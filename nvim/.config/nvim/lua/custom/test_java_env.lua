-- lua/custom/test_java_env.lua
--
-- Responsabilidad única: consultar y reconciliar el entorno Java del proyecto.
--
-- No sabe nada de: UI de tests, árbol, Maven runner.
-- Solo lee archivos, consulta jdtls y sdkman, y devuelve un estado.
--
-- API pública:
--   M.check(cwd)        → tabla de estado completo
--   M.show_panel()      → float con info formateada + acción de ajuste
--   M.java_home_for(cwd) → string|nil  JAVA_HOME a usar para Maven

local M = {}

-- Importar java_runtime para mostrar el runtime activo sincronizado
-- pcall para evitar error circular si java_runtime no está disponible aún
local function get_active_runtime()
  local ok, jr = pcall(require, "custom.java_runtime")
  if ok then
    return jr.get_active()
  end
  return nil
end

-- ─── Leer pom.xml ─────────────────────────────────────────────────────────────

---Lee la versión Java requerida por el pom.xml del proyecto.
---@param cwd string
---@return string|nil version  ej: "8", "11", "17", "21"
---@return string     source   de dónde se leyó, para mostrar al usuario
local function read_pom_version(cwd)
  local pom = cwd .. "/pom.xml"
  local f = io.open(pom, "r")
  if not f then
    return nil, "sin pom.xml"
  end
  local content = f:read("*a")
  f:close()

  -- Orden de prioridad de propiedades
  local version, source

  version = content:match("<maven%.compiler%.release>%s*([%d%.]+)%s*</maven%.compiler%.release>")
  if version then
    source = "maven.compiler.release"
  end

  if not version then
    version = content:match("<maven%.compiler%.source>%s*([%d%.]+)%s*</maven%.compiler%.source>")
    if version then
      source = "maven.compiler.source"
    end
  end

  if not version then
    version = content:match("<java%.version>%s*([%d%.]+)%s*</java%.version>")
    if version then
      source = "java.version"
    end
  end

  -- Normalizar: "1.8" → "8"
  if version == "1.8" then
    version = "8"
  end

  if not version then
    return nil, "pom.xml sin versión Java declarada"
  end

  return version, source
end

-- ─── Consultar jdtls ──────────────────────────────────────────────────────────

---Devuelve la versión Java que jdtls tiene activa actualmente.
---Lee el runtime activo desde el cliente LSP si está disponible.
---@return string|nil  ej: "21", "17", "8"
local function read_jdtls_version()
  -- Intentar leer desde el cliente jdtls activo
  local clients = vim.lsp.get_clients and vim.lsp.get_clients({ name = "jdtls" })
    or vim.lsp.get_active_clients and vim.lsp.get_active_clients({ name = "jdtls" })
    or {}

  if #clients == 0 then
    return nil
  end

  local client = clients[1]
  -- El runtime activo está en la configuración del cliente
  local settings = client.config and client.config.settings
  if not settings then
    return nil
  end

  local java_home = settings.java and settings.java.home or nil

  if not java_home then
    return nil
  end

  -- Extraer versión del path: /path/to/java/21.0.8-tem → "21"
  return java_home:match("/java/(%d+)%.") or java_home:match("/java/(%d+)$")
end

-- ─── Consultar Maven / JAVA_HOME activo ───────────────────────────────────────

---Devuelve la versión Java que Maven usará (según JAVA_HOME del entorno).
---@return string|nil  ej: "21"
---@return string|nil  path completo del JAVA_HOME
local function read_maven_version()
  local java_home = os.getenv("JAVA_HOME")

  -- Fallback 1: sdkman current symlink
  if not java_home or java_home == "" then
    local sdkman_current = (os.getenv("HOME") or "") .. "/.sdkman/candidates/java/current"
    local link = vim.fn.resolve(sdkman_current)
    if link ~= sdkman_current then
      java_home = link
    end
  end

  -- Intentar extraer versión del path
  if java_home and java_home ~= "" then
    local version = java_home:match("/java/(%d+)%.") or java_home:match("/java/(%d+)$") or java_home:match("%-(%d+)%-") -- ej: temurin-21-...
    if version then
      return version, java_home
    end
  end

  -- Fallback 2: ejecutar java -version y parsear el output
  local handle = io.popen("java -version 2>&1")
  if handle then
    local output = handle:read("*a")
    handle:close()
    -- 'java version "21.0.8"' o 'openjdk version "1.8.0_402"'
    local ver_str = output:match('"(%d+)[."]') or output:match('"1%.(%d+)')
    if ver_str then
      return ver_str, java_home or "PATH"
    end
  end

  return nil, nil
end

-- ─── Listar JDKs disponibles en sdkman ───────────────────────────────────────

---Devuelve lista de JDKs instalados en sdkman.
---@return table[]  lista de { version="21", path="...", is_current=bool }
local function list_sdkman_javas()
  local sdkman_dir = (os.getenv("HOME") or "") .. "/.sdkman/candidates/java"
  local handle = io.popen("ls " .. sdkman_dir .. " 2>/dev/null")
  if not handle then
    return {}
  end

  local current_link = vim.fn.resolve(sdkman_dir .. "/current")
  local result = {}

  for line in handle:lines() do
    local name = vim.trim(line)
    if name ~= "" and name ~= "current" then
      local path = sdkman_dir .. "/" .. name
      local major = name:match("^(%d+)%.") or name:match("^(%d+)$")
      -- Normalizar java 8
      if major == "1" then
        major = "8"
      end
      table.insert(result, {
        name = name,
        major = major,
        path = path,
        is_current = (path == current_link),
      })
    end
  end
  handle:close()

  -- Ordenar por versión major
  table.sort(result, function(a, b)
    return tonumber(a.major or 0) < tonumber(b.major or 0)
  end)

  return result
end

-- ─── API pública ──────────────────────────────────────────────────────────────

---Consulta el estado completo del entorno Java para el proyecto en cwd.
---@param cwd string  raíz del proyecto (vim.fn.getcwd() si se omite)
---@return table estado
---  {
---    required       string|nil   versión que pide el pom.xml
---    required_src   string       de dónde se leyó o mensaje si falta
---    maven          string|nil   versión que usará Maven ahora
---    maven_home     string|nil   path del JAVA_HOME activo
---    jdtls          string|nil   versión que tiene jdtls
---    available      table[]      JDKs instalados en sdkman
---    compatible     boolean      maven == required (o required es nil)
---    missing        boolean      required no está en available
---    has_pom        boolean      existe pom.xml
---    pom_unversioned boolean     pom.xml existe pero sin versión declarada
---  }
function M.check(cwd)
  cwd = cwd or vim.fn.getcwd()

  local has_pom = vim.fn.filereadable(cwd .. "/pom.xml") == 1
  local required, required_src = read_pom_version(cwd)
  local maven_ver, maven_home = read_maven_version()
  local jdtls_ver = read_jdtls_version()
  local available = list_sdkman_javas()

  -- ¿El required está instalado en sdkman?
  local missing = false
  if required then
    missing = true
    for _, jdk in ipairs(available) do
      if jdk.major == required then
        missing = false
        break
      end
    end
  end

  -- ¿Maven usará la versión correcta?
  local compatible = (not required) or (maven_ver == required)

  return {
    required = required,
    required_src = required_src or "sin pom.xml",
    maven = maven_ver,
    maven_home = maven_home,
    jdtls = jdtls_ver,
    available = available,
    compatible = compatible,
    missing = missing,
    has_pom = has_pom,
    pom_unversioned = has_pom and not required,
  }
end

---Devuelve el JAVA_HOME que debe usarse para Maven en este proyecto.
---Si todo es compatible devuelve nil (no hace falta cambiar nada).
---@param cwd string
---@return string|nil java_home
function M.java_home_for(cwd)
  local env = M.check(cwd)

  -- Sin requerimiento → no cambiar nada
  if not env.required then
    return nil
  end

  -- Ya compatible → no cambiar nada
  if env.compatible then
    return nil
  end

  -- Versión requerida no instalada → no se puede resolver
  if env.missing then
    return nil
  end

  -- Buscar el path del JDK requerido
  for _, jdk in ipairs(env.available) do
    if jdk.major == env.required then
      return jdk.path
    end
  end

  return nil
end

---Muestra un float con el estado del entorno Java del proyecto.
---Usa el runtime sincronizado como fuente de verdad para Maven y Runner.
function M.show_panel()
  local cwd = vim.fn.getcwd()
  local env = M.check(cwd)
  local active = get_active_runtime()

  -- ── Determinar estado real de Maven y Runner ───────────────────────────────
  -- El runtime sincronizado es la fuente de verdad:
  --   - Si active existe y su major == required → Maven y Runner están ok
  --   - Si required está missing → falla real, no hay forma de corregirlo
  --   - Si no hay active aún → usar env.compatible como fallback

  local required = env.required

  local maven_ok, runner_ok
  if env.missing then
    -- JDK requerido no instalado → falla real en ambos
    maven_ok = false
    runner_ok = false
  elseif active then
    -- Runtime sincronizado disponible → es la verdad
    maven_ok = (active.major == required) or not required
    runner_ok = maven_ok
  else
    -- Sin runtime aún → usar compatibilidad del sistema
    maven_ok = env.compatible
    runner_ok = env.compatible
  end

  local lines = {}
  local function add(s)
    table.insert(lines, s or "")
  end

  -- ── Cabecera ───────────────────────────────────────────────────────────────
  add("  Java Environment")
  add("  " .. string.rep("─", 44))
  add("")

  -- ── Proyecto ──────────────────────────────────────────────────────────────
  add("  Proyecto : " .. vim.fn.fnamemodify(cwd, ":t"))

  -- ── jdtls: siempre Java 21 para el LSP, es correcto ───────────────────────
  local jdtls_ver = env.jdtls or "21"
  add("  jdtls    : Java " .. jdtls_ver .. "  (configuración del LSP)")

  add("")

  -- ── pom.xml ───────────────────────────────────────────────────────────────
  if not env.has_pom then
    add("  pom.xml  : no encontrado")
  elseif env.pom_unversioned then
    add("  pom.xml  : ⚠ sin versión Java declarada")
    add("             Agrega en pom.xml:")
    add("               <maven.compiler.release>" .. (env.maven or "?") .. "</maven.compiler.release>")
  else
    add("  pom.xml  : Java " .. required .. "  (vía " .. env.required_src .. ")")
  end

  add("")

  -- ── Maven ─────────────────────────────────────────────────────────────────
  if not required then
    add("  Maven    : Java " .. (env.maven or "?") .. "  (sin versión declarada en pom.xml)")
  elseif maven_ok then
    add("  Maven    : ✓ Java " .. required)
  else
    add("  Maven    : ✗ Java " .. required .. " no instalado")
  end

  -- ── Runner / LSP ──────────────────────────────────────────────────────────
  if not required then
    add("  Runner   : Java " .. (env.maven or "?"))
  elseif runner_ok then
    add("  Runner   : ✓ Java " .. required)
  else
    add("  Runner   : ✗ Java " .. required .. " no instalado")
  end

  -- ── Mensaje de acción si hay falla ────────────────────────────────────────
  if env.missing and required then
    add("")
    add("  ⚠ Java " .. required .. " requerido pero no instalado")
    add("    En devpod agrega en devcontainer.json:")
    add('      "additionalVersions": "' .. required .. '"')
    add("    Luego: devpod delete && devpod up")
    add("")
    add("    En local:")
    add("      sdk install java <versión>-tem")
  end

  -- ── JDKs disponibles ──────────────────────────────────────────────────────
  add("")
  add("  " .. string.rep("─", 44))
  add("  JDKs instalados:")
  add("")

  for _, jdk in ipairs(env.available) do
    local marker = jdk.is_current and "● " or "  "
    local req_mark = (jdk.major == required) and " ← proyecto" or ""
    add("  " .. marker .. jdk.name .. req_mark)
  end

  if #env.available == 0 then
    add("  (ninguno encontrado)")
  end

  add("")

  -- ── Crear float ───────────────────────────────────────────────────────────
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  local max_line = 50
  for _, l in ipairs(lines) do
    if #l > max_line then
      max_line = #l
    end
  end
  local width = math.min(max_line + 4, math.floor(vim.o.columns * 0.80))
  local height = math.min(#lines + 2, vim.o.lines - 6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = "rounded",
    title = " Java Environment ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })

  -- ── Highlights ────────────────────────────────────────────────────────────
  local ns = vim.api.nvim_create_namespace("java_env_panel")
  for i, line in ipairs(lines) do
    local lnum = i - 1
    if line:match("^%s*✓") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", lnum, 0, -1)
    elseif line:match("^%s*✗") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticError", lnum, 0, -1)
    elseif line:match("^%s*⚠") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticWarn", lnum, 0, -1)
    elseif line:match("^%s*●") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticInfo", lnum, 0, -1)
    elseif line:match("←") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", lnum, 0, -1)
    elseif line:match("─") then
      vim.api.nvim_buf_add_highlight(buf, ns, "Comment", lnum, 0, -1)
    elseif line:match("Java Environment") then
      vim.api.nvim_buf_add_highlight(buf, ns, "Title", lnum, 0, -1)
    end
  end

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, "<cmd>close<CR>", { buffer = buf, silent = true })
  end
end

return M
