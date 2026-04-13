-- Telescope pickers for agents and background tasks
local M = {}

local function has_telescope()
  local ok = pcall(require, "telescope")
  return ok
end

function M.agents_picker(on_select)
  if not has_telescope() then
    vim.notify("telescope.nvim required", vim.log.levels.WARN)
    return
  end
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local api = require("a6s.api")

  api.list_agents(function(agents, err)
    if err then
      vim.notify("list_agents: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    vim.schedule(function()
      pickers.new({}, {
        prompt_title = "A6s Agents",
        finder = finders.new_table({
          results = agents or {},
          entry_maker = function(a)
            return {
              value = a,
              display = string.format("%-20s %s  %s", a.name or a.id, a.status or "?", a.description or ""),
              ordinal = (a.name or "") .. " " .. (a.description or ""),
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local sel = action_state.get_selected_entry()
            if sel and on_select then on_select(sel.value) end
          end)
          return true
        end,
      }):find()
    end)
  end)
end

function M.tasks_picker(on_select)
  if not has_telescope() then
    vim.notify("telescope.nvim required", vim.log.levels.WARN)
    return
  end
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local api = require("a6s.api")

  api.list_background_tasks(function(tasks, err)
    if err then
      vim.notify("list tasks: " .. tostring(err), vim.log.levels.ERROR)
      return
    end
    vim.schedule(function()
      pickers.new({}, {
        prompt_title = "A6s Background Tasks",
        finder = finders.new_table({
          results = tasks or {},
          entry_maker = function(t)
            return {
              value = t,
              display = string.format("%s %-10s %3d%%  %s",
                t.id or "?", t.status or "?", t.progress or 0, t.task or ""),
              ordinal = (t.task or "") .. " " .. (t.agentType or ""),
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local sel = action_state.get_selected_entry()
            if sel and on_select then on_select(sel.value) end
          end)
          return true
        end,
      }):find()
    end)
  end)
end

return M
