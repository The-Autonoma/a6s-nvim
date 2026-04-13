-- A6s for Neovim — entry point
-- Pure Lua, Neovim 0.9+, connects to local daemon over WebSocket.

local M = {}

M.config = {
  daemon_port = 9876,
  daemon_host = "127.0.0.1",
  auto_connect = true,
  keymaps_enabled = true,
  keymaps = nil, -- override table passed to keymaps.setup
  telemetry_enabled = nil, -- must be set explicitly
  statusline_enabled = true,
}

M.state = {
  initialized = false,
  last_artifacts = nil,
}

local function wire_events()
  local api = require("a6s.api")
  local statusline = require("a6s.statusline")
  local rigor = require("a6s.rigor")

  api.on("connected", function()
    statusline.set_connected(true)
  end)
  api.on("disconnected", function()
    statusline.set_connected(false)
  end)
  api.on("phase.update", function(data)
    if data and data.phase then
      statusline.set_phase(data.phase, data.progress or 0)
      if rigor.is_open() then
        rigor.update_phase(data.phase, data.status, data.progress)
      end
    end
  end)
  api.on("execution.complete", function(_)
    statusline.clear_phase()
  end)
  api.on("task.update", function(_) end) -- no-op, picker refreshes on demand
end

function M.setup(opts)
  M.config = vim.tbl_extend("force", M.config, opts or {})

  if vim.fn.has("nvim-0.9") == 0 then
    vim.notify("a6s.nvim requires Neovim 0.9+", vim.log.levels.ERROR)
    return
  end

  local api = require("a6s.api")
  api.setup({
    port = M.config.daemon_port,
    host = M.config.daemon_host,
  })

  require("a6s.commands").setup()
  require("a6s.autocmds").setup()

  if M.config.statusline_enabled then
    require("a6s.statusline").setup({})
  end

  if M.config.keymaps_enabled then
    require("a6s.keymaps").setup({
      enabled = true,
      keys = M.config.keymaps,
    })
  end

  wire_events()

  -- Telemetry opt-in prompt (one-line, first setup only)
  if M.config.telemetry_enabled == nil and not M.state.initialized then
    vim.notify(
      "a6s.nvim: set `telemetry_enabled = true|false` in setup() to silence this notice.",
      vim.log.levels.INFO
    )
  end

  if M.config.auto_connect then
    vim.defer_fn(function()
      api.connect(function() end)
      vim.defer_fn(function()
        if not api.is_connected() then
          vim.notify(
            "A6s: could not connect to daemon. Run `a6s code --daemon` to start it, or see :A6sInstall",
            vim.log.levels.WARN
          )
        end
      end, 6000)
    end, 100)
  end

  M.state.initialized = true
end

-- Public API helpers
function M.is_connected() return require("a6s.api").is_connected() end
function M.statusline_component() return require("a6s.statusline").component() end

-- :checkhealth a6s stub
function M.check()
  local health = vim.health or require("health")
  local start = health.start or health.report_start
  local ok = health.ok or health.report_ok
  local warn = health.warn or health.report_warn
  local err = health.error or health.report_error

  start("A6s for Neovim")
  if vim.fn.has("nvim-0.9") == 1 then
    ok("Neovim 0.9+ detected")
  else
    err("Neovim 0.9+ required")
  end

  local has_plenary = pcall(require, "plenary")
  if has_plenary then ok("plenary.nvim found") else warn("plenary.nvim not found (optional)") end

  local has_telescope = pcall(require, "telescope")
  if has_telescope then ok("telescope.nvim found") else warn("telescope.nvim not found (optional)") end

  local api = require("a6s.api")
  if api.is_connected() then
    ok("connected to daemon on port " .. api.config.port)
  else
    warn("not connected — run :A6sConnect or `a6s code --daemon`")
  end
end

return M
