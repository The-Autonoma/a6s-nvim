-- Minimal init for plenary-busted tests
local root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(root)

-- Locate plenary
local function find_plenary()
  local candidates = {
    os.getenv("PLENARY_PATH"),
    vim.fn.stdpath("data") .. "/lazy/plenary.nvim",
    vim.fn.stdpath("data") .. "/site/pack/vendor/start/plenary.nvim",
    vim.fn.expand("~/.local/share/nvim/site/pack/test/start/plenary.nvim"),
    "/tmp/nvim/site/pack/plenary/start/plenary.nvim",
  }
  for _, c in ipairs(candidates) do
    if c and vim.fn.isdirectory(c) == 1 then
      vim.opt.runtimepath:append(c)
      return c
    end
  end
  return nil
end

find_plenary()
vim.cmd("runtime plugin/plenary.vim")
