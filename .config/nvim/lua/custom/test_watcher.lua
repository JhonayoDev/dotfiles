-- lua/custom/test_watcher.lua
--
-- Responsabilidad única: observar target/surefire-reports/ y notificar
-- cuando aparece o cambia un archivo TEST-*.xml.
--
-- No sabe nada de: UI, Maven, ni cómo se parsean los resultados.
-- Emite eventos via callback para que el caller decida qué hacer.
--
-- API pública:
--   M.start(reports_dir, on_change)
--   M.stop()
--   M.is_active()

local M = {}

local state = {
  handle = nil, -- uv fs_event handle
  timer = nil, -- uv timer para debounce
  active = false,
}

-- Tiempo de espera tras el último evento antes de notificar.
-- Maven escribe un XML por clase de test. En proyectos Spring cada clase
-- puede tardar 2-5s, por lo que los eventos llegan muy separados y 150ms
-- no alcanza para agruparlos. Con 800ms cubrimos la mayoría de los casos:
-- si en 800ms no llegó otro XML, asumimos que terminó esa ola de escrituras.
local DEBOUNCE_MS = 800

---@return boolean
function M.is_active()
  return state.active
end

---Detiene el watcher si está activo.
function M.stop()
  if state.timer and not state.timer:is_closing() then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  if state.handle and not state.handle:is_closing() then
    state.handle:stop()
    state.handle:close()
    state.handle = nil
  end
  state.active = false
end

---Inicia el watcher sobre reports_dir.
---Llama on_change(filename) cuando detecta un XML nuevo o modificado.
---Si el directorio no existe lo crea (Maven puede no haberlo creado aún).
---
---@param reports_dir string  ruta a target/surefire-reports/
---@param on_change   function(filename: string)
function M.start(reports_dir, on_change)
  -- Detener watcher anterior si existía
  M.stop()

  -- Crear el directorio si no existe — Maven lo crea al correr los tests,
  -- pero el watcher necesita que exista para poder observarlo
  vim.fn.mkdir(reports_dir, "p")

  local handle = vim.uv.new_fs_event()
  if not handle then
    vim.notify("test_watcher: no se pudo crear fs_event", vim.log.levels.WARN)
    return
  end

  local timer = vim.uv.new_timer()
  if not timer then
    handle:close()
    vim.notify("test_watcher: no se pudo crear timer", vim.log.levels.WARN)
    return
  end

  state.handle = handle
  state.timer = timer
  state.active = true

  handle:start(reports_dir, {}, function(err, filename, _events)
    if err then
      return
    end
    -- Solo nos interesan los XMLs de tests
    if not filename or not filename:match("TEST%-.*%.xml") then
      return
    end

    -- Debounce: reiniciar el timer en cada evento
    -- Si Maven escribe 5 XMLs en 100ms, solo notificamos una vez
    timer:stop()
    timer:start(DEBOUNCE_MS, 0, function()
      vim.schedule(function()
        on_change(filename)
      end)
    end)
  end)
end

return M
