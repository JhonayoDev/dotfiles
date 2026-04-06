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
local sdkman = require("custom.java_sdkman")

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

  -- Fallback: sdkman current symlink (ruta dinámica, no hardcodeada)
  if not java_home or java_home == "" then
    local sdkman_current = sdkman.candidates_dir() .. "/current"
    local link = vim.fn.resolve(sdkman_current)
    if link ~= sdkman_current then
      java_home = link
    end
  end

  -- Intentar extraer versión del path
  if java_home and java_home ~= "" then
    local version = java_home:match("/java/(%d+)%.") or java_home:match("/java/(%d+)$") or java_home:match("%-(%d+)%-")
    if version then
      return version, java_home
    end
  end

  -- Fallback: ejecutar java -version y parsear el output
  local handle = io.popen("java -version 2>&1")
  if handle then
    local output = handle:read("*a")
    handle:close()
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
  return sdkman.list_javas()
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

---Muestra un float con el estado del entorno Java y una acción de ajuste.
function M.show_panel()
  local cwd = vim.fn.getcwd()
  local env = M.check(cwd)

  local lines = {}
  local function add(s)
    table.insert(lines, s or "")
  end

  add("  Java Environment ")
  add("  " .. string.rep("─", 44))
  add("")

  -- Proyecto
  add("  Proyecto : " .. vim.fn.fnamemodify(cwd, ":t"))

  -- Versión requerida por el pom
  if not env.has_pom then
    add("  pom.xml  : no encontrado")
  elseif env.pom_unversioned then
    add("  pom.xml  : ⚠ sin versión Java declarada")
    add("             Maven usará cualquier Java disponible")
    add("             Comportamiento puede diferir en otros IDEs")
    add("")
    add("  Sugerencia: agregar en pom.xml:")
    add("    <properties>")
    add("      <maven.compiler.release>" .. (env.maven or "?") .. "</maven.compiler.release>")
    add("    </properties>")
  else
    add("  pom.xml  : Java " .. env.required .. "  (vía " .. env.required_src .. ")")
  end

  add("")

  -- Estado de Maven
  local maven_icon = env.compatible and "✓" or "✗"
  add("  Maven    : " .. maven_icon .. " Java " .. (env.maven or "desconocido"))
  if env.maven_home then
    add("             " .. env.maven_home)
  end

  -- Estado de jdtls
  if env.jdtls then
    local jdtls_icon = (env.jdtls == env.required or not env.required) and "✓" or "⚠"
    add("  jdtls    : " .. jdtls_icon .. " Java " .. env.jdtls)
    if env.jdtls ~= env.required and env.required then
      add("             (distinto al requerido — normal si el LSP usa Java 21)")
    end
  else
    add("  jdtls    : no activo en este buffer")
  end

  -- Runtime activo sincronizado por java_runtime.lua
  local active = get_active_runtime()
  if active then
    add("")
    add("  " .. string.rep("─", 44))
    add("  Runtime sincronizado (java_runtime):")
    add("")
    local a_icon = (active.major == env.required) and "✓" or "⚠"
    add("  " .. a_icon .. " Java " .. active.major .. "  —  " .. active.name)
    add("    jdtls  ✓  Maven  ✓  DAP  ✓")
    if active.java_home and active.java_home ~= "" then
      add("    " .. active.java_home)
    end
  end

  add("")
  add("  " .. string.rep("─", 44))
  add("  JDKs disponibles en sdkman:")
  add("")

  for _, jdk in ipairs(env.available) do
    local marker = jdk.is_current and "● " or "  "
    local req_mark = (jdk.major == env.required) and " ← requerido" or ""
    add("  " .. marker .. jdk.name .. req_mark)
  end

  -- Aviso si falta el JDK requerido
  if env.missing and env.required then
    add("")
    add("  ✗ Java " .. env.required .. " no está instalado en sdkman")
    add("    Para instalarlo:")
    add("    sdk install java <versión>-tem")
    add("    Versiones disponibles: sdk list java | grep ^" .. env.required)
  end

  add("")
  add("  " .. string.rep("─", 44))

  -- Resumen final
  if not env.has_pom then
    add("    Sin pom.xml — usando Java " .. (env.maven or "?") .. " del sistema")
  elseif env.pom_unversioned then
    add("  ⚠ pom.xml sin versión — declararla evita sorpresas")
  elseif env.missing then
    add("  ✗ Java " .. env.required .. " requerido pero no instalado")
    add("    Los tests pueden fallar por incompatibilidad")
  elseif env.compatible then
    add("  ✓ Entorno compatible — Java " .. env.required)
  else
    add("  ⚠ Sistema: Java " .. (env.maven or "?") .. "  —  proyecto requiere Java " .. env.required)
    add("  ✓ El runner ajustará JAVA_HOME a Java " .. env.required .. " automáticamente")
    add("    (jdtls sigue usando Java " .. (env.jdtls or env.maven or "?") .. " para el LSP — es correcto)")
  end

  add("")

  -- Crear float
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- Ancho dinámico: el más largo de las líneas, acotado al 80% de columnas
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

  -- Highlights
  local ns = vim.api.nvim_create_namespace("java_env_panel")
  for i, line in ipairs(lines) do
    local lnum = i - 1
    if line:match("^%s*✓") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticOk", lnum, 0, -1)
    elseif line:match("^%s*✗") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticError", lnum, 0, -1)
    elseif line:match("^%s*⚠") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticWarn", lnum, 0, -1)
    elseif line:match("^%s*ℹ") then
      vim.api.nvim_buf_add_highlight(buf, ns, "DiagnosticInfo", lnum, 0, -1)
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
