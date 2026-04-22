-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- ============================================================
-- KEYMAPS: Templates
-- ============================================================

local templates = require("utils.templates")

vim.keymap.set("n", "<leader>ft", function()
  templates.select_and_insert()
end, { desc = "Insert Template" })

vim.keymap.set("n", "<leader>fg", function()
  templates.create_gitignore()
end, { desc = "Create .gitignore" })
