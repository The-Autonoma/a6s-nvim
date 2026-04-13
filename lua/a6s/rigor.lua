-- Floating window showing 5-phase RIGOR progress bars
local M = {}

M.phases = { "research", "inspect", "generate", "optimize", "review" }
M.phase_labels = {
  research = "Research",
  inspect  = "Inspect ",
  generate = "Generate",
  optimize = "Optimize",
  review   = "Review  ",
}

M.state = {
  win = nil,
  buf = nil,
  execution_id = nil,
  phase_state = {}, -- name -> { status, progress }
}

local function init_phase_state()
  M.state.phase_state = {}
  for _, p in ipairs(M.phases) do
    M.state.phase_state[p] = { status = "pending", progress = 0 }
  end
end

local function render_bar(progress, width)
  width = width or 20
  progress = math.max(0, math.min(100, progress or 0))
  local filled = math.floor(width * progress / 100)
  return "[" .. string.rep("█", filled) .. string.rep("░", width - filled) .. "]"
end

local function status_glyph(status)
  if status == "completed" then return "✓"
  elseif status == "failed" then return "✗"
  elseif status == "running" then return "⟳"
  else return " " end
end

function M.render()
  if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then return end

  local lines = {
    " A6s RIGOR Execution",
    " " .. string.rep("─", 38),
    "",
  }

  for _, p in ipairs(M.phases) do
    local ps = M.state.phase_state[p] or { status = "pending", progress = 0 }
    local line = string.format(" %s %s  %s %3d%%",
      status_glyph(ps.status),
      M.phase_labels[p],
      render_bar(ps.progress, 20),
      ps.progress)
    table.insert(lines, line)
  end

  table.insert(lines, "")
  if M.state.execution_id then
    table.insert(lines, " id: " .. M.state.execution_id)
  end
  table.insert(lines, " Press q to close")

  vim.api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(M.state.buf, "modifiable", false)
end

function M.open(execution_id)
  M.close()
  init_phase_state()
  M.state.execution_id = execution_id

  local buf = vim.api.nvim_create_buf(false, true)
  M.state.buf = buf
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "a6s-rigor")

  local width = 44
  local height = 12
  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local row = math.floor((ui.height - height) / 2)
  local col = math.floor((ui.width - width) / 2)

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width, height = height,
    row = row, col = col,
    style = "minimal", border = "rounded",
    title = " RIGOR ", title_pos = "center",
  })
  M.state.win = win

  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    callback = function() M.close() end,
    noremap = true, silent = true,
  })

  M.render()
end

function M.close()
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    pcall(vim.api.nvim_win_close, M.state.win, true)
  end
  if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    pcall(vim.api.nvim_buf_delete, M.state.buf, { force = true })
  end
  M.state.win = nil
  M.state.buf = nil
end

function M.update_phase(phase, status, progress)
  if not M.state.phase_state[phase] then
    M.state.phase_state[phase] = { status = "pending", progress = 0 }
  end
  M.state.phase_state[phase].status = status or M.state.phase_state[phase].status
  M.state.phase_state[phase].progress = progress or M.state.phase_state[phase].progress
  M.render()
end

function M.is_open()
  return M.state.win ~= nil and vim.api.nvim_win_is_valid(M.state.win)
end

return M
