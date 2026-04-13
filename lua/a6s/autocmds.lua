-- Autocmds & event wiring
local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("A6s", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      pcall(function() require("a6s.api").disconnect() end)
    end,
  })
end

return M
