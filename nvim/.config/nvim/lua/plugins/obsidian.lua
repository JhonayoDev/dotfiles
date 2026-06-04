return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ---@module 'obsidian'
  ---@type obsidian.config
  opts = {
    legacy_commands = false,

    workspaces = {
      {
        name = "personal",
        path = "~/Obsidian/Principal",
      },
    },

    daily_notes = {
      enabled = true,
      folder = "daily",
      date_format = "YYYY-MM-DD",
      default_tags = { "daily" },
    },

    templates = {
      folder = "~/Obsidian/Principal/01 - Main/010 - Recursos/Templates",
      date_format = "YYYY-MM-DD",
      time_format = "HH:mm",
      substitutions = {},
    },

    link = {
      auto_update = true,
    },
  },

  keys = {
    -- Daily notes
    { "<leader>Od", "<cmd>Obsidian today<cr>", desc = "Daily note (hoy)" },
    { "<leader>Oy", "<cmd>Obsidian yesterday<cr>", desc = "Daily note (ayer)" },
    { "<leader>Ot", "<cmd>Obsidian tomorrow<cr>", desc = "Daily note (mañana)" },
    { "<leader>Ol", "<cmd>Obsidian dailies<cr>", desc = "Listar daily notes" },

    -- Navegación / búsqueda
    { "<leader>Of", "<cmd>Obsidian find_notes<cr>", desc = "Buscar notas" },
    { "<leader>Og", "<cmd>Obsidian grep<cr>", desc = "Grep en vault" },
    { "<leader>Ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
    { "<leader>Os", "<cmd>Obsidian tags<cr>", desc = "Buscar por tag" },

    -- Notas
    { "<leader>On", "<cmd>Obsidian new<cr>", desc = "Nueva nota" },
    { "<leader>Oo", "<cmd>Obsidian open_in_app<cr>", desc = "Abrir en Obsidian" },

    -- Links (modo normal)
    { "<leader>Ofl", "<cmd>Obsidian follow_link<cr>", desc = "Seguir link" },
    { "<leader>O]", "<cmd>Obsidian nav_link next<cr>", desc = "Siguiente link" },
    { "<leader>O[", "<cmd>Obsidian nav_link prev<cr>", desc = "Link anterior" },

    -- Visual: links
    { "<leader>Oln", "<cmd>Obsidian link_new<cr>", desc = "Link → nueva nota", mode = "v" },
    { "<leader>Ole", "<cmd>Obsidian link<cr>", desc = "Link → nota existente", mode = "v" },
    { "<leader>Oex", "<cmd>Obsidian extract_note<cr>", desc = "Extraer a nueva nota", mode = "v" },

    -- Checkbox
    { "<leader>Oc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Toggle checkbox" },
  },

  config = function(_, opts)
    require("obsidian").setup(opts)

    vim.schedule(function()
      local ok, wk = pcall(require, "which-key")
      if not ok then
        return
      end
      wk.add({
        { "<leader>O", group = "Obsidian", icon = "󱓧" },
      })
    end)
  end,
}
