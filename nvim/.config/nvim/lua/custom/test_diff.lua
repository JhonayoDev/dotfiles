-- lua/custom/test_diff.lua
--
-- Responsabilidad única: analizar el stacktrace de un test fallido
-- y renderizarlo de la forma más informativa posible.
--
-- Capas de análisis (en orden de prioridad):
--
--   Capa 1 — expected/actual explícito
--     assertEquals, assertNotEquals, assertNull, assertThat, AssertJ, Hamcrest
--     → diff side-by-side
--
--   Capa 2 — mensaje custom sin expected/actual
--     assertTrue("mensaje", cond), assertFalse("mensaje", cond)
-- assertEquals(exp, act, "mensaje")
--     → float con mensaje + línea del código
--
--   Capa 3 — AssertionError sin valores
--     assertTrue(cond), assertFalse(cond), assertNotNull(obj)
--     → float con línea del código (leída del archivo fuente)
--
--   Capa 4 — excepción inesperada o desconocida
--     NullPointerException, RuntimeException, etc.
--     → stacktrace limpio sin ruido de framework
--
-- API pública:
--   M.extract(stacktrace)  → { kind, expected, actual, message, source_line, file, line_nr }
--   M.show(test)           → abre el float apropiado según el kind

local M = {}

-- ─── Patrones de ruido en stacktraces ────────────────────────────────────────
-- Líneas de framework interno que no aportan información al usuario.
-- Se filtran en la capa 4 para mostrar solo las líneas relevantes.

local NOISE_FRAMES = {
  "at org%.junit%.",
  "at org%.mockito%.",
  "at sun%.reflect%.",
  "at java%.lang%.reflect%.",
  "at com%.sun%.",
  "at org%.springframework%.test%.",
  "at org%.apache%.maven%.",
  "at org%.junit%.vintage%.",
  "at org%.junit%.platform%.",
}

local function is_noise_frame(line)
  for _, pat in ipairs(NOISE_FRAMES) do
    if line:match(pat) then
      return true
    end
  end
  return false
end

---Filtra el stacktrace dejando solo el mensaje de error y las líneas del código del usuario.
---@param st string  stacktrace completo
---@param user_pkg string|nil  prefijo del paquete del usuario (ej: "com.course")
---@return string[]  líneas relevantes
local function clean_stacktrace(st, user_pkg)
  local lines = vim.split(st, "\n")
  local result = {}
  local found_user_code = false

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed == "" then
      goto continue
    end

    -- Siempre incluir el mensaje principal (primera línea o líneas sin "at ")
    if not trimmed:match("^at ") and not trimmed:match("^%.\\.%.") then
      table.insert(result, line)
      goto continue
    end

    -- Incluir líneas del código del usuario
    if user_pkg and trimmed:match("at " .. user_pkg:gsub("%.", "%%.")) then
      table.insert(result, line)
      found_user_code = true
      goto continue
    end

    -- Si no hay paquete conocido, incluir líneas que no son ruido puro
    if not user_pkg and not is_noise_frame(trimmed) then
      table.insert(result, line)
      goto continue
    end

    ::continue::
  end

  -- Si no encontramos código del usuario, incluir todas las líneas no-ruido
  if not found_user_code and #result <= 2 then
    result = {}
    for _, line in ipairs(lines) do
      if not is_noise_frame(vim.trim(line)) then
        table.insert(result, line)
      end
    end
  end

  return result
end

-- ─── Extractores: Capa 1 — expected/actual explícito ─────────────────────────

local EXTRACTORS = {}

-- AssertJ / JUnit 5:  "expected: <5> but was: <3>"
EXTRACTORS.assertj = function(st)
  local exp = st:match("[Ee]xpected%s*:%s*<(.-)>") or st:match('[Ee]xpected%s*:%s*"(.-)"')
  local act = st:match("[Bb]ut was%s*:%s*<(.-)>")
    or st:match('[Bb]ut was%s*:%s*"(.-)"')
    or st:match("[Aa]ctual%s*:%s*<(.-)>")
  if exp or act then
    return { expected = exp, actual = act }
  end
end

-- JUnit 4 assertEquals: "expected:<5> but was:<3>"
EXTRACTORS.junit4_equals = function(st)
  local exp = st:match("expected:<%s*(.-)%s*>")
  local act = st:match("but was:<%s*(.-)%s*>")
  if exp or act then
    return { expected = exp, actual = act }
  end
end

-- assertNull falló: "expected null but was:<valor>"
EXTRACTORS.assert_null = function(st)
  local act = st:match("[Ee]xpected null but was:<%s*(.-)%s*>") or st:match("[Ee]xpected: %<null%>%s*but was: <(.-)>")
  if act then
    return { expected = "null", actual = act }
  end
end

-- assertNotNull falló: tiene el valor pero esperaba not null
-- En JUnit 4 no deja expected/actual — cae a capa 3
-- En JUnit 5: "expected: not <null>"
EXTRACTORS.assert_not_null = function(st)
  if st:match("[Ee]xpected: not %<null%>") then
    return { expected = "not null", actual = "null" }
  end
end

-- assertThrows: esperaba una excepción que no ocurrió
EXTRACTORS.assert_throws = function(st)
  local exp = st:match("[Ee]xpected%s+(.-)%s+to be thrown") or st:match("expected:%s*<(.-)>%s*but nothing was thrown")
  if exp then
    return { expected = exp .. " (excepción esperada)", actual = "ninguna excepción" }
  end
end

-- Hamcrest assertThat: "Expected: 5 \n but: was <3>"
EXTRACTORS.hamcrest = function(st)
  local exp = st:match("\nExpected:%s*(.-)%s*\n") or st:match("Expected:%s*(.+)")
  local act = st:match("\n%s*but:%s*(.-)%s*\n") or st:match("but:%s*(.+)")
  if exp or act then
    return {
      expected = exp and vim.trim(exp) or nil,
      actual = act and vim.trim(act) or nil,
    }
  end
end

-- AssertJ hasSize: "Expected size: 3 but was: 5"
EXTRACTORS.assertj_size = function(st)
  local exp = st:match("[Ee]xpected size:%s*(%d+)")
  local act = st:match("but was:%s*(%d+)")
  if exp then
    return { expected = "size " .. exp, actual = act and ("size " .. act) or nil }
  end
end

-- AssertJ contains: "to contain: <x> but could not find: <y>"
EXTRACTORS.assertj_contains = function(st)
  local exp = st:match("to contain:%s*<(.-)>")
  local act = st:match("could not find:%s*<(.-)>")
  if exp then
    return { expected = "contains <" .. exp .. ">", actual = act and ("missing: " .. act) or nil }
  end
end

-- ─── Detección: Capa 2 — mensaje custom ──────────────────────────────────────

---Extrae el mensaje custom de un assertion si existe.
---@param st string
---@return string|nil
local function extract_custom_message(st)
  -- JUnit 5: assertTrue(condition, "mensaje") → "mensaje ==> expected: <true> but was: <false>"
  local msg = st:match("^(.-)%s*==>")
  if msg and msg ~= "" and not msg:match("^%s*at ") then
    return vim.trim(msg)
  end

  -- JUnit 4: assertTrue("mensaje", condition) → el mensaje aparece antes del AssertionError
  -- El formato es: "mensaje" seguido de AssertionError en la siguiente línea
  msg = st:match("^(.-)%\njava%.lang%.AssertionError")
  if msg and msg ~= "" and #msg < 200 then
    return vim.trim(msg)
  end

  return nil
end

-- ─── Detección: Capa 3 — línea del código fuente ─────────────────────────────

---Extrae la referencia al archivo y línea del código del usuario desde el stacktrace.
---Busca la primera línea "at" que no sea de framework.
---@param st string
---@return string|nil file   nombre del archivo (ej: "GameTest.java")
---@return number|nil line_nr número de línea
---@return string|nil class_method  "ClassName.methodName"
local function extract_source_location(st)
  for _, line in ipairs(vim.split(st, "\n")) do
    local trimmed = vim.trim(line)
    if trimmed:match("^at ") and not is_noise_frame(trimmed) then
      -- "at com.course.GameTest.when_chooseRock(GameTest.java:42)"
      local file = trimmed:match("%((.-):%d+%)")
      local line_nr = tonumber(trimmed:match("%:(%d+)%)"))
      local cm = trimmed:match("at%s+[%w%.]+%.([%w]+%.[%w_]+)%(")
      return file, line_nr, cm
    end
  end
  return nil, nil, nil
end

---Lee una línea específica de un archivo Java en el proyecto.
---@param filename string  nombre del archivo (ej: "GameTest.java")
---@param line_nr  number  número de línea
---@return string|nil
local function read_source_line(filename, line_nr)
  if not filename or not line_nr then
    return nil
  end

  -- Buscar el archivo en src/test/java y src/main/java
  local cwd = vim.fn.getcwd()
  local candidates = vim.fn.glob(cwd .. "/src/**/" .. filename, false, true)

  for _, path in ipairs(candidates) do
    local f = io.open(path, "r")
    if f then
      local current = 0
      for line in f:lines() do
        current = current + 1
        if current == line_nr then
          f:close()
          return vim.trim(line)
        end
      end
      f:close()
    end
  end
  return nil
end

-- ─── Detección: tipo de assertion sin valores ─────────────────────────────────

---Determina qué tipo de assertion falló cuando no hay expected/actual.
---@param st string
---@return string  descripción legible
local function detect_assertion_type(st)
  if st:match("assertTrue") or st:match("assertThat.*isTrue") then
    return "assertTrue — condición evaluó false"
  elseif st:match("assertFalse") or st:match("assertThat.*isFalse") then
    return "assertFalse — condición evaluó true"
  elseif st:match("assertNotNull") or st:match("assertThat.*isNotNull") then
    return "assertNotNull — el valor fue null"
  elseif st:match("assertNotEquals") then
    return "assertNotEquals — los valores son iguales (se esperaba que fueran distintos)"
  elseif st:match("assertSame") then
    return "assertSame — las referencias no apuntan al mismo objeto"
  elseif st:match("assertNotSame") then
    return "assertNotSame — las referencias apuntan al mismo objeto"
  elseif st:match("assertThat.*isEmpty") then
    return "assertThat — se esperaba colección vacía"
  elseif st:match("assertThat.*isNotEmpty") then
    return "assertThat — se esperaba colección no vacía"
  elseif st:match("AssertionError") then
    return "AssertionError — condición falló"
  end
  return "Assertion falló"
end

-- ─── API pública ──────────────────────────────────────────────────────────────

---Analiza el stacktrace y determina la capa y datos disponibles.
---
---@param stacktrace string
---@return table
---  {
---    kind          string   "diff"|"message"|"source"|"exception"|"unknown"
---    expected      string|nil
---    actual        string|nil
---    message       string|nil   mensaje custom del assertion
---    assertion_type string|nil  tipo de assertion detectado
---    file          string|nil   nombre del archivo fuente
---    line_nr       number|nil   número de línea
---    source_line   string|nil   contenido de la línea
---    clean_frames  string[]     stacktrace limpio sin ruido
---  }
function M.extract(stacktrace)
  if not stacktrace or stacktrace == "" then
    return { kind = "unknown", clean_frames = {} }
  end

  local result = {
    kind = "unknown",
    expected = nil,
    actual = nil,
    message = nil,
    assertion_type = nil,
    file = nil,
    line_nr = nil,
    source_line = nil,
    clean_frames = {},
  }

  -- Extraer ubicación del código fuente (útil para todas las capas)
  result.file, result.line_nr, _ = extract_source_location(stacktrace)
  if result.file and result.line_nr then
    result.source_line = read_source_line(result.file, result.line_nr)
  end

  -- Stacktrace limpio (para capas 3 y 4)
  result.clean_frames = clean_stacktrace(stacktrace)

  -- ── Capa 1: expected/actual explícito ──────────────────────────────────
  for _, extractor in pairs(EXTRACTORS) do
    local r = extractor(stacktrace)
    if r then
      result.kind = "diff"
      result.expected = r.expected
      result.actual = r.actual
      return result
    end
  end

  -- ── Capa 2: mensaje custom ─────────────────────────────────────────────
  local custom_msg = extract_custom_message(stacktrace)
  if custom_msg then
    result.kind = "message"
    result.message = custom_msg
    result.assertion_type = detect_assertion_type(stacktrace)
    return result
  end

  -- ── Capa 3: AssertionError sin valores ─────────────────────────────────
  if stacktrace:match("AssertionError") then
    result.kind = "source"
    result.assertion_type = detect_assertion_type(stacktrace)
    return result
  end

  -- ── Capa 4: excepción inesperada ───────────────────────────────────────
  if stacktrace:match("Exception") or stacktrace:match("Error") then
    result.kind = "exception"
    return result
  end

  return result
end

---Muestra el resultado del test según su kind:
---  diff      → side-by-side expected vs actual
---  message   → float con mensaje custom + línea del código
---  source    → float con tipo de assertion + línea del código
---  exception → float con stacktrace limpio
---  unknown   → float con stacktrace completo
---
---@param test table  { name, stacktrace, message, ... }
function M.show(test)
  if not test then
    return
  end

  local st = test.stacktrace
  if not st or st == "" then
    vim.notify("No hay stacktrace disponible para: " .. (test.name or "?"), vim.log.levels.INFO)
    return
  end

  local info = M.extract(st)

  if info.kind == "diff" then
    M._show_diff(test, info)
  elseif info.kind == "message" or info.kind == "source" then
    M._show_assertion_detail(test, info)
  else
    M._show_stacktrace(test, info)
  end
end

-- ─── Renderizado: Capa 1 — diff side-by-side ─────────────────────────────────

function M._show_diff(test, info)
  local exp_lines = vim.split(info.expected or "(no disponible)", "\n")
  local act_lines = vim.split(info.actual or "(no disponible)", "\n")

  local exp_buf = vim.api.nvim_create_buf(false, true)
  local act_buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(exp_buf, 0, -1, false, exp_lines)
  vim.api.nvim_buf_set_lines(act_buf, 0, -1, false, act_lines)

  for _, buf in ipairs({ exp_buf, act_buf }) do
    vim.api.nvim_set_option_value("filetype", "text", { buf = buf })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  end

  local width = math.min(120, vim.o.columns - 4)
  local height = math.min(20, vim.o.lines - 8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local half = math.floor(width / 2) - 1

  local exp_win = vim.api.nvim_open_win(exp_buf, true, {
    relative = "editor",
    width = half,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = "  Expected",
    title_pos = "center",
  })
  local act_win = vim.api.nvim_open_win(act_buf, false, {
    relative = "editor",
    width = half,
    height = height,
    row = row,
    col = col + half + 2,
    border = "rounded",
    title = "  Actual",
    title_pos = "center",
  })

  vim.api.nvim_set_current_win(exp_win)
  vim.cmd("diffthis")
  vim.api.nvim_set_current_win(act_win)
  vim.cmd("diffthis")

  local function close_both()
    vim.cmd("diffoff!")
    if vim.api.nvim_win_is_valid(exp_win) then
      vim.api.nvim_win_close(exp_win, true)
    end
    if vim.api.nvim_win_is_valid(act_win) then
      vim.api.nvim_win_close(act_win, true)
    end
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, close_both, { buffer = exp_buf, silent = true })
    vim.keymap.set("n", key, close_both, { buffer = act_buf, silent = true })
  end
end

-- ─── Renderizado: Capas 2 y 3 — detalle de assertion ─────────────────────────

function M._show_assertion_detail(test, info)
  local lines = {}
  local function add(s)
    table.insert(lines, s or "")
  end

  add("  ✗ " .. (info.assertion_type or "Assertion falló"))
  add("  " .. string.rep("─", 50))
  add("")

  -- Mensaje custom (capa 2)
  if info.message then
    add("  Mensaje: " .. info.message)
    add("")
  end

  -- Ubicación en el código fuente (capas 2 y 3)
  if info.file and info.line_nr then
    add("  Archivo : " .. info.file .. ", línea " .. info.line_nr)
    if info.source_line then
      add("  Código  : " .. info.source_line)
    end
    add("")
  end

  -- Stacktrace limpio
  if #info.clean_frames > 0 then
    add("  " .. string.rep("─", 50))
    add("  Stacktrace:")
    add("")
    for _, frame in ipairs(info.clean_frames) do
      add("  " .. frame)
    end
  end

  add("")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("filetype", "java", { buf = buf })

  local max_w = 0
  for _, l in ipairs(lines) do
    if #l > max_w then
      max_w = #l
    end
  end
  local width = math.min(math.max(max_w + 4, 60), vim.o.columns - 6)
  local height = math.min(#lines + 2, vim.o.lines - 6)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = "  ✗ " .. (test.name or ""),
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  -- Highlights
  local ns = vim.api.nvim_create_namespace("java_diff_detail")
  for i, line in ipairs(lines) do
    local lnum = i - 1
    if line:match("^%s*✗") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticError", lnum, 0, -1)
    elseif line:match("^%s*Mensaje") or line:match("^%s*Código") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticInfo", lnum, 0, -1)
    elseif line:match("^%s*Archivo") then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", lnum, 0, -1)
    elseif line:match("─") then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", lnum, 0, -1)
    end
  end

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, silent = true })
  end
end

-- ─── Renderizado: Capas 4 — stacktrace limpio ────────────────────────────────

function M._show_stacktrace(test, info)
  local frames = (info and #info.clean_frames > 0) and info.clean_frames or vim.split(test.stacktrace or "", "\n")

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, frames)
  vim.api.nvim_set_option_value("filetype", "java", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local width = math.min(100, vim.o.columns - 10)
  local height = math.min(#frames + 2, vim.o.lines - 6)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = "  Stacktrace: " .. (test.name or ""),
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("wrap", false, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, silent = true })
  end
end

return M
