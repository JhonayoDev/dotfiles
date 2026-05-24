return {
  { "tpope/vim-dadbod" },
  {
    "kristijanhusak/vim-dadbod-ui",
    dependencies = {
      "tpope/vim-dadbod",
      "kristijanhusak/vim-dadbod-completion",
    },
    cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection" },
    init = function()
      vim.g.db_ui_use_nerd_fonts = 1
    end,
    config = function()
      local erd = require("custom.dadbod-erd")

      local function get_schema(db)
        return db and (db:match("/([%w_]+)%s*$") or nil)
      end

      local function resolve_schema()
        local db = vim.b.db or vim.g.db or ""
        return vim.g.dbui_erd_schema or (db ~= "" and get_schema(db)) or "erd"
      end

      -- Toggle panel
      vim.keymap.set("n", "<leader>Dt", "<cmd>DBUIToggle<cr>", { desc = "DB: toggle panel" })

      -- Ejecutar query (global, por si acaso)
      --vim.keymap.set("n", "<leader>DS", "<Plug>(DBUI_ExecuteQuery)", { desc = "DB: ejecutar query" })

      -- ERD: abrir query
      vim.api.nvim_create_user_command("DBUIErd", function()
        local db = vim.b.db or vim.g.db
        if not db then
          vim.notify("Abre un buffer de dadbod primero", vim.log.levels.WARN)
          return
        end
        local schema = get_schema(db)
        if schema then
          vim.g.dbui_erd_schema = schema
          erd.open_query(db, schema)
        else
          vim.ui.input({ prompt = "Nombre de la database: " }, function(input)
            if input and input ~= "" then
              vim.g.dbui_erd_schema = input
              erd.open_query(db, input)
            end
          end)
        end
      end, { desc = "DB: abrir query ERD" })

      -- ERD: renderizar PNG
      vim.api.nvim_create_user_command("DBUIErdRender", function()
        erd.render(resolve_schema())
      end, { desc = "DB: renderizar ERD" })

      -- ERD: copiar .mmd al clipboard
      vim.api.nvim_create_user_command("DBUIErdCopy", function()
        erd.copy_mmd(resolve_schema())
      end, { desc = "DB: copiar .mmd al clipboard" })

      -- Ayuda
      vim.api.nvim_create_user_command("DBUIHelp", function()
        local help = {
          "",
          "  dadbod — atajos disponibles",
          "  ─────────────────────────────────────────────────",
          "  <leader>Dt   Toggle panel dadbod-ui",
          "  <leader>De   Abrir query ERD (pide schema si no detecta)",
          "  <leader>DS   Ejecutar query (buffer ERD o cualquier sql)",
          "  <leader>Dr   Renderizar ERD → PNG",
          "  <leader>Dc   Copiar .mmd al clipboard (README, Obsidian)",
          "  <leader>D?   Mostrar esta ayuda",
          "",
          "  flujo ERD:",
          "  1) <leader>Dt  → abre dadbod, entra a un buffer de tu DB",
          "  2) <leader>De  → abre buffer con la query ERD",
          "  3) <leader>DS  → ejecuta la query",
          "  4) <leader>Dr  → genera y abre el PNG",
          "  5) <leader>Dc  → copia el .mmd para README u Obsidian",
          "",
          "  mappings nativos de dadbod-ui:",
          "  \\S   ejecutar query completa",
          "  \\R   toggle vista expandida del resultado",
          "  \\W   guardar query",
          "  ?    ayuda del drawer",
          "",
        }

        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, help)
        vim.bo[buf].modifiable = false

        local width = 54
        local height = #help
        local win = vim.api.nvim_open_win(buf, true, {
          relative = "editor",
          width = width,
          height = height,
          row = math.floor((vim.o.lines - height) / 2),
          col = math.floor((vim.o.columns - width) / 2),
          style = "minimal",
          border = "rounded",
          title = " dadbod help ",
          title_pos = "center",
        })
        vim.wo[win].cursorline = false
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
        vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
      end, { desc = "DB: mostrar ayuda" })

      -- Atajos
      vim.keymap.set("n", "<leader>De", "<cmd>DBUIErd<cr>", { desc = "DB: abrir query ERD" })
      vim.keymap.set("n", "<leader>Dr", "<cmd>DBUIErdRender<cr>", { desc = "DB: renderizar ERD" })
      vim.keymap.set("n", "<leader>Dc", "<cmd>DBUIErdCopy<cr>", { desc = "DB: copiar .mmd al clipboard" })
      vim.keymap.set("n", "<leader>D?", "<cmd>DBUIHelp<cr>", { desc = "DB: ayuda" })
    end,
  },
}
