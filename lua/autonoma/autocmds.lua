-- Autocmds & event wiring
local M = {}

function M.setup()
  local group = vim.api.nvim_create_augroup("Autonoma", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      pcall(function() require("autonoma.api").disconnect() end)
    end,
  })
end

return M
