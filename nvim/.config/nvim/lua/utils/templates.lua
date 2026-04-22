-- ~/.config/nvim/lua/utils/templates.lua
local M = {}

M.templates_dir = vim.fn.stdpath("config") .. "/templates"

---Lista todos los templates disponibles
---@return table
function M.list_templates()
  local templates = {}
  local handle = vim.loop.fs_scandir(M.templates_dir)

  if handle then
    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name then
        break
      end

      if type == "file" and name:match("%.txt$") then
        -- Quitar extensión .txt
        local template_name = name:gsub("%.txt$", "")
        table.insert(templates, template_name)
      end
    end
  end

  table.sort(templates)
  return templates
end

---Inserta un template en el buffer actual
---@param template_name string Nombre del template (sin .txt)
function M.insert_template(template_name)
  local template_path = M.templates_dir .. "/" .. template_name .. ".txt"

  -- Verificar que existe
  if vim.fn.filereadable(template_path) == 0 then
    vim.notify("Template no encontrado: " .. template_name, vim.log.levels.ERROR)
    return
  end

  -- Leer contenido
  local lines = {}
  for line in io.lines(template_path) do
    table.insert(lines, line)
  end

  -- Insertar en el buffer actual
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  vim.api.nvim_buf_set_lines(0, current_line - 1, current_line - 1, false, lines)

  vim.notify("✓ Template insertado: " .. template_name, vim.log.levels.INFO)
end

---Crea un archivo nuevo desde un template
---@param filename string Nombre del archivo a crear
---@param template_name string Nombre del template
function M.create_from_template(filename, template_name)
  local template_path = M.templates_dir .. "/" .. template_name .. ".txt"

  if vim.fn.filereadable(template_path) == 0 then
    vim.notify("Template no encontrado: " .. template_name, vim.log.levels.ERROR)
    return
  end

  -- Leer template
  local lines = {}
  for line in io.lines(template_path) do
    table.insert(lines, line)
  end

  -- Crear archivo
  local file = io.open(filename, "w")
  if file then
    file:write(table.concat(lines, "\n"))
    file:close()

    -- Abrir archivo
    vim.cmd("edit " .. filename)
    vim.notify("✓ Archivo creado: " .. filename, vim.log.levels.INFO)
  else
    vim.notify("Error al crear archivo: " .. filename, vim.log.levels.ERROR)
  end
end

---Menú interactivo para seleccionar e insertar template
function M.select_and_insert()
  local templates = M.list_templates()

  if #templates == 0 then
    vim.notify("No hay templates disponibles en " .. M.templates_dir, vim.log.levels.WARN)
    return
  end

  vim.ui.select(templates, {
    prompt = "Selecciona un template:",
    format_item = function(item)
      return "📄 " .. item
    end,
  }, function(choice)
    if choice then
      M.insert_template(choice)
    end
  end)
end

---Menú para crear .gitignore desde template
function M.create_gitignore()
  local templates = M.list_templates()
  local gitignore_templates = {}

  -- Filtrar solo templates de gitignore
  for _, tmpl in ipairs(templates) do
    if tmpl:match("^gitignore") then
      table.insert(gitignore_templates, tmpl)
    end
  end

  if #gitignore_templates == 0 then
    vim.notify("No hay templates de .gitignore disponibles", vim.log.levels.WARN)
    return
  end

  vim.ui.select(gitignore_templates, {
    prompt = "Tipo de proyecto:",
    format_item = function(item)
      -- Mostrar sin el prefijo "gitignore-"
      local display = item:gsub("^gitignore%-", ""):gsub("^gitignore$", "generic")
      return "🚫 " .. display
    end,
  }, function(choice)
    if choice then
      -- Verificar si ya existe .gitignore
      if vim.fn.filereadable(".gitignore") == 1 then
        vim.ui.select(
          { "Sobrescribir", "Agregar al final", "Cancelar" },
          { prompt = ".gitignore ya existe. ¿Qué hacer?" },
          function(action)
            if action == "Sobrescribir" then
              M.create_from_template(".gitignore", choice)
            elseif action == "Agregar al final" then
              vim.cmd("edit .gitignore")
              vim.cmd("normal! G")
              M.insert_template(choice)
            end
          end
        )
      else
        M.create_from_template(".gitignore", choice)
      end
    end
  end)
end

return M
