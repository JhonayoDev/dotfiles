return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {},
        config = function(_, opts)
          local dap = require("dap")
          local dapui = require("dapui")
          dapui.setup(opts)

          --dap.listeners.after.event_initialized["dapui_config"] = function()
          --  dapui.open()
          --end
          --dap.listeners.before.event_terminated["dapui_config"] = function()
          --  dapui.close()
          --end
          --dap.listeners.before.event_exited["dapui_config"] = function()
          --  dapui.close()
          --end
        end,
      },
    },
    config = function()
      local dap = require("dap")

      -- ============================================================
      -- CONFIGURACIÓN PARA JAVA
      -- ============================================================
      -- Estas configuraciones se mostrarán cuando ejecutes :DapNew
      -- pero normalmente usarás <leader>tc y <leader>tm en su lugar
      dap.configurations.java = {
        {
          type = "java",
          request = "attach",
          name = "Debug (Attach) - Remote",
          hostName = "127.0.0.1",
          port = 5005,
        },
        {
          type = "java",
          request = "launch",
          name = "Debug (Launch) - Current File",
          -- nvim-jdtls llenará esto dinámicamente
        },
      }

      -- El adaptador se registra automáticamente por nvim-jdtls
      -- No necesitas configurar dap.adapters.java manualmente
    end,
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "Open REPL",
      },
      {
        "<leader>dx",
        function()
          require("dapui").toggle()
        end,
        desc = "Min / Max Dap",
      },
      {
        "<leader>dt",
        function()
          require("dap").terminate()
          require("dapui").close()
        end,
        desc = "Terminate Dap",
      },
      {
        "<leader>dj",
        function()
          require("dap").continue()
          require("dapui").open({ layout = 2 })
        end,
        desc = "Run Java Class",
      },
    },
  },
}
