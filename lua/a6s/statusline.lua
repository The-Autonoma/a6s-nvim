-- Statusline component showing connection status + RIGOR phase
local M = {}

M.state = {
  connected = false,
  current_phase = nil, -- "research" | "inspect" | "generate" | "optimize" | "review"
  phase_progress = 0,
}

local phase_icons = {
  research = "R",
  inspect = "I",
  generate = "G",
  optimize = "O",
  review = "V",
}

function M.set_connected(v)
  M.state.connected = v
  vim.schedule(function() pcall(vim.cmd, "redrawstatus") end)
end

function M.set_phase(phase, progress)
  M.state.current_phase = phase
  M.state.phase_progress = progress or 0
  vim.schedule(function() pcall(vim.cmd, "redrawstatus") end)
end

function M.clear_phase()
  M.state.current_phase = nil
  M.state.phase_progress = 0
  vim.schedule(function() pcall(vim.cmd, "redrawstatus") end)
end

-- Returns a short string suitable for statusline
function M.component()
  local conn = M.state.connected and "●" or "○"
  if M.state.current_phase then
    local icon = phase_icons[M.state.current_phase] or "?"
    return string.format("A6s %s [%s %d%%]", conn, icon, M.state.phase_progress)
  end
  return string.format("A6s %s", conn)
end

-- Lualine-style component
function M.lualine_component()
  return {
    M.component,
    color = function()
      if not M.state.connected then
        return { fg = "#888888" }
      end
      return { fg = "#8ec07c" }
    end,
  }
end

function M.setup(opts)
  opts = opts or {}
  -- Create autocmd user event for external redraws
  vim.api.nvim_create_augroup("A6sStatusline", { clear = true })
end

return M
