-- lua/custom/test_results.lua
local M = {}

local Path = require("plenary.path")
local scan = require("plenary.scandir")

function M.surefire_dir()
  return vim.fn.getcwd() .. "/target/surefire-reports"
end

function M.get_test_files()
  local dir = M.surefire_dir()
  if vim.fn.isdirectory(dir) == 0 then return {} end
  return scan.scan_dir(dir, { search_pattern = "TEST%-.*%.xml", depth = 1 })
end

-- ─── Utilidades XML ───────────────────────────────────────────────────────────

local function extract_attr(str, attr)
  local val = str:match(attr .. '="([^"]*)"')
  if not val then return nil end
  val = val:gsub("&#10;", " "):gsub("&#13;", ""):gsub("&amp;", "&")
           :gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
  return vim.trim(val)
end

local function decode_entities(s)
  if not s then return s end
  return s:gsub("&#10;", "\n"):gsub("&#13;", ""):gsub("&amp;", "&")
          :gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
          :gsub("&apos;", "'")
end

-- ─── Parser ───────────────────────────────────────────────────────────────────
-- Itera el XML posicionalmente para evitar que patrones multi-línea
-- con `.-` capturen bloques incorrectos cuando hay múltiples testcase.

---@param file string
---@return table[]
function M.parse_file(file)
  local content = Path:new(file):read()
  if not content or content == "" then return {} end

  -- ── Leer el FQN del <testsuite> ───────────────────────────────────────────
  -- Surefire 3.x + JUnit 4 escribe el nombre del método en el atributo
  -- classname de cada <testcase> en lugar del nombre de la clase.
  -- El <testsuite name="com.course.GameTest"> sí tiene el FQN correcto,
  -- lo usamos como fallback cuando el classname del testcase no es válido.
  local suite_name = content:match('<testsuite[^>]- name="([^"]+)"')
    or content:match('<testsuite[^>]-name="([^"]+)"')

  -- Un classname es válido si tiene paquete (contiene punto) o empieza con
  -- mayúscula y es distinto al nombre del método. JUnit 4 + Surefire 3.x
  -- pone el nombre del método como classname → no tiene punto, empieza en
  -- minúscula → inválido → usar suite_name.
  local function resolve_classname(cn, test_name)
    if not cn or cn == "" then return suite_name end
    if cn:match("%.") then return cn end          -- FQN con paquete → válido
    if cn:match("^%u") and cn ~= test_name then return cn end  -- PascalCase distinto al método → válido
    return suite_name                              -- parece nombre de método → fallback
  end

  local results = {}
  local pos = 1

  while true do
    local tc_start = content:find("<testcase", pos, true)
    if not tc_start then break end

    local sc_end   = content:find("/>",          tc_start, true)
    local body_end = content:find("</testcase>", tc_start, true)

    local tag_attrs, body, has_body

    if sc_end and (not body_end or sc_end < body_end) then
      tag_attrs = content:sub(tc_start, sc_end + 1):match("<testcase([^>]-)/>" )
      has_body  = false
      pos       = sc_end + 2
    elseif body_end then
      local full = content:sub(tc_start, body_end + 10)
      tag_attrs  = full:match("<testcase([^>]-)>")
      body       = full:match("<testcase[^>]->(.*)</testcase>")
      has_body   = true
      pos        = body_end + 11
    else
      break
    end

    if not tag_attrs then goto continue end

    local name      = extract_attr(tag_attrs, "name")
    local classname = resolve_classname(extract_attr(tag_attrs, "classname"), name)
    if not name or not classname then goto continue end

    local status, message, stacktrace = "passed", nil, nil

    if has_body and body then
      local f_tag  = body:match("<failure([^>]-)>")
      local f_body = body:match("<failure[^>]*>(.-)</failure>")
      if f_tag or body:match("<failure") then
        status     = "failed"
        message    = (f_tag and extract_attr(f_tag, "message")) or "Assertion failed"
        stacktrace = f_body and decode_entities(vim.trim(f_body)) or nil
      end

      if status == "passed" then
        local e_tag  = body:match("<error([^>]-)>")
        local e_body = body:match("<error[^>]*>(.-)</error>")
        if e_tag or body:match("<error") then
          status     = "error"
          message    = (e_tag and extract_attr(e_tag, "message")) or "Unexpected error"
          stacktrace = e_body and decode_entities(vim.trim(e_body)) or nil
        end
      end

      if status == "passed" and body:match("<skipped") then
        status = "skipped"
      end
    end

    table.insert(results, {
      name       = name,
      class      = classname,
      status     = status,
      time       = tonumber(extract_attr(tag_attrs, "time")) or 0,
      message    = message,
      stacktrace = stacktrace,
    })

    ::continue::
  end

  return results
end

function M.get_all_results()
  local all = {}
  for _, file in ipairs(M.get_test_files()) do
    vim.list_extend(all, M.parse_file(file))
  end
  return all
end

function M.get_results_for_class(classname)
  local all = M.get_all_results()
  local out = {}

  -- Nombre simple de lo que buscamos (sin package)
  local simple = classname:match("([^.]+)$") or classname

  for _, t in ipairs(all) do
    -- Del classname del XML extraer la clase raíz (antes del $ si existe)
    -- "com.example.demo.EntityUnitTest$DoctorTest" → "EntityUnitTest"
    -- "com.example.demo.EntityUnitTest"            → "EntityUnitTest"
    local fqn_root = t.class:match("([^.]+)%$") or t.class:match("([^.]+)$")

    if fqn_root == simple or t.class == classname then
      table.insert(out, t)
    end
  end
  return out
end

function M.group_by_class(results)
  local grouped, order = {}, {}
  for _, test in ipairs(results) do
    if not grouped[test.class] then
      grouped[test.class] = {}
      table.insert(order, test.class)
    end
    table.insert(grouped[test.class], test)
  end
  return grouped, order
end

function M.stats(results)
  local s = { total = #results, passed = 0, failed = 0, error = 0, skipped = 0 }
  for _, t in ipairs(results) do
    s[t.status] = (s[t.status] or 0) + 1
  end
  return s
end

---Agrupa tests en árbol: { root_class -> { tests_directos, nested -> { tests } } }
---@param results table[]
---@return table árbol jerárquico
---@return string[] orden de clases raíz
function M.group_as_tree(results)
  local roots  = {}   -- { [root_name] = { direct={}, nested={[nested_name]={tests}} } }
  local order  = {}   -- orden de aparición de raíces

  for _, test in ipairs(results) do
    local cls = test.class

    -- Extraer raíz y nested del classname
    -- "com.example.demo.EntityUnitTest$DoctorTest" → root="EntityUnitTest", nested="DoctorTest"
    -- "com.example.demo.EntityUnitTest"            → root="EntityUnitTest", nested=nil
    local root, nested
    local dollar_pos = cls:find("%$")
    if dollar_pos then
      root   = cls:sub(1, dollar_pos - 1):match("([^.]+)$")
      nested = cls:sub(dollar_pos + 1)
      -- nested profundo: "A$B$C" → nested = "B$C", mostrar solo el último
      nested = nested:match("([^$]+)$") or nested
    else
      root   = cls:match("([^.]+)$")
      nested = nil
    end

    if not roots[root] then
      roots[root] = { direct = {}, nested = {}, nested_order = {} }
      table.insert(order, root)
    end

    if nested then
      if not roots[root].nested[nested] then
        roots[root].nested[nested] = {}
        table.insert(roots[root].nested_order, nested)
      end
      table.insert(roots[root].nested[nested], test)
    else
      table.insert(roots[root].direct, test)
    end
  end

  return roots, order
end


return M
