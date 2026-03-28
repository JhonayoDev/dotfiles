-- lua/custom/java_runtime.lua
--
-- Responsabilidad única: sincronizar el runtime Java correcto para el proyecto
-- actual en las tres capas: jdtls (LSP), Maven (tests) y DAP (debug).
--
-- No reemplaza ni modifica test_java_env — lo usa como fuente de verdad.
-- No modifica test_runner — este ya lee test_java_env directamente.
--
-- Flujo:
--   on_attach de jdtls → java_runtime.sync(cwd)
--     ├── test_java_env.check() → required = "8" | "17" | "21" | nil
--     ├── jdtls.set_runtime("JavaSE-X")   → automático si disponible
--     ├── DAP config → JAVA_HOME en env   → automático
--     └── Si no disponible → notificar + fallback interactivo opcional
--
-- API pública:
--   M.sync(cwd)       sincronizar todo al runtime correcto
--   M.get_active()    runtime activo actualmente { name, java_home, major }
--   M.status()        estado de cada capa { jdtls, maven, dap, required }

local M = {}

local java_env = require("custom.test_java_env")

-- ─── Estado interno ───────────────────────────────────────────────────────────

local state = {
  active = nil, -- { name, java_home, major }  runtime activo actualmente
}

-- ─── Mapeo de versiones ───────────────────────────────────────────────────────
-- Convierte versión major ("8", "17", "21") al nombre que usa jdtls.
-- jdtls usa el formato "JavaSE-X" o "JavaSE-1.X" para Java 8.

local JDTLS_RUNTIME_NAMES = {
  ["8"] = "JavaSE-1.8",
  ["11"] = "JavaSE-11",
  ["17"] = "JavaSE-17",
  ["21"] = "JavaSE-21",
}

local function to_jdtls_name(major)
  return JDTLS_RUNTIME_NAMES[major] or ("JavaSE-" .. major)
end

-- ─── Sincronización: jdtls ────────────────────────────────────────────────────

---Aplica el runtime a jdtls via set_runtime().
---@param jdtls_name string  ej: "JavaSE-1.8"
---@return boolean  true si se aplicó correctamente
local function sync_jdtls(jdtls_name)
  local ok, jdtls = pcall(require, "jdtls")
  if not ok then
    return false
  end

  -- set_runtime acepta string directo con el nombre del runtime
  local success, err = pcall(jdtls.set_runtime, jdtls_name)
  if not success then
    vim.notify("java_runtime: no se pudo aplicar " .. jdtls_name .. " a jdtls\n" .. tostring(err), vim.log.levels.WARN)
    return false
  end
  return true
end

-- ─── Sincronización: DAP ──────────────────────────────────────────────────────

---Aplica JAVA_HOME a todas las configuraciones DAP de Java.
---@param java_home string  path al JDK
local function sync_dap(java_home)
  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end

  if not dap.configurations.java then
    return
  end

  for _, config in ipairs(dap.configurations.java) do
    config.env = config.env or {}
    config.env.JAVA_HOME = java_home
  end
end

-- ─── Fallback interactivo ─────────────────────────────────────────────────────

---Muestra un selector para elegir un runtime alternativo cuando el requerido
---no está instalado.
---@param required string   versión requerida que falta (ej: "11")
---@param available table[] lista de JDKs disponibles de test_java_env
---@param on_select function(jdk) callback con el JDK elegido
local function prompt_fallback(required, available, on_select)
  if #available == 0 then
    vim.notify(
      "java_runtime: Java " .. required .. " no instalado y no hay alternativas en sdkman",
      vim.log.levels.ERROR
    )
    return
  end

  local options = {}
  for _, jdk in ipairs(available) do
    table.insert(options, jdk.name .. " (Java " .. (jdk.major or "?") .. ")")
  end

  vim.ui.select(options, {
    prompt = "Java " .. required .. " no instalado — elegir alternativa:",
  }, function(choice, idx)
    if choice and idx then
      on_select(available[idx])
    end
  end)
end

-- ─── API pública ──────────────────────────────────────────────────────────────

---Devuelve el runtime activo actualmente.
---@return table|nil  { name, java_home, major }
function M.get_active()
  return state.active
end

---Devuelve el estado de cada capa.
---@return table
function M.status()
  local cwd = vim.fn.getcwd()
  local env = java_env.check(cwd)
  return {
    required = env.required,
    active = state.active,
    jdtls = env.jdtls,
    maven = env.maven,
    missing = env.missing,
  }
end

---Sincroniza el runtime correcto para el proyecto en cwd.
---Aplica automáticamente a jdtls, Maven (via DAP env) y notifica el resultado.
---Si la versión requerida no está instalada, ofrece fallback interactivo.
---
---@param cwd string|nil  raíz del proyecto (vim.fn.getcwd() si se omite)
function M.sync(cwd)
  cwd = cwd or vim.fn.getcwd()
  local env = java_env.check(cwd)

  -- Sin requerimiento declarado en pom.xml
  if not env.required then
    if env.pom_unversioned then
      vim.notify(
        " Java_runtime: pom.xml sin versión Java declarada — usando Java " .. (env.maven or "?") .. " del sistema",
        vim.log.levels.WARN
      )
    end
    -- No hay nada que sincronizar
    return
  end

  -- Versión requerida no instalada → fallback interactivo
  if env.missing then
    vim.notify(
      "⚠ Java_runtime: Java "
        .. env.required
        .. " requerido pero no instalado en sdkman\n"
        .. "  Instalá con: sdk install java <versión>-tem\n"
        .. "  Seleccioná un runtime alternativo para continuar.",
      vim.log.levels.WARN
    )

    prompt_fallback(env.required, env.available, function(jdk)
      local jdtls_name = to_jdtls_name(jdk.major)
      sync_jdtls(jdtls_name)
      sync_dap(jdk.path)
      state.active = { name = jdtls_name, java_home = jdk.path, major = jdk.major }
      vim.notify(
        " Java_runtime: usando Java "
          .. jdk.major
          .. " como fallback\n"
          .. "  jdtls → "
          .. jdtls_name
          .. "\n"
          .. "  DAP   → Java "
          .. jdk.major,
        vim.log.levels.INFO
      )
    end)
    return
  end

  -- Versión requerida disponible → encontrar el path
  local java_home = java_env.java_home_for(cwd)
  if not java_home then
    -- Ya es compatible (maven == required), no hace falta cambiar nada
    state.active = {
      name = to_jdtls_name(env.required),
      java_home = env.maven_home or "",
      major = env.required,
    }
    vim.notify(" Java " .. env.required .. " ✓  (ya configurado correctamente)", vim.log.levels.INFO)
    return
  end

  local jdtls_name = to_jdtls_name(env.required)

  -- Aplicar a jdtls
  local jdtls_ok = sync_jdtls(jdtls_name)

  -- Aplicar a DAP
  sync_dap(java_home)

  -- Guardar estado activo
  state.active = {
    name = jdtls_name,
    java_home = java_home,
    major = env.required,
  }

  -- Notificación con resultado
  local jdtls_status = jdtls_ok and "✓" or "⚠ falló"
  vim.notify(
    " Proyecto requiere Java "
      .. env.required
      .. " — runtime sincronizado\n"
      .. "  jdtls → "
      .. jdtls_name
      .. "  "
      .. jdtls_status
      .. "\n"
      .. "  Maven → Java "
      .. env.required
      .. "  ✓ (automático)\n"
      .. "  DAP   → Java "
      .. env.required
      .. "  ✓",
    vim.log.levels.INFO
  )
end

return M
