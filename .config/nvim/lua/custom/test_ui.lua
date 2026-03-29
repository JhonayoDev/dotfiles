-- lua/custom/test_ui.lua
--
-- Responsabilidad única: layout, renderizado, keymaps y orquestación.
-- Delega toda la lógica a los módulos especializados:
--
--   test_context  → detectar framework, clase, método desde el buffer
--   test_results  → parsear XMLs de surefire-reports
--   test_runner   → ejecutar Maven y emitir eventos
--   test_watcher  → observar surefire-reports en tiempo real
--   test_diff     → extraer y mostrar expected/actual y stacktrace

local M = {}

local context_mod = require("custom.test_context")
local results_mod = require("custom.test_results")
local runner_mod = require("custom.test_runner")
local watcher_mod = require("custom.test_watcher")
local diff_mod = require("custom.test_diff")
local java_env_mod = require("custom.test_java_env")

-- ─── Iconos Nerd Fonts v3 ─────────────────────────────────────────────────────

local ICON = {
  passed = "✓ ",
  failed = "✗ ",
  error = "⚠ ",
  skipped = "○ ",
  running = "● ",
  stale = "~ ", -- resultados desactualizados
  fold_open = "▼ ",
  fold_close = "▶ ",
  child = "├ ",
  child_last = "└ ",
  pipe = "│ ",
  blank = "  ",
}

-- ─── Highlights ───────────────────────────────────────────────────────────────

local HL = {
  header = "Title",
  class = "Type",
  passed = "DiagnosticOk",
  failed = "DiagnosticError",
  error = "DiagnosticWarn",
  skipped = "Comment",
  running = "DiagnosticInfo",
  stale = "Comment",
  message = "DiagnosticVirtualTextError",
  help = "Comment",
  separator = "Comment",
  log_error = "DiagnosticError",
  log_ok = "DiagnosticOk",
  log_info = "DiagnosticInfo",
}

-- ─── Estado ───────────────────────────────────────────────────────────────────

local state = {
  -- ventanas y buffers
  tree_buf = nil,
  tree_win = nil,
  out_buf = nil,
  out_win = nil,
  -- árbol
  lines = {},
  metadata = {},
  collapsed = {},
  -- ejecución
  running = false,
  stale = false, -- true cuando hay resultados pero se inició un nuevo run
  active_class = nil,
  -- log de Maven — acumula TODO el output, nunca se trunca
  log_lines = {},
}

-- ─── Layout dinámico ──────────────────────────────────────────────────────────
-- El ancho del panel de output es el 40% de las columnas disponibles.
-- El árbol ocupa el 60% restante.
-- Altura del panel = 18 líneas (configurable).

local PANEL_HEIGHT = 18

local function out_width()
  return math.floor(vim.o.columns * 0.40)
end

-- ─── Utilidades de buffer ─────────────────────────────────────────────────────

local function buf_opt(buf, k, v)
  vim.api.nvim_set_option_value(k, v, { buf = buf })
end

local function win_opt(win, k, v)
  vim.api.nvim_set_option_value(k, v, { win = win })
end

local function hl_line(buf, ns, group, lnum)
  vim.api.nvim_buf_add_highlight(buf, ns, group, lnum, 0, -1)
end

local function buf_set_lines(buf, lines)
  buf_opt(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  buf_opt(buf, "modifiable", false)
end

-- Scroll el buffer de output al final
local function scroll_output_to_end()
  if not state.out_win or not vim.api.nvim_win_is_valid(state.out_win) then
    return
  end
  if not state.out_buf or not vim.api.nvim_buf_is_valid(state.out_buf) then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(state.out_buf)
  vim.api.nvim_win_set_cursor(state.out_win, { line_count, 0 })
end

-- ─── Ventana ──────────────────────────────────────────────────────────────────

local function is_open()
  return state.tree_win and vim.api.nvim_win_is_valid(state.tree_win)
end

local function create_buf(name)
  local buf = vim.api.nvim_create_buf(false, true)
  buf_opt(buf, "bufhidden", "wipe")
  buf_opt(buf, "buftype", "nofile")
  buf_opt(buf, "swapfile", false)
  pcall(vim.api.nvim_buf_set_name, buf, name)
  return buf
end

local function setup_win(win)
  win_opt(win, "number", false)
  win_opt(win, "relativenumber", false)
  win_opt(win, "signcolumn", "no")
  win_opt(win, "wrap", false)
  win_opt(win, "cursorline", true)
  win_opt(win, "winfixheight", true)
end

local function open_layout()
  if is_open() then
    return
  end
  state.tree_buf = create_buf("JavaTests://tree")
  state.out_buf = create_buf("JavaTests://output")

  -- Split horizontal inferior ocupa PANEL_HEIGHT líneas
  vim.cmd("botright " .. PANEL_HEIGHT .. "split")
  state.tree_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.tree_win, state.tree_buf)
  setup_win(state.tree_win)

  state.tree_width = vim.api.nvim_win_get_width(state.tree_win)
  -- Panel derecho: 40% del ancho total
  vim.cmd("vsplit")
  state.out_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.out_win, state.out_buf)
  setup_win(state.out_win)
  -- El panel de output sí puede hacer scroll — wrap off pero scrollable
  win_opt(state.out_win, "winfixwidth", true)
  win_opt(state.out_win, "wrap", false)
  vim.api.nvim_win_set_width(state.out_win, out_width())

  -- Foco al árbol
  vim.api.nvim_set_current_win(state.tree_win)

  -- Cerrar ambos paneles si se cierra el árbol
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(state.tree_win),
    once = true,
    callback = function()
      watcher_mod.stop()
      if state.out_win and vim.api.nvim_win_is_valid(state.out_win) then
        vim.api.nvim_win_close(state.out_win, true)
      end
      state.tree_win = nil
      state.tree_buf = nil
      state.out_win = nil
      state.out_buf = nil
    end,
  })
end

-- ─── Renderizado: panel de output (log) ───────────────────────────────────────
--
-- El log NUNCA se trunca — acumula todas las líneas de Maven.
-- El panel es scrollable: el usuario puede subir para ver el historial.
-- Al recibir nueva línea hace auto-scroll al final.

local function render_log()
  if not state.out_buf or not vim.api.nvim_buf_is_valid(state.out_buf) then
    return
  end

  -- Escribir todas las líneas del log en el buffer
  buf_set_lines(state.out_buf, state.log_lines)

  -- Highlights
  local ns = vim.api.nvim_create_namespace("java_test_log")
  vim.api.nvim_buf_clear_namespace(state.out_buf, ns, 0, -1)

  for i, line in ipairs(state.log_lines) do
    local lnum = i - 1
    if line:match("%[ERROR%]") or line:match("FAILURE") or line:match("FAILED") then
      hl_line(state.out_buf, ns, HL.log_error, lnum)
    elseif line:match("BUILD SUCCESS") then
      hl_line(state.out_buf, ns, HL.log_ok, lnum)
    elseif line:match("Tests run:") or line:match("^%s*⚠") or line:match("^%s*ℹ") then
      hl_line(state.out_buf, ns, HL.log_info, lnum)
    elseif line:match("^%s*✗") then
      hl_line(state.out_buf, ns, HL.log_error, lnum)
    elseif line:match("^%s*✓") or line:match("BUILD SUCCESS") then
      hl_line(state.out_buf, ns, HL.log_ok, lnum)
    elseif line:match("^%s*─") or line:match("^%s*═") then
      hl_line(state.out_buf, ns, HL.separator, lnum)
    end
  end

  -- Auto-scroll al final si el watcher o runner agregó líneas nuevas
  scroll_output_to_end()
end

-- Agregar líneas al log y re-renderizar
local function log_append(lines)
  for _, line in ipairs(lines) do
    table.insert(state.log_lines, line)
  end
  render_log()
end

-- ─── Renderizado: árbol de tests ──────────────────────────────────────────────

local function add_tests(lines, metadata, tests, indent, parent_class)
  local total = #tests
  for i, test in ipairs(tests) do
    local is_last = (i == total)
    local prefix = is_last and ICON.child_last or ICON.child
    local t_icon = state.stale and ICON.stale or (ICON[test.status] or ICON.error)
    local time_str = test.time > 0 and string.format("%6.3fs", test.time) or "      "

    local tree_width = (state.tree_win and vim.api.nvim_win_is_valid(state.tree_win))
        and vim.api.nvim_win_get_width(state.tree_win)
      or math.floor(vim.o.columns * 0.60)
    local max_name = math.max(10, tree_width - indent - 12)
    local name = #test.name > max_name and test.name:sub(1, max_name - 1) .. "…" or test.name

    table.insert(
      lines,
      string.format("%s%s%s%-" .. max_name .. "s  %s", string.rep(" ", indent), prefix, t_icon, name, time_str)
    )
    metadata[#lines] = { kind = "test", test = test, class = parent_class }

    if test.message and not state.stale then
      local pipe = is_last and ICON.blank or ICON.pipe
      local msg = test.message:sub(1, 36 - indent) .. (#test.message > 36 - indent and "…" or "")
      table.insert(lines, string.rep(" ", indent) .. pipe .. "  " .. msg)
      metadata[#lines] = { kind = "message", test = test }
    end
  end
end

local function build_tree(results)
  local lines = {}
  local metadata = {}
  local roots, order = results_mod.group_as_tree(results)
  local stats = results_mod.stats(results)
  local sep_width = vim.o.columns - out_width() - 4
  -- Header
  local s_icon = state.stale and ICON.stale or (stats.failed > 0 and ICON.failed or ICON.passed)
  local stale_note = state.stale and " (corriendo…)" or ""
  local header = string.format(
    "%s Tests  %s%d  %s%d  %d total%s",
    s_icon,
    ICON.passed,
    stats.passed,
    ICON.failed,
    stats.failed,
    stats.total,
    stale_note
  )
  table.insert(lines, " " .. header)
  metadata[#lines] = { kind = "header" }
  table.insert(lines, " " .. string.rep("─", sep_width))
  metadata[#lines] = { kind = "separator" }

  for _, root in ipairs(order) do
    local data = roots[root]
    local collapsed = state.collapsed[root]

    local total_count = #data.direct
    for _, n_tests in pairs(data.nested) do
      total_count = total_count + #n_tests
    end

    local has_fail = false
    for _, t in ipairs(data.direct) do
      if t.status == "failed" or t.status == "error" then
        has_fail = true
        break
      end
    end
    if not has_fail then
      for _, n_tests in pairs(data.nested) do
        for _, t in ipairs(n_tests) do
          if t.status == "failed" or t.status == "error" then
            has_fail = true
            break
          end
        end
        if has_fail then
          break
        end
      end
    end

    local c_icon = state.stale and ICON.stale or (has_fail and ICON.failed or ICON.passed)
    local fold = collapsed and ICON.fold_close or ICON.fold_open

    if #data.nested_order > 0 or total_count > 0 then
      table.insert(lines, string.format(" %s%s%s  (%d)", fold, c_icon, root, total_count))
      metadata[#lines] = { kind = "class", class = root }
    end

    if not collapsed then
      if #data.direct > 0 then
        add_tests(lines, metadata, data.direct, 3, root)
      end

      for _, nested_name in ipairs(data.nested_order) do
        local n_tests = data.nested[nested_name]
        local n_key = root .. "$" .. nested_name
        local n_collapsed = state.collapsed[n_key]

        local n_fail = false
        for _, t in ipairs(n_tests) do
          if t.status == "failed" or t.status == "error" then
            n_fail = true
            break
          end
        end

        local n_icon = state.stale and ICON.stale or (n_fail and ICON.failed or ICON.passed)
        local n_fold = n_collapsed and ICON.fold_close or ICON.fold_open

        table.insert(lines, string.format("   %s%s%s  (%d)", n_fold, n_icon, nested_name, #n_tests))
        metadata[#lines] = { kind = "nested", class = n_key, root = root }

        if not n_collapsed then
          add_tests(lines, metadata, n_tests, 6, n_key)
        end
      end

      table.insert(lines, "")
      metadata[#lines] = { kind = "blank" }
    end
  end

  table.insert(lines, " " .. string.rep("─", 50))
  metadata[#lines] = { kind = "separator" }
  table.insert(lines, "  <CR> ir   d diff   s trace   <Tab> fold   r reload   q cerrar")
  metadata[#lines] = { kind = "help" }

  return lines, metadata
end

local function apply_tree_highlights(buf, metadata)
  local ns = vim.api.nvim_create_namespace("java_test_tree")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, meta in ipairs(metadata) do
    if not meta then
      goto continue
    end
    local lnum = i - 1
    if meta.kind == "header" then
      hl_line(buf, ns, HL.header, lnum)
    elseif meta.kind == "separator" then
      hl_line(buf, ns, HL.separator, lnum)
    elseif meta.kind == "help" then
      hl_line(buf, ns, HL.help, lnum)
    elseif meta.kind == "class" then
      hl_line(buf, ns, HL.class, lnum)
    elseif meta.kind == "nested" then
      hl_line(buf, ns, HL.class, lnum)
    elseif meta.kind == "message" then
      hl_line(buf, ns, HL.message, lnum)
    elseif meta.kind == "test" and meta.test then
      local grp = state.stale and HL.stale or (HL[meta.test.status] or "Normal")
      hl_line(buf, ns, grp, lnum)
    end
    ::continue::
  end
end

local function refresh_tree()
  if not state.tree_buf or not vim.api.nvim_buf_is_valid(state.tree_buf) then
    return
  end

  local results = state.active_class and results_mod.get_results_for_class(state.active_class)
    or results_mod.get_all_results()

  if #results == 0 then
    buf_set_lines(state.tree_buf, {
      "",
      "  " .. ICON.running .. " No hay resultados todavía.",
      "",
      "  <leader>cTpc  →  clase actual",
      "  <leader>cTpm  →  método bajo cursor",
      "  <leader>cTpa  →  todos los tests",
      "",
    })
    return
  end

  local lines, metadata = build_tree(results)
  state.lines = lines
  state.metadata = metadata
  buf_set_lines(state.tree_buf, lines)
  apply_tree_highlights(state.tree_buf, metadata)
end

-- ─── Keymaps del árbol ────────────────────────────────────────────────────────

local function goto_test()
  if not state.tree_win or not vim.api.nvim_win_is_valid(state.tree_win) then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(state.tree_win)[1]
  local meta = state.metadata[lnum]
  if not meta or not meta.test then
    return
  end
  local test = meta.test

  local fqn_root = test.class:match("^(.-)%$") or test.class
  local package = fqn_root:match("^(.+)%.[^.]+$") or ""
  local root_cls = fqn_root:match("([^.]+)$")
  local pkg_path = package:gsub("%.", "/")
  local rel = (pkg_path ~= "" and (pkg_path .. "/") or "") .. root_cls .. ".java"

  local candidates = {
    vim.fn.getcwd() .. "/src/test/java/" .. rel,
    vim.fn.getcwd() .. "/src/main/java/" .. rel,
  }
  local target
  for _, p in ipairs(candidates) do
    if vim.fn.filereadable(p) == 1 then
      target = p
      break
    end
  end
  if not target then
    vim.notify("Archivo no encontrado: " .. rel, vim.log.levels.WARN)
    return
  end

  -- Ir a la ventana del editor (la que no es panel)
  local panel_wins = { state.tree_win, state.out_win }
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local is_panel = false
    for _, pw in ipairs(panel_wins) do
      if w == pw then
        is_panel = true
        break
      end
    end
    if not is_panel then
      vim.api.nvim_set_current_win(w)
      break
    end
  end

  vim.cmd("edit " .. vim.fn.fnameescape(target))
  local buf_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  for i, line in ipairs(buf_lines) do
    if line:match("void%s+" .. vim.pesc(test.name) .. "%s*%(") then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      vim.cmd("normal! zz")
      break
    end
  end
end

local function toggle_class()
  if not state.tree_win then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(state.tree_win)[1]
  local meta = state.metadata[lnum]
  if not meta then
    return
  end
  if meta.kind == "class" or meta.kind == "nested" then
    state.collapsed[meta.class] = not state.collapsed[meta.class]
    refresh_tree()
  end
end

local function show_stacktrace()
  if not state.tree_win then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(state.tree_win)[1]
  local meta = state.metadata[lnum]
  if not meta or not meta.test then
    vim.notify("No hay stacktrace disponible.", vim.log.levels.INFO)
    return
  end
  diff_mod._show_stacktrace(meta.test)
end

local function show_diff()
  if not state.tree_win then
    return
  end
  local lnum = vim.api.nvim_win_get_cursor(state.tree_win)[1]
  local meta = state.metadata[lnum]
  if not meta or not meta.test then
    vim.notify("No hay datos de diff disponibles.", vim.log.levels.INFO)
    return
  end
  diff_mod.show(meta.test)
end

local function setup_keymaps(buf)
  local o = { buffer = buf, silent = true, noremap = true }
  vim.keymap.set("n", "<CR>", goto_test, vim.tbl_extend("force", o, { desc = "Ir al test" }))
  vim.keymap.set("n", "s", show_stacktrace, vim.tbl_extend("force", o, { desc = "Stacktrace" }))
  vim.keymap.set("n", "d", show_diff, vim.tbl_extend("force", o, { desc = "Diff" }))
  vim.keymap.set("n", "<Tab>", toggle_class, vim.tbl_extend("force", o, { desc = "Fold" }))
  vim.keymap.set("n", "r", function()
    refresh_tree()
  end, vim.tbl_extend("force", o, { desc = "Reload resultados" }))
  vim.keymap.set("n", "q", function()
    M.close()
  end, vim.tbl_extend("force", o, { desc = "Cerrar" }))
end

-- ─── Orquestación: correr tests ───────────────────────────────────────────────

local function do_run(spec, label, ctx)
  -- 1. Marcar resultados actuales como desactualizados
  state.stale = true
  state.running = true

  -- 2. Inicializar log con header informativo
  state.log_lines = {
    " " .. string.rep("═", out_width() - 3),
    "  " .. label,
    " " .. string.rep("─", out_width() - 3),
    "",
  }

  if ctx.is_spring then
    table.insert(state.log_lines, "  ⚠ Spring context — puede tardar 10-30s")
    table.insert(state.log_lines, "    Si falla: verificar DB/config/variables de entorno")
    table.insert(state.log_lines, "")
  end
  if ctx.is_disabled then
    table.insert(state.log_lines, "  ○ @Disabled/@Ignore — 0 tests es esperado")
    table.insert(state.log_lines, "")
  end
  if ctx.parent_class then
    table.insert(state.log_lines, "   Herencia: extends " .. ctx.parent_class)
    table.insert(state.log_lines, "    Tests heredados aparecen bajo la clase padre")
    table.insert(state.log_lines, "")
  end
  if ctx.framework == "junit4" then
    table.insert(state.log_lines, "   JUnit 4" .. (ctx.runner and (" — @RunWith(" .. ctx.runner .. ")") or ""))
    -- Advertir limitación de filtrado por método con JUnit 4 + Surefire 3.x
    -- El Vintage engine no puede satisfacer el filtro #método → corre la clase completa
    if ctx.method then
      table.insert(state.log_lines, "  ⚠ JUnit 4 + Surefire 3.x no soporta filtrar por método")
      table.insert(state.log_lines, "    Se ejecutará la clase completa: " .. (ctx.root_class or ""))
    end
    table.insert(state.log_lines, "")
  end

  -- Info de Java env: versión requerida, la que usará Maven, ajuste automático
  local jenv = java_env_mod.check(vim.fn.getcwd())
  if jenv.required then
    if jenv.compatible then
      table.insert(state.log_lines, "   Java " .. jenv.required .. " ✓")
    elseif jenv.missing then
      table.insert(state.log_lines, "  ✗ Java " .. jenv.required .. " requerido pero no instalado")
      table.insert(state.log_lines, "    Los tests pueden fallar — instalá con: sdk install java <ver>-tem")
    else
      table.insert(state.log_lines, "   Java " .. jenv.required .. " requerido")
      table.insert(
        state.log_lines,
        "    Sistema: Java "
          .. (jenv.maven or "?")
          .. " → runner usará Java "
          .. jenv.required
          .. " automáticamente"
      )
    end
  elseif jenv.pom_unversioned then
    table.insert(
      state.log_lines,
      "  ⚠ pom.xml sin versión Java — usando Java " .. (jenv.maven or "?") .. " del sistema"
    )
  end
  table.insert(state.log_lines, "")

  -- 3. Abrir panel y mostrar estado inicial
  M.show()
  refresh_tree()
  render_log()

  -- 4. Iniciar watcher reactivo — actualiza el árbol cuando llega un XML
  local reports_dir = vim.fn.getcwd() .. "/target/surefire-reports"
  watcher_mod.start(reports_dir, function(_filename)
    -- XML nuevo detectado: refrescar árbol en tiempo real
    vim.schedule(function()
      if state.running then
        refresh_tree()
      end
    end)
  end)

  -- 5. Correr Maven via runner_mod
  runner_mod.run(spec, {
    cwd = vim.fn.getcwd(),

    on_line = function(line)
      table.insert(state.log_lines, line)
      render_log()
    end,

    on_exit = function(exit_code, analysis)
      watcher_mod.stop()
      state.running = false
      state.stale = false

      -- Agregar resumen al final del log (no reemplaza — se acumula)
      table.insert(state.log_lines, "")
      table.insert(state.log_lines, " " .. string.rep("─", out_width() - 3))

      if analysis.context_failed then
        table.insert(state.log_lines, "  ✗ Spring context falló — ningún test corrió")
        table.insert(state.log_lines, "    Revisá 'Error creating bean' arriba")
      elseif analysis.no_tests then
        if ctx.parent_class then
          table.insert(state.log_lines, "   0 tests — posiblemente en clase padre: " .. ctx.parent_class)
        elseif ctx.is_disabled then
          table.insert(state.log_lines, "   @Disabled — 0 tests es el comportamiento esperado")
        else
          table.insert(state.log_lines, "   0 tests ejecutados — verificar spec de Maven")
        end
      elseif analysis.build_success then
        table.insert(state.log_lines, "  ✓ BUILD SUCCESS")
      else
        table.insert(state.log_lines, "  ✗ BUILD FAILURE — ver errores arriba")
      end

      table.insert(state.log_lines, "")

      refresh_tree()
      render_log()

      local icon = exit_code == 0 and ICON.passed or ICON.failed
      vim.notify(icon .. " Tests finalizados: " .. label, vim.log.levels.INFO)
    end,
  })
end

-- ─── API pública ──────────────────────────────────────────────────────────────

function M.show()
  open_layout()
  setup_keymaps(state.tree_buf)
  refresh_tree()
  render_log()
end

function M.close()
  watcher_mod.stop()
  if state.tree_win and vim.api.nvim_win_is_valid(state.tree_win) then
    vim.api.nvim_win_close(state.tree_win, true)
  end
end

function M.toggle()
  if is_open() then
    M.close()
  else
    M.show()
  end
end

function M.refresh()
  refresh_tree()
  render_log()
end

function M.run_class()
  if runner_mod.is_running() then
    vim.notify("Ya hay una ejecución en curso.", vim.log.levels.WARN)
    return
  end
  local ctx = context_mod.parse()
  local spec, label = context_mod.build_spec(ctx, false)
  if not spec then
    vim.notify("No se detectó la clase actual.", vim.log.levels.WARN)
    return
  end
  state.active_class = ctx.root_class
  do_run(spec, label, ctx)
end

function M.run_method()
  if runner_mod.is_running() then
    vim.notify("Ya hay una ejecución en curso.", vim.log.levels.WARN)
    return
  end
  local ctx = context_mod.parse()
  if not ctx.method then
    vim.notify("No se detectó el método bajo el cursor.", vim.log.levels.WARN)
    return
  end
  local spec, label = context_mod.build_spec(ctx, true)
  if not spec then
    vim.notify("No se detectó la clase actual.", vim.log.levels.WARN)
    return
  end
  state.active_class = ctx.root_class
  do_run(spec, label, ctx)
end

function M.run_all()
  if runner_mod.is_running() then
    vim.notify("Ya hay una ejecución en curso.", vim.log.levels.WARN)
    return
  end
  state.active_class = nil
  local ctx = { is_spring = false, is_disabled = false, parent_class = nil, framework = "junit5", runner = nil }
  do_run("", "todos los tests", ctx)
end

-- Para debug desde Neovim
function M._parse_context()
  return context_mod.parse()
end

return M
