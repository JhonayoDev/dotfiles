-- ~/.config/nvim/lua/java/creator.lua
local M = {}

---Detecta el root del proyecto Java (donde está pom.xml o build.gradle)
---@return string|nil
local function find_project_root()
  local root_markers = { "pom.xml", "build.gradle", "gradlew", ".git" }
  return vim.fs.root(0, root_markers)
end

---Detecta el package basándose en la ruta actual del archivo
---@return string|nil package_name El package detectado (ej: "com.example.demo.dto")
---@return string|nil src_path La ruta al directorio src/main/java o src/test/java
local function detect_current_package()
  local current_file = vim.fn.expand("%:p")
  local root = find_project_root()

  if not root then
    return nil, nil
  end

  -- Buscar src/main/java o src/test/java
  local src_main = current_file:match("(.*src/main/java)/")
  local src_test = current_file:match("(.*src/test/java)/")
  local src_path = src_main or src_test

  if not src_path then
    src_path = root .. "/src/main/java"
  end

  -- Extraer el package desde la ruta
  local package_path = current_file:match("src/main/java/(.+)/[^/]+%.java$")
    or current_file:match("src/test/java/(.+)/[^/]+%.java$")

  local package_name = nil
  if package_path then
    package_name = package_path:gsub("/", ".")
  else
    local current_dir = vim.fn.expand("%:p:h")
    package_path = current_dir:match("src/main/java/(.+)$") or current_dir:match("src/test/java/(.+)$")
    if package_path then
      package_name = package_path:gsub("/", ".")
    end
  end

  return package_name, src_path
end

---Crea un nuevo item Java (Class, Interface, Enum, Record)
---@param type string "class"|"interface"|"enum"|"record"
function M.create_java_item(type)
  local root = find_project_root()

  if not root then
    vim.notify("No se encontró un proyecto Java (pom.xml o build.gradle)", vim.log.levels.ERROR)
    return
  end

  -- 1. Preguntar source set: main o test
  vim.ui.select({ "main", "test" }, {
    prompt = "Source set:",
    format_item = function(item)
      local icons = { main = "☕ main", test = "🧪 test" }
      return icons[item] or item
    end,
  }, function(source_set)
    if not source_set then
      vim.notify("Cancelado", vim.log.levels.WARN)
      return
    end

    -- 2. Detectar package actual y forzar src_path según selección
    local suggested_package, _ = detect_current_package()
    local src_path = root .. "/src/" .. source_set .. "/java"

    -- 3. Preguntar por el package (con sugerencia)
    vim.ui.input({
      prompt = "Package: ",
      default = suggested_package or "",
    }, function(package_name)
      if not package_name or package_name == "" then
        vim.notify("Cancelado: package vacío", vim.log.levels.WARN)
        return
      end

      -- 4. Preguntar por el nombre de la clase/interface/etc
      vim.ui.input({
        prompt = "Nombre del " .. type .. ": ",
      }, function(name)
        if not name or name == "" then
          vim.notify("Cancelado: nombre vacío", vim.log.levels.WARN)
          return
        end

        -- Validación: nombre debe empezar con mayúscula
        if not name:match("^[A-Z]") then
          vim.notify("El nombre debe empezar con mayúscula", vim.log.levels.ERROR)
          return
        end

        -- 5. Construir la ruta del archivo
        local package_path = package_name:gsub("%.", "/")
        local file_dir = src_path .. "/" .. package_path
        local file_path = file_dir .. "/" .. name .. ".java"

        -- Validación: verificar si ya existe
        if vim.fn.filereadable(file_path) == 1 then
          vim.ui.select(
            { "Sobrescribir", "Cancelar" },
            { prompt = "El archivo ya existe. ¿Qué deseas hacer?" },
            function(choice)
              if choice == "Sobrescribir" then
                M._write_file(type, name, package_name, file_dir, file_path)
              else
                vim.notify("Creación cancelada", vim.log.levels.INFO)
              end
            end
          )
        else
          M._write_file(type, name, package_name, file_dir, file_path)
        end
      end)
    end)
  end)
end

---Escribe el archivo físicamente
---@param type string
---@param name string
---@param package_name string
---@param file_dir string
---@param file_path string
function M._write_file(type, name, package_name, file_dir, file_path)
  -- 1. Crear directorio si no existe
  vim.fn.mkdir(file_dir, "p")

  -- 2. Generar contenido según el tipo
  local content = M._generate_content(type, name, package_name)

  -- 3. Escribir archivo
  local file = io.open(file_path, "w")
  if file then
    file:write(content)
    file:close()

    -- 4. Abrir el archivo
    vim.cmd("edit " .. file_path)

    -- 5. Posicionar cursor dentro de la clase (línea 4, después de la declaración)
    vim.api.nvim_win_set_cursor(0, { 4, 4 })

    vim.notify("✓ Creado: " .. package_name .. "." .. name, vim.log.levels.INFO)
  else
    vim.notify("Error al crear el archivo: " .. file_path, vim.log.levels.ERROR)
  end
end

---Genera el contenido del archivo según el tipo
---@param type string
---@param name string
---@param package_name string
---@return string
function M._generate_content(type, name, package_name)
  local templates = {
    class = string.format(
      [[package %s;

public class %s {
    
}
]],
      package_name,
      name
    ),

    interface = string.format(
      [[package %s;

public interface %s {
    
}
]],
      package_name,
      name
    ),

    enum = string.format(
      [[package %s;

public enum %s {
    
}
]],
      package_name,
      name
    ),

    record = string.format(
      [[package %s;

public record %s() {
    
}
]],
      package_name,
      name
    ),
  }

  return templates[type] or templates.class
end

---Muestra menú para seleccionar el tipo de item a crear
function M.create_menu()
  vim.ui.select({ "Class", "Interface", "Enum", "Record" }, {
    prompt = "¿Qué deseas crear?",
    format_item = function(item)
      return "📄 " .. item
    end,
  }, function(choice)
    if choice then
      M.create_java_item(choice:lower())
    end
  end)
end

---Mueve el archivo actual a otro package
function M.move_to_package()
  local current_file = vim.fn.expand("%:p")

  -- Verificar que es un archivo Java
  if not current_file:match("%.java$") then
    vim.notify("Este comando solo funciona en archivos .java", vim.log.levels.ERROR)
    return
  end

  local root = find_project_root()
  if not root then
    vim.notify("No se encontró un proyecto Java", vim.log.levels.ERROR)
    return
  end

  -- 1. Detectar package actual
  local current_package, src_path = detect_current_package()
  local class_name = vim.fn.expand("%:t:r") -- Nombre sin extensión

  if not current_package then
    vim.notify("No se pudo detectar el package actual", vim.log.levels.ERROR)
    return
  end

  -- 2. Preguntar nuevo package
  vim.ui.input({
    prompt = "Nuevo package (actual: " .. current_package .. "): ",
    default = current_package,
  }, function(new_package)
    if not new_package or new_package == "" then
      vim.notify("Cancelado", vim.log.levels.WARN)
      return
    end

    if new_package == current_package then
      vim.notify("El package es el mismo, no hay nada que hacer", vim.log.levels.INFO)
      return
    end

    -- 3. Construir nueva ruta
    local new_package_path = new_package:gsub("%.", "/")
    local new_file_dir = src_path .. "/" .. new_package_path
    local new_file_path = new_file_dir .. "/" .. class_name .. ".java"

    -- Verificar si ya existe un archivo con ese nombre en el destino
    if vim.fn.filereadable(new_file_path) == 1 then
      vim.notify("Ya existe un archivo con ese nombre en " .. new_package, vim.log.levels.ERROR)
      return
    end

    -- 4. Leer contenido actual
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    -- 5. Actualizar la línea del package
    for i, line in ipairs(lines) do
      if line:match("^package%s+") then
        lines[i] = "package " .. new_package .. ";"
        break
      end
    end

    -- 6. Crear directorio destino si no existe
    vim.fn.mkdir(new_file_dir, "p")

    -- 7. Escribir el nuevo archivo
    local new_file = io.open(new_file_path, "w")
    if new_file then
      new_file:write(table.concat(lines, "\n"))
      new_file:close()

      -- 8. Cerrar buffer actual y eliminar archivo viejo
      local old_file_path = current_file
      vim.cmd("bdelete!")
      vim.fn.delete(old_file_path)

      -- 9. Abrir el nuevo archivo
      vim.cmd("edit " .. new_file_path)

      -- 10. Usar JDTLS para actualizar imports en todo el proyecto
      vim.defer_fn(function()
        require("jdtls").organize_imports()
        vim.notify("✓ Movido a: " .. new_package .. "." .. class_name, vim.log.levels.INFO)
        vim.notify(
          "Tip: Usa 'Find Usages' o busca en el proyecto para actualizar imports manualmente",
          vim.log.levels.INFO
        )
      end, 200)
    else
      vim.notify("Error al crear el archivo en la nueva ubicación", vim.log.levels.ERROR)
    end
  end)
end

return M
