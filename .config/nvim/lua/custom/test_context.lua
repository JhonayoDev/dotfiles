-- lua/custom/test_context.lua
--
-- Responsabilidad única: leer el buffer Java actual y devolver el contexto
-- necesario para construir un spec de Maven.
--
-- No sabe nada de: UI, Maven, XMLs, ni resultados previos.
-- Solo lee líneas de texto y devuelve una tabla.
--
-- API pública:
--   M.parse()                      → ctx
--   M.build_spec(ctx, with_method) → spec, label

local M = {}

-- ─── Estructura del contexto ──────────────────────────────────────────────────
--
-- framework        "junit4" | "junit5"
-- root_class       nombre simple de la clase raíz  (ej: "GameTest")
-- nested_chain     lista de clases @Nested hasta el cursor (ej: {"DoctorTest"})
-- method           nombre del método bajo el cursor (ej: "when_chooseRock...")
-- parent_class     clase que extiende la raíz, si existe (ej: "BaseTest")
-- runner           valor de @RunWith sin .class    (ej: "MockitoJUnitRunner")
-- is_parameterized true si el método/clase usa @ParameterizedTest o @Parameterized
-- is_repeated      true si usa @RepeatedTest
-- is_disabled      true si usa @Disabled o @Ignore (clase o método)
-- is_spring        true si hay anotación que levanta contexto Spring
-- surefire_pattern "indexed"            → JUnit4 @Parameterized (resultados con [0],[1]...)
--                  "expected_exception" → @Test(expected=...)
--                  nil                  → caso estándar
-- tags             lista de strings de @Tag
-- categories       lista de strings de @Category (JUnit 4)

-- ─── Pase 0: escaneo global del archivo ───────────────────────────────────────
-- Lee TODO el archivo para determinar framework, runner y flags de clase.
-- No depende de la posición del cursor.

local function scan_file(buf_lines, ctx)
  for _, line in ipairs(buf_lines) do

    -- ── Framework por imports ──────────────────────────────────────────────
    -- JUnit 4: imports sin .jupiter
    if line:match("import%s+org%.junit%.Test")
    or line:match("import%s+org%.junit%.Before")
    or line:match("import%s+org%.junit%.After")
    or line:match("import%s+org%.junit%.runner%.")
    or line:match("import%s+org%.junit%.runners%.") then
      ctx.framework = "junit4"
    end

    -- JUnit 5: jupiter tiene prioridad — algunos proyectos mezclan imports
    -- pero la intención es JUnit 5
    if line:match("import%s+org%.junit%.jupiter%.") then
      ctx.framework = "junit5"
    end

    -- ── @RunWith (JUnit 4) ─────────────────────────────────────────────────
    local runner = line:match("@RunWith%s*%(%s*([%w%.]+)%.class%s*%)")
    if runner then
      ctx.runner    = runner
      ctx.framework = "junit4"

      if runner:match("Parameterized") then
        ctx.is_parameterized = true
        ctx.surefire_pattern = "indexed"
      end
      if runner:match("SpringRunner") or runner:match("SpringJUnit4") then
        ctx.is_spring = true
      end
    end

    -- ── @ExtendWith (JUnit 5) ──────────────────────────────────────────────
    local extension = line:match("@ExtendWith%s*%(%s*([%w%.]+)%.class%s*%)")
    if extension then
      ctx.framework = "junit5"
      if extension:match("SpringExtension") then
        ctx.is_spring = true
      end
    end

    -- ── Anotaciones Spring que levantan contexto ───────────────────────────
    if line:match("@SpringBootTest")
    or line:match("@WebMvcTest")
    or line:match("@DataJpaTest")
    or line:match("@DataMongoTest")
    or line:match("@RestClientTest")
    or line:match("@JsonTest")
    or line:match("@JdbcTest") then
      ctx.is_spring = true
    end

    -- ── @Disabled / @Ignore a nivel de clase ──────────────────────────────
    if line:match("^%s*@Disabled") or line:match("^%s*@Ignore") then
      ctx.is_disabled = true
    end

    -- ── @Tag (JUnit 5) ─────────────────────────────────────────────────────
    local tag = line:match('@Tag%s*%(%s*["\'](.-)["\'%s]*%)')
    if tag then
      table.insert(ctx.tags, tag)
    end

    -- ── @Category (JUnit 4) ────────────────────────────────────────────────
    -- @Category(IntegrationTest.class)
    -- @Category({UnitTest.class, FastTest.class})
    local cat = line:match("@Category%s*%(%s*{?%s*([%w%.]+)%.class")
    if cat then
      local simple = cat:match("([%w]+)$")
      if simple then
        table.insert(ctx.categories, simple)
      end
    end
  end
end

-- ─── Pase 1: recolectar declaraciones de clase ────────────────────────────────
-- Para cada "class X" guardamos línea, indentación, si es @Nested y herencia.
-- Ventana de 8 líneas hacia atrás para cubrir bloques largos de anotaciones.

local function collect_classes(buf_lines)
  local classes = {}

  for i, line in ipairs(buf_lines) do
    if not line:match("class%s+%w+") then goto continue end

    local indent    = #line:match("^(%s*)")
    local name      = line:match("class%s+(%w+)")
    local parent    = line:match("extends%s+(%w+)")
    local is_nested = false

    for j = i - 1, math.max(1, i - 8), -1 do
      local prev = buf_lines[j]
      if prev:match("^%s*$") then
        -- vacía: seguir buscando
      elseif prev:match("@Nested") then
        is_nested = true
        break
      elseif prev:match("^%s*@") then
        -- otra anotación: seguir
      else
        break
      end
    end

    table.insert(classes, {
      line      = i,
      name      = name,
      indent    = indent,
      is_nested = is_nested,
      parent    = parent,
    })

    ::continue::
  end

  return classes
end

-- ─── Pase 2: determinar clases que contienen al cursor ────────────────────────
-- Construye la cadena raíz → nested ordenada por indentación creciente.

local function resolve_class_chain(classes, cursor_row, ctx)
  -- Solo las clases declaradas antes del cursor
  local containing = {}
  for _, cls in ipairs(classes) do
    if cls.line <= cursor_row then
      table.insert(containing, cls)
    end
  end

  -- Última clase vista por cada nivel de indentación
  local by_indent = {}
  for _, cls in ipairs(containing) do
    by_indent[cls.indent] = cls
  end

  local levels = {}
  for indent in pairs(by_indent) do
    table.insert(levels, indent)
  end
  table.sort(levels)

  for i, indent in ipairs(levels) do
    local cls = by_indent[indent]
    if i == 1 then
      ctx.root_class   = cls.name
      ctx.parent_class = cls.parent
    elseif cls.is_nested then
      table.insert(ctx.nested_chain, cls.name)
    end
  end
end

-- ─── Pase 3: método bajo el cursor y sus anotaciones ─────────────────────────
-- Busca hacia atrás desde el cursor el primer método encontrado.
-- Luego escanea sus anotaciones (hasta 8 líneas arriba).

local function resolve_method(buf_lines, cursor_row, ctx)
  -- Anotaciones que marcan un método como ejecutable por el runner.
  -- @Before/@After/@BeforeEach/@AfterEach son de ciclo de vida, no tests.
  -- Solo considerar métodos con alguna de estas anotaciones.
  local TEST_ANNOTATIONS = {
    "@Test", "@ParameterizedTest", "@RepeatedTest",
  }

  -- Verifica si alguna de las líneas previas al método tiene una anotación de test
  local function has_test_annotation(line_idx)
    for j = line_idx - 1, math.max(1, line_idx - 8), -1 do
      local ann = buf_lines[j]
      for _, ta in ipairs(TEST_ANNOTATIONS) do
        if ann:match(ta) then return true end
      end
      -- Si llegamos a código que no es anotación ni vacío, parar
      if not ann:match("^%s*@") and not ann:match("^%s*$") then
        break
      end
    end
    return false
  end

  local i = cursor_row
  while i >= 1 do
    local line = buf_lines[i]

    local method = line:match("public%s+void%s+([%w_]+)%s*%(")
      or line:match("public%s+%S+%s+([%w_]+)%s*%(")
      or line:match("protected%s+void%s+([%w_]+)%s*%(")
      or line:match("protected%s+%S+%s+([%w_]+)%s*%(")
      or line:match("private%s+void%s+([%w_]+)%s*%(")
      or line:match("private%s+%S+%s+([%w_]+)%s*%(")
      or line:match("^%s*void%s+([%w_]+)%s*%(")

    -- Solo aceptar el método si tiene una anotación de test encima.
    -- Esto evita que @Before/@After sean detectados como el método objetivo.
    if method and has_test_annotation(i) then
      ctx.method = method

      for j = i - 1, math.max(1, i - 8), -1 do
        local ann = buf_lines[j]

        if ann:match("@ParameterizedTest") or ann:match("@RepeatedTest") then
          ctx.is_parameterized = true
        end
        if ann:match("@RepeatedTest") then
          ctx.is_repeated = true
        end
        if ann:match("@Test%s*%(") and ann:match("expected%s*=") then
          ctx.surefire_pattern = ctx.surefire_pattern or "expected_exception"
        end
        if ann:match("@Disabled") or ann:match("@Ignore") then
          ctx.is_disabled = true
        end

        local mtag = ann:match('@Tag%s*%(%s*["\'](.-)["\'%s]*%)')
        if mtag and not vim.tbl_contains(ctx.tags, mtag) then
          table.insert(ctx.tags, mtag)
        end

        if not ann:match("^%s*@") and not ann:match("^%s*$") then
          break
        end
      end

      break
    end

    i = i - 1
  end
end

-- ─── API pública ──────────────────────────────────────────────────────────────

---Lee el buffer actual y devuelve el contexto completo del archivo Java.
---@return table ctx
function M.parse()
  local buf_lines  = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]

  local ctx = {
    framework        = "junit5",
    root_class       = nil,
    nested_chain     = {},
    method           = nil,
    parent_class     = nil,
    runner           = nil,
    is_parameterized = false,
    is_repeated      = false,
    is_disabled      = false,
    is_spring        = false,
    surefire_pattern = nil,
    tags             = {},
    categories       = {},
  }

  scan_file(buf_lines, ctx)

  local classes = collect_classes(buf_lines)
  if #classes == 0 then return ctx end

  resolve_class_chain(classes, cursor_row, ctx)
  resolve_method(buf_lines, cursor_row, ctx)

  return ctx
end

---Construye el spec de Maven y un label legible a partir del contexto.
---
--- Reglas:
---   JUnit 4                  → nombre exacto sin wildcard
---   JUnit 4 + Parameterized  → clase completa (métodos tienen índice numérico)
---   JUnit 5 clase simple     → wildcard para cubrir @Nested internos
---   JUnit 5 + nested chain   → spec exacto con \$
---   Cualquiera + método      → Clase#metodo
---
---@param ctx    table   resultado de M.parse()
---@param with_method boolean  incluir el método en el spec
---@return string|nil spec   valor para -Dtest= (nil si no hay clase)
---@return string     label  descripción legible para mostrar en UI
function M.build_spec(ctx, with_method)
  if not ctx.root_class then
    return nil, "No se detectó clase"
  end

  -- Cadena de clases escapando $ para el shell
  local parts = { ctx.root_class }
  for _, nested in ipairs(ctx.nested_chain) do
    table.insert(parts, nested)
  end
  local class_spec = table.concat(parts, "$")

  -- ── Con método ──────────────────────────────────────────────────────────
  if with_method and ctx.method then
    -- JUnit 4 @Parameterized: el spec por método no es confiable porque
    -- Surefire reporta los resultados como "metodo[0]", "metodo[1]"
    if ctx.is_parameterized and ctx.surefire_pattern == "indexed" then
      return ctx.root_class,
             ctx.root_class .. " (parameterized — corriendo clase completa)"
    end

    local label = class_spec .. " › " .. ctx.method
    if ctx.is_parameterized then label = label .. " (parametrized)" end
    if ctx.is_repeated       then label = label .. " (repeated)"    end

    return class_spec .. "#" .. ctx.method, label
  end

  -- ── Sin método: por framework ────────────────────────────────────────────
  if ctx.framework == "junit4" then
    local label = ctx.root_class
    if ctx.runner    then label = label .. " [@RunWith(" .. ctx.runner .. ")]"  end
    if ctx.is_spring then label = label .. " ⚠ Spring context (puede tardar)"  end
    if ctx.is_disabled then label = label .. " [IGNORADO]"                      end
    return ctx.root_class, label
  end

  -- JUnit 5 con nested explícito
  if #ctx.nested_chain > 0 then
    local label = class_spec
    if ctx.is_spring then label = label .. " ⚠ Spring context" end
    return class_spec, label
  end

  -- JUnit 5 clase simple: wildcard para cubrir @Nested internos
  local label = ctx.root_class .. " (todos)"
  if ctx.is_spring   then label = label .. " ⚠ Spring context (puede tardar)" end
  if ctx.is_disabled then label = label .. " [DISABLED]"                       end

  return ctx.root_class .. "*", label
end

return M
