-- ~/.config/nvim/lua/plugins/lazydocker.lua
return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- Agregar lazydocker como un comando más de Snacks
      vim.keymap.set("n", "<leader>gd", function()
        Snacks.terminal.open("lazydocker", {
          cwd = vim.fn.getcwd(),
        })
      end, { desc = "LazyDocker" })
    end,
  },
}
