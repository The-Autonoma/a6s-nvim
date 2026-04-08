-- Autonoma.nvim plugin loader — minimal entry, defines user commands only.
if vim.g.loaded_autonoma then return end
vim.g.loaded_autonoma = 1

-- Provide :AutonomaSetup as lightweight entry for lazy loading
vim.api.nvim_create_user_command("AutonomaSetup", function(opts)
  local cfg = {}
  if opts.args ~= "" then
    local ok, fn = pcall(loadstring, "return " .. opts.args)
    if ok and fn then
      local ok2, parsed = pcall(fn)
      if ok2 and type(parsed) == "table" then cfg = parsed end
    end
  end
  require("autonoma").setup(cfg)
end, { desc = "Setup Autonoma plugin", nargs = "*" })
