-- Tests for commands dispatch and input validation
describe("a6s.commands", function()
  local commands = require("a6s.commands")
  local notify = require("a6s.notify")
  local api = require("a6s.api")

  before_each(function()
    api.reset_state()
  end)

  it("registers all user commands on setup()", function()
    commands.setup()
    local expected = {
      "A6sConnect", "A6sDisconnect", "A6sInvoke",
      "A6sExplain", "A6sRefactor", "A6sReview",
      "A6sGenerateTests", "A6sTasks", "A6sCancelTask",
      "A6sPreview", "A6sApply", "A6sInstall",
      "A6sAgents", "A6sStatus", "A6sLaunch", "A6sOutput",
    }
    local cmds = vim.api.nvim_get_commands({})
    for _, name in ipairs(expected) do
      assert.is_not_nil(cmds[name], "missing command: " .. name)
    end
  end)

  it("validate_input rejects empty string", function()
    assert.is_nil(notify.validate_input("", "field"))
    assert.is_nil(notify.validate_input("   \t\n  ", "field"))
  end)

  it("validate_input rejects non-string", function()
    assert.is_nil(notify.validate_input(nil, "field"))
    assert.is_nil(notify.validate_input(123, "field"))
  end)

  it("validate_input rejects overly long input", function()
    local huge = string.rep("x", notify.MAX_INPUT_LEN + 1)
    assert.is_nil(notify.validate_input(huge, "field"))
  end)

  it("validate_input trims whitespace", function()
    assert.equals("hello", notify.validate_input("  hello  ", "field"))
  end)

  it("validate_input accepts exactly MAX length", function()
    local max = string.rep("a", notify.MAX_INPUT_LEN)
    assert.equals(max, notify.validate_input(max, "field"))
  end)

  it("cmd_disconnect does not error when not connected", function()
    assert.has_no.errors(function() commands.cmd_disconnect() end)
  end)

  it("cmd_preview warns when no artifacts", function()
    require("a6s").state.last_artifacts = nil
    assert.has_no.errors(function() commands.cmd_preview() end)
  end)

  it("cmd_apply warns when no artifacts", function()
    require("a6s").state.last_artifacts = {}
    assert.has_no.errors(function() commands.cmd_apply() end)
  end)

  it("cmd_invoke errors when not connected", function()
    assert.has_no.errors(function() commands.cmd_invoke("a", "b") end)
  end)

  it("cmd_install does not error", function()
    assert.has_no.errors(function() commands.cmd_install() end)
  end)

  it("cmd_agents errors when not connected", function()
    assert.has_no.errors(function() commands.cmd_agents() end)
  end)

  it("cmd_execution_status errors when not connected", function()
    assert.has_no.errors(function() commands.cmd_execution_status("exec-123") end)
  end)

  it("cmd_background_launch errors when not connected", function()
    assert.has_no.errors(function() commands.cmd_background_launch() end)
  end)

  it("cmd_background_output errors when not connected", function()
    assert.has_no.errors(function() commands.cmd_background_output("task-123") end)
  end)
end)
