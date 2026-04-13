-- A6s.nvim plugin loader — minimal entry, defines user commands only.
if vim.g.loaded_a6s then return end
vim.g.loaded_a6s = 1

-- Provide :A6sSetup as lightweight entry for lazy loading
vim.api.nvim_create_user_command("A6sSetup", function(opts)
  local cfg = {}
  if opts.args ~= "" then
    local ok, fn = pcall(loadstring, "return " .. opts.args)
    if ok and fn then
      local ok2, parsed = pcall(fn)
      if ok2 and type(parsed) == "table" then cfg = parsed end
    end
  end
  require("a6s").setup(cfg)
end, { desc = "Setup A6s plugin", nargs = "*" })
