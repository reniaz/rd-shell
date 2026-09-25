-- Live-reload for the matugen colorscheme (colors/matugen.lua). matugen
-- re-renders that file on every wallpaper switch; this watches its
-- directory with vim.uv.fs_event (no post_hook, no --remote-send typed
-- into a focused buffer) and re-sources it in every running nvim, but only
-- while "matugen" is still the active colorscheme -- a user who ran
-- `:colorscheme gruvbox-material` is left alone.
--
-- Required once from init.lua (require("matugen_watch")); a no-op after
-- the first call so re-requiring (e.g. from :luafile during testing) is
-- harmless.

local M = {}

if M._started then
  return M
end
M._started = true

local uv = vim.uv or vim.loop
local target = vim.fn.stdpath("config") .. "/colors/matugen.lua"
local watch_dir = vim.fn.stdpath("config") .. "/colors"

local debounce_timer = nil

local function reload()
  if vim.g.colors_name ~= "matugen" then
    return
  end
  -- pcall: a reload caught mid-write by matugen (partial file) must not
  -- error out of the fs_event callback or blow up the user's session.
  pcall(vim.cmd.colorscheme, "matugen")
end

local function on_event(err, filename, _events)
  if err then
    return
  end
  if filename ~= "matugen.lua" then
    return
  end
  if debounce_timer then
    debounce_timer:stop()
    debounce_timer:close()
  end
  debounce_timer = uv.new_timer()
  debounce_timer:start(150, 0, function()
    debounce_timer:stop()
    debounce_timer:close()
    debounce_timer = nil
    vim.schedule(reload)
  end)
end

local handle = uv.new_fs_event()
if handle then
  local ok = handle:start(watch_dir, {}, on_event)
  if not ok then
    handle:close()
  else
    vim.api.nvim_create_autocmd("VimLeavePre", {
      once = true,
      callback = function()
        if not handle:is_closing() then
          handle:stop()
          handle:close()
        end
      end,
    })
  end
end

M.target = target
return M
