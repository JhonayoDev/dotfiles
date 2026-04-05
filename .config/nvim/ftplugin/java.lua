local home = os.getenv("HOME")
local sdkman = os.getenv("SDKMAN_DIR") or (home .. "/.sdkman")
local jdtls = require("jdtls")

-- Nombre del proyecto basado en el directorio actual
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = home .. "/.cache/nvim/jdtls/" .. project_name

-- ============================================================
-- BUNDLES CONFIGURATION (siguiendo documentación oficial)
-- ============================================================

-- 1. Primero agregamos java-debug
local bundles = {
  vim.fn.glob(home .. "/.local/share/nvim/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar", true),
}

-- 2. Luego agregamos java-test EXCLUYENDO los JARs problemáticos
local java_test_path = home .. "/.local/share/nvim/mason/share/java-test/*.jar"
local java_test_bundles = vim.split(vim.fn.glob(java_test_path, true), "\n")

local excluded = {
  "com.microsoft.java.test.runner-jar-with-dependencies.jar",
  "jacocoagent.jar",
}

for _, bundle in ipairs(java_test_bundles) do
  local filename = vim.fn.fnamemodify(bundle, ":t")
  if not vim.tbl_contains(excluded, filename) and bundle ~= "" then
    table.insert(bundles, bundle)
  end
end

-- 3. Capacidades para Blink y Snacks
local capabilities = require("blink.cmp").get_lsp_capabilities()
local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

-- Configuración principal
local config = {
  cmd = {
    sdkman .. "/candidates/java/21.0.8-tem/bin/java",
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    "-Dlog.level=ALL",
    "-Xmx1g",
    "--add-modules=ALL-SYSTEM",
    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",
    "-javaagent:" .. home .. "/.local/share/nvim/mason/share/jdtls/lombok.jar",
    "-jar",
    vim.fn.glob(home .. "/.local/share/nvim/mason/packages/jdtls/plugins/org.eclipse.equinox.launcher_*.jar"),
    "-configuration",
    home .. "/.local/share/nvim/mason/packages/jdtls/config_linux",
    "-data",
    workspace_dir,
  },

  root_dir = vim.fs.root(0, { "gradlew", ".git", "mvnw", "pom.xml", "build.gradle" }),

  settings = {
    java = {
      home = sdkman .. "/candidates/java/21.0.8-tem",
      configuration = {
        runtimes = {
          {
            name = "JavaSE-1.8",
            path = sdkman .. "/candidates/java/8.0.482-tem",
          },
          {
            name = "JavaSE-17",
            path = sdkman .. "/candidates/java/17.0.16-tem",
          },
          {
            name = "JavaSE-21",
            path = sdkman .. "/candidates/java/21.0.8-tem",
            default = true,
          },
        },
      },
      maven = {
        downloadSources = true,
      },
      implementationsCodeLens = {
        enabled = true,
      },
      referencesCodeLens = {
        enabled = true,
      },
      references = {
        includeDecompiledSources = true,
      },
      signatureHelp = { enabled = true },
      format = {
        enabled = true,
      },
      inlayHints = {
        parameterNames = {
          enabled = "all",
        },
      },
    },
  },

  init_options = {
    bundles = bundles,
    extendedClientCapabilities = extendedClientCapabilities,
  },

  on_attach = function(client, bufnr)
    -- Verificar que nvim-dap está disponible antes de configurarlo

    -- Sincronizar runtime Java automáticamente
    vim.defer_fn(function()
      require("custom.java_runtime").sync(vim.fn.getcwd())
    end, 500) -- 500ms para dar tiempo a que jdtls termine de iniciar

    local dap_ok, dap = pcall(require, "dap")
    if dap_ok then
      jdtls.setup_dap({ hotcodereplace = "auto" })
      require("jdtls.dap").setup_dap_main_class_configs()
    else
      vim.notify("nvim-dap not available, skipping DAP setup", vim.log.levels.WARN)
    end
    -- ============================================================
    -- Keymaps para Java (DAP, Testing, Refactoring, etc.)
    -- ============================================================
    local opts = { buffer = bufnr, silent = true }

    -- Registrar grupo de Test en which-key
    local wk_ok, wk = pcall(require, "which-key")
    if wk_ok then
      wk.add({
        { "<leader>cT", group = "Test" },
        { "<leader>cTd", group = "Dap" },
        { "<leader>ce", group = "Extract", buffer = bufnr },
      })
    end

    -- ============================================================
    -- DAP: Debug & Run
    -- ============================================================

    -- ============================================================
    -- DAP: Ejecutar directamente la 3ra configuración (main class)
    -- ============================================================
    if dap_ok then
      -- Ejecutar Main Class con layout 2
      vim.keymap.set("n", "<leader>cR", function()
        local configs = dap.configurations.java
        if configs and configs[3] then
          dap.run(configs[3])
          require("dapui").open({ layout = 2 })
        else
          dap.continue()
          require("dapui").open({ layout = 2 })
        end
      end, vim.tbl_extend("force", opts, { desc = "Launch Main Class" }))

      -- Toggle dapui (minimizar/maximizar)
      vim.keymap.set("n", "<leader>cx", function()
        require("dapui").toggle({ layout = 2 })
      end, vim.tbl_extend("force", opts, { desc = "Min / Max Run Console" }))

      -- Terminar debug y cerrar UI
      vim.keymap.set("n", "<leader>cX", function()
        dap.terminate()
        require("dapui").close()
      end, vim.tbl_extend("force", opts, { desc = "Terminate Run Console" }))
    end

    vim.keymap.set("n", "<leader>cU", function()
      require("jdtls").set_runtime()
    end, vim.tbl_extend("force", opts, { desc = "Set Java Runtime" }))

    -- ============================================================
    -- DAP: Testing
    -- ============================================================
    if dap_ok then
      -- ============================================================
      -- Test SIN debug (solo Console - layout 2)
      -- ============================================================
      vim.keymap.set("n", "<leader>cTdc", function()
        require("jdtls.dap").test_class()
        require("dapui").open({ layout = 2 })
      end, vim.tbl_extend("force", opts, { desc = "Test Class (Console)" }))

      vim.keymap.set("n", "<leader>cTdm", function()
        require("jdtls.dap").test_nearest_method()
        require("dapui").open({ layout = 2 })
      end, vim.tbl_extend("force", opts, { desc = "Test Method (Console)" }))

      -- ============================================================
      -- Test CON debug (UI completa - ambos layouts)
      -- ============================================================
      vim.keymap.set("n", "<leader>cTdC", function()
        require("jdtls.dap").test_class()
        require("dapui").open() -- Sin especificar layout = abre todo
      end, vim.tbl_extend("force", opts, { desc = "Debug Test Class (Full UI)" }))

      vim.keymap.set("n", "<leader>cTdM", function()
        require("jdtls.dap").test_nearest_method()
        require("dapui").open() -- Sin especificar layout = abre todo
      end, vim.tbl_extend("force", opts, { desc = "Debug Test Method (Full UI)" }))
    end
    -- ============================================================
    -- Test UI Panel (test_ui.lua)
    -- ============================================================
    local ui_ok, test_ui = pcall(require, "custom.test_ui")
    vim.keymap.set("n", "<leader>cJ", function()
      require("custom.test_java_env").show_panel()
    end, vim.tbl_extend("force", opts, { desc = "Java Environment" }))

    if ui_ok then
      vim.keymap.set("n", "<leader>cTp", function()
        test_ui.toggle()
      end, vim.tbl_extend("force", opts, { desc = "Toggle Test Panel" }))

      vim.keymap.set("n", "<leader>cTx", function()
        require("custom.test_runner").cancel()
        vim.notify("Ejecución cancelada", vim.log.levels.WARN)
      end, vim.tbl_extend("force", opts, { desc = "Cancel Run (Panel)" }))

      vim.keymap.set("n", "<leader>cTc", function()
        test_ui.run_class()
      end, vim.tbl_extend("force", opts, { desc = "Run Class (Panel)" }))

      vim.keymap.set("n", "<leader>cTm", function()
        test_ui.run_method()
      end, vim.tbl_extend("force", opts, { desc = "Run Method (Panel)" }))

      vim.keymap.set("n", "<leader>cTa", function()
        test_ui.run_all()
      end, vim.tbl_extend("force", opts, { desc = "Run All (Panel)" }))
    end

    -- ============================================================
    -- JDTLS: Project Management
    -- ============================================================
    vim.keymap.set("n", "<leader>co", function()
      jdtls.organize_imports()
    end, vim.tbl_extend("force", opts, { desc = "Organize Imports" }))

    vim.keymap.set("n", "<leader>cu", function()
      jdtls.update_projects_config()
    end, vim.tbl_extend("force", opts, { desc = "Update Project Config" }))

    -- ============================================================
    -- JDTLS: Refactoring (Extract)
    -- ============================================================
    vim.keymap.set("n", "<leader>cev", function() -- ← crv -> cev
      jdtls.extract_variable()
    end, vim.tbl_extend("force", opts, { desc = "Extract Variable" }))

    vim.keymap.set("v", "<leader>cev", function()
      jdtls.extract_variable(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Variable" }))

    vim.keymap.set("n", "<leader>cec", function() -- ← crc -> cec
      jdtls.extract_constant()
    end, vim.tbl_extend("force", opts, { desc = "Extract Constant" }))

    vim.keymap.set("v", "<leader>cec", function()
      jdtls.extract_constant(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Constant" }))

    vim.keymap.set("v", "<leader>cem", function() -- ← crm -> cem
      jdtls.extract_method(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Method" }))

    vim.keymap.set("n", "<leader>cem", function() -- ← crm -> cem
      jdtls.extract_method(true)
    end, vim.tbl_extend("force", opts, { desc = "Extract Method" }))
  end,
}

jdtls.start_or_attach(config)

-- ============================================================
-- JAVA FILE CREATOR: Módulo para crear y gestionar archivos Java
-- ============================================================
-- Carga el módulo personalizado que permite crear clases, interfaces,
-- enums y records, además de mover archivos entre packages
local java_creator = require("java.creator")

-- ============================================================
-- COMANDOS: Creación de archivos Java
-- ============================================================
-- Comando :JavaCreate [tipo]
-- Sin argumentos: Muestra menú interactivo para seleccionar tipo
-- Con argumento: Crea directamente el tipo especificado
-- Ejemplos:
--   :JavaCreate           → Muestra menú
--   :JavaCreate class     → Crea una clase directamente
--   :JavaCreate interface → Crea una interfaz directamente
vim.api.nvim_create_user_command("JavaCreate", function(opts)
  if opts.args == "" then
    java_creator.create_menu()
  else
    java_creator.create_java_item(opts.args)
  end
end, {
  nargs = "?",
  complete = function()
    return { "class", "interface", "enum", "record" }
  end,
  desc = "Crear nuevo archivo Java (Class/Interface/Enum/Record)",
})

-- ============================================================
-- COMANDOS: Refactoring de archivos Java
-- ============================================================
-- Comando :JavaMove
-- Mueve la clase actual a otro package, actualizando la declaración
-- del package automáticamente. Los imports en otros archivos deben
-- actualizarse manualmente usando diagnósticos y code actions.
vim.api.nvim_create_user_command("JavaMove", function()
  java_creator.move_to_package()
end, {
  desc = "Mover clase actual a otro package",
})

-- ============================================================
-- KEYMAPS: Creación de archivos Java
-- ============================================================
-- <leader>cN - Crear nuevo archivo Java (menú interactivo)
-- Muestra un selector con opciones: Class, Interface, Enum, Record
-- Solicita el package (sugiere el actual) y el nombre del archivo
-- Crea el archivo en la ubicación correcta con el package declarado
vim.keymap.set("n", "<leader>cN", function()
  require("java.creator").create_menu()
end, { buffer = bufnr, desc = "New Java Class/Interface/Enum/Record" })

-- ============================================================
-- KEYMAPS: Refactoring de archivos Java
-- ============================================================
-- <leader>cM - Mover clase a otro package y mostrar diagnósticos
-- Workflow:
--   1. Solicita el nuevo package (sugiere el actual)
--   2. Mueve el archivo y actualiza la declaración del package
--   3. Abre automáticamente Trouble con diagnósticos del buffer
--   4. Permite arreglar imports rotos usando code actions (<leader>ca)
-- Nota: Los imports en otros archivos NO se actualizan automáticamente,
--       usa los diagnósticos para identificar y corregir referencias rotas
vim.keymap.set("n", "<leader>cM", function()
  require("java.creator").move_to_package()
  -- Esperar a que el archivo se mueva antes de mostrar diagnósticos
  vim.defer_fn(function()
    vim.cmd("Trouble diagnostics toggle filter.buf=0")
  end, 500)
end, { buffer = bufnr, desc = "Move to Package & Show Diagnostics" })
