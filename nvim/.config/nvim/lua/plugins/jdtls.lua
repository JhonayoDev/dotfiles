return {
  "mfussenegger/nvim-jdtls",
  opts = function()
    -- Retornamos una tabla vacía para que LazyVim no intente hacer su propio setup
    -- y deje que nuestro ftplugin/java.lua tome el control total.
    return {}
  end,
  config = function()
    -- No hacemos nada aquí. El inicio real ocurre en ftplugin/java.lua
  end,
}
