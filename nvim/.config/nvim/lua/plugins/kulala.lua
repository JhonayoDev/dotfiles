return {
  {
    "mistweaverco/kulala.nvim",

    ft = { "http", "rest" },

    opts = {
      debug = false,

      global_keymaps = true,
      global_keymaps_prefix = "<leader>cr",

      lsp = {
        enable = false,
      },

      ui = {
        display_mode = "split",
      },
    },

    config = function(_, opts)
      require("kulala").setup(opts)

      local wk = require("which-key")

      wk.add({
        { "<leader>c", group = "Code" },
        { "<leader>cR", group = "REST Client" },
      })
    end,
  },
}
