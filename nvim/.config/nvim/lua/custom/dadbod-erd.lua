local M = {}

local EXCLUDED_TABLES = { flyway_schema_history = true }
local PUPPETEER_CONFIG = vim.fn.expand("~/.config/nvim/puppeteer-config.json")

local function ensure_puppeteer_config()
  if vim.fn.filereadable(PUPPETEER_CONFIG) == 0 then
    vim.fn.writefile({ '{"args":["--no-sandbox"]}' }, PUPPETEER_CONFIG)
  end
end

local function find_latest_dbout()
  local found = vim.fn.glob("/tmp/nvim.*/**/*.dbout", false, true)
  if #found == 0 then
    return nil
  end
  table.sort(found, function(a, b)
    local na = tonumber(a:match("/(%d+)%.dbout$")) or 0
    local nb = tonumber(b:match("/(%d+)%.dbout$")) or 0
    return na > nb
  end)
  return found[1]
end

local function simplify_type(t)
  return t:match("^(%a+)") or t
end

local function parse_dbout(dbout)
  local raw = vim.fn.readfile(dbout)
  local tables = {}
  local table_order = {}
  local relations = {}

  for _, line in ipairs(raw) do
    local t = vim.trim(line)
    if t:match("^|") and not t:match("^|%-") and not t:match("^|%s*row_type") then
      local row_type, tname, colname, coltype, extra, ref =
        t:match("^|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|%s*(.-)%s*|$")

      if row_type == "col" and not EXCLUDED_TABLES[tname] then
        if not tables[tname] then
          tables[tname] = {}
          table.insert(table_order, tname)
        end
        local key = (extra and extra ~= "" and extra ~= "NULL") and (" " .. vim.trim(extra)) or ""
        local typ = simplify_type(coltype ~= "NULL" and coltype or "varchar")
        table.insert(tables[tname], string.format("    %s %s%s", typ, colname, key))
      elseif row_type == "fk" then
        table.insert(relations, string.format('  %s }|--|| %s : "%s"', tname, ref, colname))
      end
    end
  end

  return tables, table_order, relations
end

local function build_mmd(tables, table_order, relations)
  local mmd = { "erDiagram" }
  for _, tname in ipairs(table_order) do
    table.insert(mmd, "  " .. tname .. " {")
    for _, col in ipairs(tables[tname]) do
      table.insert(mmd, col)
    end
    table.insert(mmd, "  }")
  end
  for _, r in ipairs(relations) do
    table.insert(mmd, r)
  end
  return mmd
end

local function render_png(out_mmd, out_png)
  vim.fn.jobstart({ "mmdc", "-i", out_mmd, "-o", out_png, "-p", PUPPETEER_CONFIG }, {
    on_exit = function(_, code)
      if code == 0 then
        vim.notify("ERD listo → " .. out_png, vim.log.levels.INFO)
        vim.fn.jobstart({ "eog", out_png })
      else
        vim.cmd("vsplit " .. out_mmd)
        vim.notify("mmdc falló (código " .. code .. ")", vim.log.levels.ERROR)
      end
    end,
  })
end

function M.open_query(db, schema)
  local dir = vim.fn.expand("~/.local/share/db_ui/" .. schema)
  vim.fn.mkdir(dir, "p")
  local bufname = dir .. "/erd_query.sql"
  vim.cmd("edit " .. vim.fn.fnameescape(bufname))
  vim.b.db = db
  vim.bo.filetype = "sql"

  local query = string.format(
    [[-- ERD Mermaid — schema: %s
-- 1) Ejecuta con <leader>DS o \S
-- 2) Luego <leader>Dr para renderizar

SELECT
  'col' AS row_type,
  t.TABLE_NAME, c.COLUMN_NAME, c.COLUMN_TYPE,
  IF(kcu_pk.COLUMN_NAME IS NOT NULL, 'PK',
    IF(kcu_fk.COLUMN_NAME IS NOT NULL, 'FK', '')
  ) AS extra,
  NULL AS ref_table,
  c.ORDINAL_POSITION AS ord
FROM information_schema.TABLES t
JOIN information_schema.COLUMNS c
  ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
LEFT JOIN information_schema.KEY_COLUMN_USAGE kcu_pk
  ON kcu_pk.TABLE_SCHEMA = t.TABLE_SCHEMA AND kcu_pk.TABLE_NAME = t.TABLE_NAME
  AND kcu_pk.COLUMN_NAME = c.COLUMN_NAME AND kcu_pk.CONSTRAINT_NAME = 'PRIMARY'
LEFT JOIN information_schema.KEY_COLUMN_USAGE kcu_fk
  ON kcu_fk.TABLE_SCHEMA = t.TABLE_SCHEMA AND kcu_fk.TABLE_NAME = t.TABLE_NAME
  AND kcu_fk.COLUMN_NAME = c.COLUMN_NAME AND kcu_fk.REFERENCED_TABLE_NAME IS NOT NULL
WHERE t.TABLE_SCHEMA = '%s' AND t.TABLE_TYPE = 'BASE TABLE'
UNION ALL
SELECT
  'fk' AS row_type,
  kcu.TABLE_NAME, kcu.COLUMN_NAME, NULL, NULL,
  kcu.REFERENCED_TABLE_NAME, 0 AS ord
FROM information_schema.KEY_COLUMN_USAGE kcu
JOIN information_schema.TABLE_CONSTRAINTS tc
  ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
  AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA AND tc.TABLE_NAME = kcu.TABLE_NAME
WHERE tc.CONSTRAINT_TYPE = 'FOREIGN KEY' AND kcu.TABLE_SCHEMA = '%s'
ORDER BY row_type DESC, TABLE_NAME, ord, COLUMN_NAME;]],
    schema,
    schema,
    schema
  )

  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(query, "\n"))
  vim.cmd("write")

  -- Mapping local al buffer para ejecutar
  vim.keymap.set("n", "<leader>DS", function()
    vim.cmd("write")
    vim.cmd("DB")
  end, { buffer = true, desc = "DB: ejecutar query ERD" })

  vim.notify("Ejecuta con <leader>DS o \\S, luego <leader>Dr para renderizar", vim.log.levels.INFO)
end

function M.render(schema)
  ensure_puppeteer_config()

  local dbout = find_latest_dbout()
  if not dbout then
    vim.notify("No se encontró .dbout — ejecuta la query primero", vim.log.levels.WARN)
    return
  end

  local tables, table_order, relations = parse_dbout(dbout)

  if #table_order == 0 then
    vim.cmd("vsplit " .. dbout)
    vim.notify("No se parsearon tablas — revisa el dbout abierto", vim.log.levels.WARN)
    return
  end

  local mmd = build_mmd(tables, table_order, relations)
  local out_mmd = string.format("/tmp/erd_%s.mmd", schema)
  local out_png = string.format("/tmp/erd_%s.png", schema)

  vim.fn.writefile(mmd, out_mmd)
  render_png(out_mmd, out_png)
end

function M.copy_mmd(schema)
  local out_mmd = string.format("/tmp/erd_%s.mmd", schema)
  if vim.fn.filereadable(out_mmd) == 0 then
    vim.notify("No hay .mmd generado aún — corre <leader>Dr primero", vim.log.levels.WARN)
    return
  end
  local lines = vim.fn.readfile(out_mmd)
  local content = "```mermaid\n" .. table.concat(lines, "\n") .. "\n```"
  vim.fn.setreg("+", content)
  vim.fn.setreg('"', content)
  vim.notify("Mermaid copiado al clipboard (" .. #lines .. " líneas)", vim.log.levels.INFO)
end

return M
