-- ~/.config/nvim/lua/config/templates.lua
local templates = require("utils.templates")

-- ============================================================
-- COMANDOS: Templates
-- ============================================================

-- Comando para insertar template en posición actual
vim.api.nvim_create_user_command("TemplateInsert", function()
  templates.select_and_insert()
end, { desc = "Insertar template en posición actual" })

-- Comando para crear .gitignore desde template
vim.api.nvim_create_user_command("TemplateGitignore", function()
  templates.create_gitignore()
end, { desc = "Crear .gitignore desde template" })
