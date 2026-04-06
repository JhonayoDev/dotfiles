-- lua/custom/java_sdkman.lua
--
-- Responsabilidad única: ser la fuente de verdad sobre SDKMAN y los JDKs
-- disponibles en el sistema, independientemente del entorno.
--
-- Funciona en:
--   - PC local     → ~/.sdkman         (instalación de usuario estándar)
--   - DevPod       → /usr/local/sdkman (instalado por Dev Container feature)
--   - Cualquier entorno con $SDKMAN_DIR definido
--
-- No sabe nada de: jdtls, Maven, UI, DAP.
-- Solo resuelve rutas y versiones.
--
-- API pública:
--   M.dir()                 → string     ruta raíz de SDKMAN
--   M.candidates_dir()      → string     ruta a candidates/java
--   M.list_javas()          → table[]    JDKs instalados
--   M.find_java(major)      → table|nil  primer JDK que coincide con major
--   M.current_java()        → table|nil  JDK activo (symlink current)
--   M.java_home(major)      → string|nil path del JDK para esa versión major

local M = {}

-- ─── Resolución de SDKMAN_DIR ─────────────────────────────────────────────────
-- Orden de prioridad:
--   1. Variable de entorno $SDKMAN_DIR  (siempre la más confiable)
--   2. /usr/local/sdkman               (Dev Container feature)
--   3. ~/.sdkman                       (instalación de usuario estándar)

local function resolve_sdkman_dir()
  -- 1. Variable de entorno
  local from_env = os.getenv("SDKMAN_DIR")
  if from_env and from_env ~= "" then
    return from_env
  end

  -- 2. Instalación global (devpod / dev containers)
  if vim.fn.isdirectory("/usr/local/sdkman") == 1 then
    return "/usr/local/sdkman"
  end

  -- 3. Instalación de usuario estándar
  local home = os.getenv("HOME") or ""
  return home .. "/.sdkman"
end

-- Cacheamos el resultado para no recalcular en cada llamada
local _sdkman_dir = nil

---Devuelve la ruta raíz de SDKMAN.
---@return string
function M.dir()
  if not _sdkman_dir then
    _sdkman_dir = resolve_sdkman_dir()
  end
  return _sdkman_dir
end

---Devuelve la ruta al directorio de candidatos Java.
---@return string
function M.candidates_dir()
  return M.dir() .. "/candidates/java"
end

-- ─── Listado de JDKs instalados ───────────────────────────────────────────────

---Extrae la versión major de un nombre de JDK.
--- "21.0.10-ms"  → "21"
--- "8.0.482-tem" → "8"
--- "17.0.9-tem"  → "17"
---@param name string
---@return string|nil
local function extract_major(name)
  -- Caso especial: "1.8.x" → major es "8"
  local one_eight = name:match("^1%.8%.")
  if one_eight then
    return "8"
  end

  -- Caso general: primer número antes del primer punto
  local major = name:match("^(%d+)%.")
  if major then
    return major
  end

  -- Sin punto: número directo (poco común pero posible)
  return name:match("^(%d+)$")
end

---Devuelve lista de JDKs instalados en SDKMAN.
---@return table[]  lista de { name, major, path, is_current }
function M.list_javas()
  local candidates = M.candidates_dir()
  local handle = io.popen("ls " .. candidates .. " 2>/dev/null")
  if not handle then
    return {}
  end

  local current_path = vim.fn.resolve(candidates .. "/current")
  local result = {}

  for line in handle:lines() do
    local name = vim.trim(line)
    if name ~= "" and name ~= "current" then
      local path = candidates .. "/" .. name
      local major = extract_major(name)
      table.insert(result, {
        name = name,
        major = major,
        path = path,
        is_current = (path == current_path),
      })
    end
  end
  handle:close()

  -- Ordenar por versión major numérica
  table.sort(result, function(a, b)
    return tonumber(a.major or 0) < tonumber(b.major or 0)
  end)

  return result
end

---Busca el primer JDK instalado que coincida con la versión major dada.
---No importa el sufijo (-ms, -tem, -amzn, etc.) ni el parche exacto.
---Ejemplo: find_java("21") encuentra "21.0.10-ms" o "21.0.11-tem"
---@param major string  ej: "8", "17", "21", "25"
---@return table|nil  { name, major, path, is_current }
function M.find_java(major)
  -- Normalizar: "1.8" → "8"
  if major == "1.8" then
    major = "8"
  end

  for _, jdk in ipairs(M.list_javas()) do
    if jdk.major == major then
      return jdk
    end
  end
  return nil
end

---Devuelve el JDK activo actualmente (el que apunta el symlink current).
---@return table|nil  { name, major, path, is_current }
function M.current_java()
  for _, jdk in ipairs(M.list_javas()) do
    if jdk.is_current then
      return jdk
    end
  end
  return nil
end

---Devuelve el path del JDK para una versión major dada.
---Shortcut de find_java(major).path para uso en configuraciones.
---@param major string
---@return string|nil
function M.java_home(major)
  local jdk = M.find_java(major)
  return jdk and jdk.path or nil
end

return M
