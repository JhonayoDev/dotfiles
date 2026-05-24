-- lua/utils/env.lua
local M = {}

function M.load_env(path)
  path = path or (vim.fn.getcwd() .. "/.env")

  local env = {}

  local file = io.open(path, "r")
  if not file then
    vim.notify(".env no encontrado", vim.log.levels.WARN)
    return env
  end

  for line in file:lines() do
    if not line:match("^%s*#") and line:match("=") then
      local key, value = line:match("^([^=]+)=(.*)$")

      if key and value then
        key = vim.trim(key)
        value = vim.trim(value)

        value = value:gsub("%${([^}]+)}", function(ref)
          return env[ref] or os.getenv(ref) or ""
        end)

        env[key] = value
      end
    end
  end

  file:close()

  return env
end

return M
