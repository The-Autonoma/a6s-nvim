-- Tests for commands dispatch and input validation
describe("autonoma.commands", function()
  local commands = require("autonoma.commands")
  local notify = require("autonoma.notify")
  local api = require("autonoma.api")

  before_each(function()
    api.reset_state()
  end)

  it("registers all user commands on setup()", function()
    commands.setup()
    local expected = {
      "AutonomaConnect", "AutonomaDisconnect", "AutonomaInvoke",
      "AutonomaExplain", "AutonomaRefactor", "AutonomaReview",
      "AutonomaGenerateTests", "AutonomaTasks", "AutonomaCancelTask",
      "AutonomaPreview", "AutonomaApply", "AutonomaInstall",
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
    require("autonoma").state.last_artifacts = nil
    assert.has_no.errors(function() commands.cmd_preview() end)
  end)

  it("cmd_apply warns when no artifacts", function()
    require("autonoma").state.last_artifacts = {}
    assert.has_no.errors(function() commands.cmd_apply() end)
  end)

  it("cmd_invoke errors when not connected", function()
    assert.has_no.errors(function() commands.cmd_invoke("a", "b") end)
  end)

  it("cmd_install does not error", function()
    assert.has_no.errors(function() commands.cmd_install() end)
  end)
end)
