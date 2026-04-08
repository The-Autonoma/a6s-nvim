-- Notification wrapper with nvim-notify integration and vim.notify fallback
local M = {}

local has_notify, notify = pcall(require, "notify")

local function send(msg, level, opts)
  opts = opts or {}
  opts.title = opts.title or "A6s"
  if has_notify then
    notify(msg, level, opts)
  else
    vim.notify(msg, level)
  end
end

function M.info(msg, opts) send(msg, vim.log.levels.INFO, opts) end
function M.warn(msg, opts) send(msg, vim.log.levels.WARN, opts) end
function M.error(msg, opts) send(msg, vim.log.levels.ERROR, opts) end
function M.debug(msg, opts) send(msg, vim.log.levels.DEBUG, opts) end

function M.success(msg, opts)
  opts = opts or {}
  opts.icon = opts.icon or "✓"
  send(msg, vim.log.levels.INFO, opts)
end

function M.progress(msg, opts)
  opts = opts or {}
  opts.icon = opts.icon or "⟳"
  opts.timeout = opts.timeout or false
  send(msg, vim.log.levels.INFO, opts)
end

-- Validation helpers
local MAX_INPUT_LEN = 10000

function M.validate_input(text, field_name)
  field_name = field_name or "input"
  if type(text) ~= "string" then
    M.error(field_name .. " must be a string")
    return nil
  end
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    M.error(field_name .. " cannot be empty")
    return nil
  end
  if #trimmed > MAX_INPUT_LEN then
    M.error(field_name .. " exceeds maximum length (" .. MAX_INPUT_LEN .. ")")
    return nil
  end
  return trimmed
end

M.MAX_INPUT_LEN = MAX_INPUT_LEN

return M
