-- lua/custom/test_runner.lua
--
-- Responsabilidad única: ejecutar Maven y emitir eventos via callbacks.
--
-- No sabe nada de: UI, árbol, resultados previos, ni cómo se parseó el contexto.
-- Recibe un spec ya construido y notifica línea a línea y al terminar.
--
-- API pública:
--   M.run(spec, opts)   ejecuta Maven
--   M.cancel()          mata el job activo si existe
--   M.is_running()      boolean

local M = {}

-- Delegar detección de Java al módulo especializado
local java_env = require("custom.test_java_env")

-- ─── Estado interno ───────────────────────────────────────────────────────────

local state = {
  job_id = nil,
  running = false,
}

-- ─── Utilidades ───────────────────────────────────────────────────────────────

-- Detecta si el proyecto tiene mvnw o usa mvn global
local function maven_cmd(cwd)
  local mvnw = (cwd or vim.fn.getcwd()) .. "/mvnw"
  if vim.fn.filereadable(mvnw) == 1 then
    return "sh ./mvnw"
  end
  return "mvn"
end

-- Determina el JAVA_HOME correcto para el proyecto.
-- Delega a test_java_env que tiene la lógica completa de detección.
local function resolve_java_home(cwd)
  local java_home = java_env.java_home_for(cwd)
  if java_home then
    local env = java_env.check(cwd)
    vim.notify(" usando Java " .. (env.required or "?") .. " para este proyecto", vim.log.levels.INFO)
  end
  return java_home
end

-- Patrones de líneas que no aportan información útil al usuario.
-- Se filtran en Lua para no usar pipe en el shell (el pipe rompía
-- la recepción de output en proyectos JUnit 4 sin Spring/Hibernate).
local NOISE_PATTERNS = {
  "Rolled back transaction",
  "Began transaction",
  "HikariPool",
  "^Hibernate:",
  "o%.h%.e%.j%.MappingException",
  "^%s*at com%.sun%.",
  "^%s*at sun%.",
  "^%s*at java%.lang%.reflect%.",
}

local function is_noise(line)
  for _, pat in ipairs(NOISE_PATTERNS) do
    if line:match(pat) then
      return true
    end
  end
  return false
end

-- Detecta condiciones especiales en el output acumulado
local function analyze_output(lines)
  local result = {
    no_tests = false,
    context_failed = false,
    build_success = false,
  }
  for _, line in ipairs(lines) do
    if line:match("No tests were executed") then
      result.no_tests = true
    end
    if line:match("BUILD SUCCESS") then
      result.build_success = true
    end
    if
      line:match("Unable to start ApplicationContext")
      or line:match("Error creating bean")
      or line:match("APPLICATION FAILED TO START")
    then
      result.context_failed = true
    end
  end
  return result
end

-- ─── API pública ──────────────────────────────────────────────────────────────

---@return boolean
function M.is_running()
  return state.running
end

---Cancela el job activo si existe.
function M.cancel()
  if state.job_id then
    vim.fn.jobstop(state.job_id)
    state.job_id = nil
    state.running = false
  end
end

---Ejecuta Maven con el spec dado y notifica via callbacks.
---
---@param spec string  valor para -Dtest= (vacío = todos los tests)
---@param opts table
---  opts.cwd        string    directorio raíz del proyecto
---  opts.on_line    function(line)   callback por cada línea de output
---  opts.on_exit    function(code, analysis)  callback al terminar
---                   analysis = { no_tests, context_failed, build_success }
function M.run(spec, opts)
  if state.running then
    vim.notify("Ya hay una ejecución en curso.", vim.log.levels.WARN)
    return
  end

  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()
  local on_line = opts.on_line or function() end
  local on_exit = opts.on_exit or function() end

  local mvn = maven_cmd(cwd)
  local test_arg = spec ~= "" and ("-Dtest='" .. spec .. "'") or ""

  -- Detectar si el proyecto requiere un Java distinto al actual
  -- Ej: pom.xml con maven.compiler.release=8 en un sistema con Java 21
  local java_home = resolve_java_home(cwd)

  -- Script minimal sin pipe — preserva el exit code de Maven
  -- y evita problemas de buffering con proyectos JUnit 4
  local script_file = vim.fn.tempname() .. ".sh"
  local java_export = java_home and ("export JAVA_HOME='" .. java_home .. "'\n") or ""
  local script_content = "#!/bin/sh\n" .. java_export .. mvn .. " test " .. test_arg .. "\n"

  local sf = io.open(script_file, "w")
  if sf then
    sf:write(script_content)
    sf:close()
    vim.fn.system("chmod +x " .. script_file)
  else
    vim.notify("test_runner: no se pudo crear script temporal", vim.log.levels.ERROR)
    return
  end

  state.running = true
  state.job_id = nil

  -- Acumular output para el análisis final
  local accumulated = {}

  local function handle_data(data)
    if not data then
      return
    end
    vim.schedule(function()
      for _, line in ipairs(data) do
        if line ~= "" and not is_noise(line) then
          table.insert(accumulated, line)
          on_line(line)
        end
      end
    end)
  end

  state.job_id = vim.fn.jobstart({ "sh", script_file }, {
    cwd = cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(_, data)
      handle_data(data)
    end,
    on_stderr = function(_, data)
      handle_data(data)
    end,

    on_exit = function(_, exit_code)
      vim.schedule(function()
        state.running = false
        state.job_id = nil
        vim.fn.delete(script_file)

        -- Dar 300ms para que el SO flushee los XMLs en surefire-reports/
        -- antes de que el caller intente leerlos
        vim.defer_fn(function()
          local analysis = analyze_output(accumulated)
          on_exit(exit_code, analysis)
        end, 300)
      end)
    end,
  })
end

return M
