return {
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        -- Habilitar configuración automática
        configure = true,
        -- Configuración extra de lazygit
        config = {
          os = { editPreset = "nvim-remote" },
          gui = {
            nerdFontsVersion = "3",
          },
        },
      },
    },
  },
}
