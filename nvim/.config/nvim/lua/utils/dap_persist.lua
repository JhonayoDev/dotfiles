local M = {}

local cache_dir = vim.fn.stdpath("cache") .. "/dap-persist"
local cache_file = cache_dir .. "/projects.json"

function M.save(config_name)
  vim.fn.mkdir(cache_dir, "p")

  local data = {}
  local ok, file = pcall(io.open, cache_file, "r")
  if ok and file then
    local content = file:read("*a")
    file:close()
    local parsed = vim.json.decode(content, { luanil = { object = true } })
    if parsed then
      data = parsed
    end
  end

  data[vim.fn.getcwd()] = config_name

  local out, err = io.open(cache_file, "w")
  if out then
    out:write(vim.json.encode(data))
    out:close()
  else
    vim.notify("No se pudo guardar la configuración DAP: " .. (err or ""), vim.log.levels.WARN)
  end
end

function M.load()
  local ok, file = pcall(io.open, cache_file, "r")
  if not ok or not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  local data = vim.json.decode(content, { luanil = { object = true } })
  if not data then
    return nil
  end

  return data[vim.fn.getcwd()]
end

return M
