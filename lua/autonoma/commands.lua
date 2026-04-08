-- User commands for A6s
local M = {}

local function get_visual_selection()
  local s_start = vim.fn.getpos("'<")
  local s_end = vim.fn.getpos("'>")
  local n_lines = math.abs(s_end[2] - s_start[2]) + 1
  local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)
  if #lines == 0 then return "" end
  -- Adjust first/last line for column
  lines[1] = string.sub(lines[1], s_start[3], -1)
  if n_lines == 1 then
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3] - s_start[3] + 1)
  else
    lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
  end
  return table.concat(lines, "\n")
end

local function current_buffer_info()
  return {
    file_path = vim.api.nvim_buf_get_name(0),
    language = vim.bo.filetype,
  }
end

local function show_text_float(title, text)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  local lines = vim.split(text or "", "\n")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  local ui = vim.api.nvim_list_uis()[1] or { width = 80, height = 24 }
  local width = math.floor(ui.width * 0.8)
  local height = math.floor(ui.height * 0.7)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", width = width, height = height,
    row = math.floor((ui.height - height) / 2),
    col = math.floor((ui.width - width) / 2),
    style = "minimal", border = "rounded",
    title = " " .. title .. " ", title_pos = "center",
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>close<CR>", { noremap = true, silent = true })
  return buf, win
end

function M.cmd_connect()
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")
  if api.is_connected() then
    notify.info("Already connected")
    return
  end
  api.connect(function()
    notify.success("Connected to A6s daemon")
  end)
  -- Offer install hint if it fails
  vim.defer_fn(function()
    if not api.is_connected() then
      notify.warn("Run `a6s code --daemon` to start the A6s daemon, or `:AutonomaInstall`")
    end
  end, 6000)
end

function M.cmd_disconnect()
  require("autonoma.api").disconnect()
  require("autonoma.notify").info("Disconnected")
end

function M.cmd_invoke(agent_type, task)
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")
  local rigor = require("autonoma.rigor")

  if not api.is_connected() then
    notify.error("Not connected. Run :AutonomaConnect")
    return
  end

  local function do_invoke(atype, atask)
    atype = notify.validate_input(atype, "agentType")
    atask = notify.validate_input(atask, "task")
    if not atype or not atask then return end

    api.invoke_agent(atype, atask, nil, function(result, err)
      if err then
        notify.error("invoke failed: " .. tostring(err))
        return
      end
      local exec_id = result and result.executionId
      if exec_id then
        notify.info("Execution started: " .. exec_id)
        rigor.open(exec_id)
      end
    end)
  end

  if agent_type and task then
    do_invoke(agent_type, task)
    return
  end

  -- Prompt interactively
  vim.ui.input({ prompt = "Agent: " }, function(atype)
    if not atype then return end
    vim.ui.input({ prompt = "Task: " }, function(atask)
      if not atask then return end
      do_invoke(atype, atask)
    end)
  end)
end

local function code_op(method_name, extra)
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")
  if not api.is_connected() then
    notify.error("Not connected. Run :AutonomaConnect")
    return
  end
  local code = get_visual_selection()
  code = notify.validate_input(code, "selection")
  if not code then return end
  local info = current_buffer_info()

  if method_name == "explain" then
    api.explain_code(code, info.language, info.file_path, function(result, err)
      if err then notify.error("explain failed: " .. tostring(err)); return end
      vim.schedule(function() show_text_float("Explain", tostring(result or "")) end)
    end)
  elseif method_name == "refactor" then
    api.refactor_code(code, info.language, info.file_path, extra, function(result, err)
      if err then notify.error("refactor failed: " .. tostring(err)); return end
      vim.schedule(function()
        show_text_float("Refactor Artifacts",
          "Received " .. tostring(#(result or {})) .. " artifacts. Use :AutonomaPreview/:AutonomaApply")
        require("autonoma").state.last_artifacts = result
      end)
    end)
  elseif method_name == "tests" then
    api.generate_tests(code, info.language, info.file_path, function(result, err)
      if err then notify.error("tests failed: " .. tostring(err)); return end
      require("autonoma").state.last_artifacts = result
      vim.schedule(function()
        show_text_float("Generated Tests",
          "Received " .. tostring(#(result or {})) .. " artifacts. Use :AutonomaPreview/:AutonomaApply")
      end)
    end)
  elseif method_name == "review" then
    api.review_code(code, info.language, info.file_path, extra or "all", function(result, err)
      if err then notify.error("review failed: " .. tostring(err)); return end
      vim.schedule(function()
        local lines = { "# Review\n", (result and result.summary) or "", "" }
        for _, issue in ipairs((result and result.issues) or {}) do
          table.insert(lines, string.format("- [%s] line %s: %s",
            issue.severity or "?", tostring(issue.line or "?"), issue.message or ""))
        end
        show_text_float("Review", table.concat(lines, "\n"))
      end)
    end)
  end
end

function M.cmd_explain() code_op("explain") end
function M.cmd_refactor(instructions) code_op("refactor", instructions) end
function M.cmd_review(review_type) code_op("review", review_type) end
function M.cmd_generate_tests() code_op("tests") end

function M.cmd_tasks()
  local telescope = require("autonoma.telescope")
  telescope.tasks_picker(function(t)
    vim.notify("Selected task: " .. (t.id or "?"), vim.log.levels.INFO)
  end)
end

function M.cmd_cancel_task(task_id)
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")
  if not task_id or task_id == "" then
    vim.ui.input({ prompt = "Task ID: " }, function(tid)
      if not tid or tid == "" then return end
      M.cmd_cancel_task(tid)
    end)
    return
  end
  api.cancel_background_task(task_id, function(_, err)
    if err then notify.error("cancel failed: " .. tostring(err))
    else notify.info("Cancelled " .. task_id) end
  end)
end

function M.cmd_preview()
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")
  local artifacts = require("autonoma").state.last_artifacts
  if not artifacts or #artifacts == 0 then
    notify.warn("No artifacts to preview")
    return
  end
  api.preview_artifacts(artifacts, function(result, err)
    if err then notify.error("preview failed: " .. tostring(err)); return end
    vim.schedule(function()
      local lines = { "# Preview" }
      for _, f in ipairs((result and result.files) or {}) do
        table.insert(lines, string.format("- %s: %s", f.action or "?", f.path or "?"))
        if f.diff then
          table.insert(lines, "```diff")
          for _, dl in ipairs(vim.split(f.diff, "\n")) do table.insert(lines, dl) end
          table.insert(lines, "```")
        end
      end
      show_text_float("Preview", table.concat(lines, "\n"))
    end)
  end)
end

function M.cmd_apply()
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")
  local artifacts = require("autonoma").state.last_artifacts
  if not artifacts or #artifacts == 0 then
    notify.warn("No artifacts to apply")
    return
  end
  vim.ui.select({ "Yes", "No" }, { prompt = "Apply " .. #artifacts .. " artifact(s)?" }, function(choice)
    if choice ~= "Yes" then return end
    api.apply_artifacts(artifacts, function(result, err)
      if err then notify.error("apply failed: " .. tostring(err)); return end
      notify.success(string.format("Applied %d / skipped %d",
        (result and result.applied) or 0, (result and result.skipped) or 0))
    end)
  end)
end

function M.cmd_install()
  local url = "https://www.theautonoma.io/docs/cli/daemon"
  vim.notify("See: " .. url, vim.log.levels.INFO)
  -- Best-effort open in browser
  local opener = (vim.fn.has("mac") == 1) and "open"
    or (vim.fn.has("unix") == 1) and "xdg-open"
    or (vim.fn.has("win32") == 1) and "start"
  if opener then pcall(vim.fn.jobstart, { opener, url }, { detach = true }) end
end

function M.cmd_agents()
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")

  if not api.is_connected() then
    notify.error("Not connected. Run :AutonomaConnect")
    return
  end

  api.list_agents(function(result, err)
    if err then
      notify.error("agents list failed: " .. tostring(err))
      return
    end

    local agents = result and result.agents or result or {}
    if #agents == 0 then
      notify.warn("No agents available")
      return
    end

    vim.schedule(function()
      local lines = { "# Agents", "" }
      for _, agent in ipairs(agents) do
        local id = agent.id or "?"
        local name = agent.name or id
        local desc = agent.description or ""
        table.insert(lines, string.format("- **%s** (%s): %s", name, id, desc))
      end
      show_text_float("Agents", table.concat(lines, "\n"))
    end)
  end)
end

function M.cmd_execution_status(execution_id)
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")

  if not api.is_connected() then
    notify.error("Not connected. Run :AutonomaConnect")
    return
  end

  local function do_status(eid)
    eid = notify.validate_input(eid, "executionId")
    if not eid then return end

    api.execution_status(eid, function(result, err)
      if err then
        notify.error("execution status failed: " .. tostring(err))
        return
      end
      vim.schedule(function()
        local status = result and result.status or "unknown"
        local phase = result and result.phase or "unknown"
        local progress = result and result.progress or 0
        notify.info(string.format("Execution %s: status=%s phase=%s progress=%d%%",
          eid, status, phase, progress))
      end)
    end)
  end

  if execution_id and execution_id ~= "" then
    do_status(execution_id)
    return
  end

  vim.ui.input({ prompt = "Execution ID: " }, function(eid)
    if not eid or eid == "" then return end
    do_status(eid)
  end)
end

function M.cmd_background_launch()
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")

  if not api.is_connected() then
    notify.error("Not connected. Run :AutonomaConnect")
    return
  end

  api.list_agents(function(result, err)
    if err then
      notify.error("agents list failed: " .. tostring(err))
      return
    end

    local agents = result and result.agents or result or {}
    if #agents == 0 then
      notify.warn("No agents available")
      return
    end

    vim.schedule(function()
      local display_items = {}
      for _, agent in ipairs(agents) do
        table.insert(display_items, (agent.name or agent.id or "?") .. " (" .. (agent.id or "?") .. ")")
      end

      vim.ui.select(display_items, { prompt = "Select agent:" }, function(_, idx)
        if not idx then return end
        local agent = agents[idx]
        local agent_type = agent.id or agent.name

        vim.ui.input({ prompt = "Task: " }, function(task)
          task = notify.validate_input(task, "task")
          if not task then return end

          api.launch_background_task(task, agent_type, function(launch_result, launch_err)
            if launch_err then
              notify.error("launch failed: " .. tostring(launch_err))
              return
            end
            local task_id = launch_result and (launch_result.taskId or launch_result.task_id)
            if task_id then
              notify.info("Background task started: " .. task_id)
            else
              notify.info("Background task launched")
            end
          end)
        end)
      end)
    end)
  end)
end

function M.cmd_background_output(task_id)
  local api = require("autonoma.api")
  local notify = require("autonoma.notify")

  if not api.is_connected() then
    notify.error("Not connected. Run :AutonomaConnect")
    return
  end

  local function do_output(tid)
    tid = notify.validate_input(tid, "taskId")
    if not tid then return end

    api.get_task_output(tid, function(result, err)
      if err then
        notify.error("output failed: " .. tostring(err))
        return
      end
      vim.schedule(function()
        local output = result and (result.output or result.content or vim.inspect(result)) or "No output"
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option(buf, "swapfile", false)
        local lines = vim.split(tostring(output), "\n")
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_name(buf, "autonoma://task/" .. tid)
        vim.cmd("split")
        vim.api.nvim_win_set_buf(0, buf)
      end)
    end)
  end

  if task_id and task_id ~= "" then
    do_output(task_id)
    return
  end

  vim.ui.input({ prompt = "Task ID: " }, function(tid)
    if not tid or tid == "" then return end
    do_output(tid)
  end)
end

function M.setup()
  local cmd = vim.api.nvim_create_user_command
  cmd("AutonomaConnect", function() M.cmd_connect() end, { desc = "Connect to A6s daemon" })
  cmd("AutonomaDisconnect", function() M.cmd_disconnect() end, { desc = "Disconnect from daemon" })
  cmd("AutonomaInvoke", function(opts)
    local args = opts.fargs
    M.cmd_invoke(args[1], args[2] and table.concat(vim.list_slice(args, 2), " "))
  end, { desc = "Invoke an agent", nargs = "*" })
  cmd("AutonomaExplain", function() M.cmd_explain() end, { desc = "Explain selection", range = true })
  cmd("AutonomaRefactor", function(opts) M.cmd_refactor(opts.args ~= "" and opts.args or nil) end,
    { desc = "Refactor selection", range = true, nargs = "*" })
  cmd("AutonomaReview", function(opts) M.cmd_review(opts.args ~= "" and opts.args or nil) end,
    { desc = "Review selection", range = true, nargs = "?" })
  cmd("AutonomaGenerateTests", function() M.cmd_generate_tests() end,
    { desc = "Generate tests for selection", range = true })
  cmd("AutonomaTasks", function() M.cmd_tasks() end, { desc = "List background tasks" })
  cmd("AutonomaCancelTask", function(opts) M.cmd_cancel_task(opts.args) end,
    { desc = "Cancel a background task", nargs = "?" })
  cmd("AutonomaPreview", function() M.cmd_preview() end, { desc = "Preview last artifacts" })
  cmd("AutonomaApply", function() M.cmd_apply() end, { desc = "Apply last artifacts" })
  cmd("AutonomaInstall", function() M.cmd_install() end, { desc = "Open daemon install docs" })
  cmd("AutonomaAgents", function() M.cmd_agents() end, { desc = "List available agents" })
  cmd("AutonomaStatus", function(opts) M.cmd_execution_status(opts.args ~= "" and opts.args or nil) end,
    { desc = "Show execution status", nargs = "?" })
  cmd("AutonomaLaunch", function() M.cmd_background_launch() end, { desc = "Launch background task" })
  cmd("AutonomaOutput", function(opts) M.cmd_background_output(opts.args ~= "" and opts.args or nil) end,
    { desc = "Show background task output", nargs = "?" })
end

-- Expose helpers for testing
M._get_visual_selection = get_visual_selection
M._show_text_float = show_text_float

return M
