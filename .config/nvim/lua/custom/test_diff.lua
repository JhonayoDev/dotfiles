-- lua/custom/test_diff.lua
--
-- Responsabilidad única: dado el stacktrace de un test fallido,
-- extraer expected/actual y renderizarlo en un float o diff side-by-side.
--
-- No sabe nada de: Maven, XMLs, árbol de tests, ni layout general.
--
-- API pública:
--   M.extract(stacktrace) → { expected, actual, kind }
--   M.show(test)          → abre float según el kind

local M = {}

-- ─── Extractores por framework ────────────────────────────────────────────────
--
-- Cada extractor recibe el stacktrace completo y devuelve { expected, actual }
-- o nil si no puede parsearlo.
--
-- Para agregar soporte a un nuevo framework de assertions:
--   1. Escribir una función extractora
--   2. Agregarla a la tabla EXTRACTORS
-- El resto del módulo no cambia.

local EXTRACTORS = {}

-- AssertJ / JUnit 5 estándar:
-- "expected: <5> but was: <3>"
-- "expected: <"hola"> but was: <"chau">"
EXTRACTORS.assertj = function(st)
  local exp = st:match("[Ee]xpected%s*:%s*<(.-)>")
    or st:match('[Ee]xpected%s*:%s*"(.-)"')
    or st:match("[Ee]xpected%s*:%s*(%S+)")
  local act = st:match("[Bb]ut was%s*:%s*<(.-)>")
    or st:match('[Bb]ut was%s*:%s*"(.-)"')
    or st:match("[Aa]ctual%s*:%s*<(.-)>")
    or st:match("[Ww]as%s*:%s*(%S+)")
  if exp or act then
    return { expected = exp, actual = act }
  end
end

-- JUnit 4 Assert clásico:
-- "expected:<5> but was:<3>"   (sin espacios alrededor de los dos puntos)
EXTRACTORS.junit4 = function(st)
  local exp = st:match("expected:<%s*(.-)%s*>")
  local act = st:match("but was:<%s*(.-)%s*>")
  if exp or act then
    return { expected = exp, actual = act }
  end
end

-- Hamcrest (usado frecuentemente con JUnit 4):
-- "Expected: 5"
-- "     but: was <3>"
EXTRACTORS.hamcrest = function(st)
  local exp = st:match("[Ee]xpected%s*:%s*(.+)\n")
    or st:match("[Ee]xpected%s*:%s*(%S+)")
  local act = st:match("but%s*:%s*was%s*<(.-)>")
    or st:match("but%s*:%s*(.+)\n")
  if exp or act then
    return { expected = vim.trim(exp or ""), actual = vim.trim(act or "") }
  end
end

-- ─── API pública ──────────────────────────────────────────────────────────────

---Analiza el stacktrace y determina qué mostrar.
---
---@param stacktrace string
---@return table
---  {
---    expected string|nil   valor esperado si se encontró
---    actual   string|nil   valor actual   si se encontró
---    kind     string       "assertion" | "exception" | "unknown"
---  }
function M.extract(stacktrace)
  if not stacktrace or stacktrace == "" then
    return { kind = "unknown" }
  end

  -- Probar cada extractor en orden
  for _, extractor in pairs(EXTRACTORS) do
    local result = extractor(stacktrace)
    if result then
      return {
        expected = result.expected,
        actual   = result.actual,
        kind     = "assertion",
      }
    end
  end

  -- Tiene stacktrace pero no es una aserción reconocida → excepción inesperada
  if stacktrace:match("Exception") or stacktrace:match("Error") then
    return { kind = "exception" }
  end

  return { kind = "unknown" }
end

---Muestra el resultado del test fallido según su kind:
---  assertion → diff side-by-side (expected vs actual)
---  exception → stacktrace en float
---  unknown   → stacktrace en float
---
---@param test table  entrada de test_results con campos name, stacktrace, message
function M.show(test)
  if not test then return end

  local st = test.stacktrace

  if not st or st == "" then
    vim.notify("No hay stacktrace disponible para: " .. (test.name or "?"),
      vim.log.levels.INFO)
    return
  end

  local info = M.extract(st)

  if info.kind == "assertion" and (info.expected or info.actual) then
    M._show_diff(test, info)
  else
    M._show_stacktrace(test)
  end
end

---Abre el stacktrace completo en un float centrado.
---@param test table
function M._show_stacktrace(test)
  local lines = vim.split(test.stacktrace or "", "\n")
  local buf   = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype",   "java",  { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false,   { buf = buf })
  vim.api.nvim_set_option_value("bufhidden",  "wipe",  { buf = buf })

  local width  = math.min(100, vim.o.columns - 10)
  local height = math.min(#lines + 2, vim.o.lines - 6)

  local win = vim.api.nvim_open_win(buf, true, {
    relative  = "editor",
    width     = width,
    height    = height,
    row       = math.floor((vim.o.lines   - height) / 2),
    col       = math.floor((vim.o.columns - width)  / 2),
    border    = "rounded",
    title     = "  Stacktrace: " .. (test.name or ""),
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("wrap",       false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true,  { win = win })

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, silent = true })
  end
end

---Abre diff side-by-side: expected (izquierda) vs actual (derecha).
---@param test table
---@param info table  resultado de M.extract()
function M._show_diff(test, info)
  local exp_lines = vim.split(info.expected or "(no disponible)", "\n")
  local act_lines = vim.split(info.actual   or "(no disponible)", "\n")

  local exp_buf = vim.api.nvim_create_buf(false, true)
  local act_buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(exp_buf, 0, -1, false, exp_lines)
  vim.api.nvim_buf_set_lines(act_buf, 0, -1, false, act_lines)

  for _, buf in ipairs({ exp_buf, act_buf }) do
    vim.api.nvim_set_option_value("filetype",   "text", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false,  { buf = buf })
    vim.api.nvim_set_option_value("bufhidden",  "wipe", { buf = buf })
  end

  local width  = math.min(120, vim.o.columns - 4)
  local height = math.min(20,  vim.o.lines   - 8)
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)
  local half   = math.floor(width / 2) - 1

  local exp_win = vim.api.nvim_open_win(exp_buf, true, {
    relative  = "editor",
    width     = half, height = height,
    row       = row,  col    = col,
    border    = "rounded",
    title     = "  Expected",
    title_pos = "center",
  })
  local act_win = vim.api.nvim_open_win(act_buf, false, {
    relative  = "editor",
    width     = half, height = height,
    row       = row,  col    = col + half + 2,
    border    = "rounded",
    title     = "  Actual",
    title_pos = "center",
  })

  vim.api.nvim_set_current_win(exp_win); vim.cmd("diffthis")
  vim.api.nvim_set_current_win(act_win); vim.cmd("diffthis")

  local function close_both()
    vim.cmd("diffoff!")
    if vim.api.nvim_win_is_valid(exp_win) then vim.api.nvim_win_close(exp_win, true) end
    if vim.api.nvim_win_is_valid(act_win) then vim.api.nvim_win_close(act_win, true) end
  end

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, close_both, { buffer = exp_buf, silent = true })
    vim.keymap.set("n", key, close_both, { buffer = act_buf, silent = true })
  end
end

return M
