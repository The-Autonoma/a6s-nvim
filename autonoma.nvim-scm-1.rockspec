rockspec_format = "3.0"
package = "autonoma.nvim"
version = "scm-1"

source = {
  url = "git+https://github.com/autonoma/autonoma.nvim.git",
}

description = {
  summary = "Neovim client for the Autonoma Code daemon",
  detailed = [[
    Official Neovim integration for Autonoma Code. Connects to the local
    Autonoma CLI daemon over WebSocket (ws://localhost:9876/ws) and provides
    commands to invoke agents, stream RIGOR phase updates, review/apply
    artifacts, and manage background tasks. Pure Lua, Neovim 0.9+.
  ]],
  homepage = "https://github.com/autonoma/autonoma.nvim",
  license = "MIT",
  labels = { "neovim", "ai", "autonoma", "websocket" },
}

dependencies = {
  "lua >= 5.1",
  "plenary.nvim",
}

test_dependencies = {
  "plenary.nvim",
}

build = {
  type = "builtin",
  copy_directories = { "doc", "plugin" },
}

test = {
  type = "command",
  command = "make test",
}
