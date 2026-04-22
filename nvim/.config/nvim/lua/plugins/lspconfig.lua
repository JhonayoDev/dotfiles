return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Deshabilitar jdtls en nvim-lspconfig
        -- Lo manejamos manualmente en ftplugin/java.lua
        jdtls = {
          enabled = false,
        },
      },
    },
  },
}
