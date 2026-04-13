# a6s.nvim

Official Neovim client for **A6s** -- Intelligent Multi-Agent Orchestration. Connects to the local A6s CLI daemon over WebSocket (`ws://localhost:9876/ws`) and provides commands to invoke AI agents, stream RIGOR phase updates, review/apply generated artifacts, and manage background tasks.

- **Pure Lua**, no FFI, Neovim 0.9+
- **Zero credentials** — the daemon is the only component that talks to the orchestrator
- **30s** request timeout, **5s** connect timeout, exponential reconnect (1→16s, 5 attempts)

## Requirements

- Neovim 0.9+
- A6s CLI in daemon mode: `a6s code --daemon`
- Optional: telescope.nvim (agent/task pickers), nvim-notify (rich notifications)

## Install

**lazy.nvim**
```lua
{
  "autonoma/a6s.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  opts = { telemetry_enabled = false },
}
```

**packer.nvim**
```lua
use {
  "autonoma/a6s.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function() require("a6s").setup({ telemetry_enabled = false }) end,
}
```

**vim-plug**
```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'autonoma/a6s.nvim'
lua require('a6s').setup({ telemetry_enabled = false })
```

**rocks.nvim** — `:Rocks install a6s.nvim`

## Configuration

```lua
require("a6s").setup({
  daemon_port = 9876,
  daemon_host = "127.0.0.1",
  auto_connect = true,
  keymaps_enabled = true,
  telemetry_enabled = false, -- set explicitly to silence first-run prompt
  statusline_enabled = true,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:A6sConnect` | Connect to daemon |
| `:A6sDisconnect` | Disconnect |
| `:A6sInvoke [agent task]` | Invoke an agent |
| `:A6sExplain` | Explain visual selection |
| `:A6sRefactor [instr]` | Refactor visual selection |
| `:A6sReview [type]` | Review visual selection (security/performance/quality/all) |
| `:A6sGenerateTests` | Generate tests for selection |
| `:A6sTasks` | List background tasks |
| `:A6sCancelTask [id]` | Cancel a task |
| `:A6sPreview` | Preview last artifacts (diff) |
| `:A6sApply` | Apply last artifacts |

## Default keymaps

| Keymap | Mode | Action |
|--------|------|--------|
| `<leader>aa` | n | Invoke agent |
| `<leader>ae` | v | Explain |
| `<leader>ar` | v | Refactor |
| `<leader>av` | v | Review |
| `<leader>at` | v | Generate tests |
| `<leader>al` | n | Task list |

## Statusline (lualine)

```lua
require("lualine").setup({
  sections = { lualine_x = { require("a6s.statusline").lualine_component() } }
})
```

## Protocol

Full spec and daemon bootstrap guide: <https://www.theautonoma.io/docs/build/cli/daemon>. All 13 methods are implemented:
`agents.list`, `agents.invoke`, `execution.status`, `background.{list,launch,cancel,output}`, `artifacts.{preview,apply}`, `code.{explain,refactor,generateTests,review}`.

## Development

```bash
make install         # fetch plenary.nvim
make lint            # luacheck
make test            # plenary busted
make test-coverage   # luacov (fails if <80%)
```

## License

MIT
