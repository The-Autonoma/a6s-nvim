-- Default keymaps (opt-in via setup config)
local M = {}

M.defaults = {
  invoke = "<leader>aa",
  explain = "<leader>ae",
  refactor = "<leader>ar",
  review = "<leader>av",
  tests = "<leader>at",
  tasks = "<leader>al",
}

function M.setup(opts)
  opts = opts or {}
  if opts.enabled == false then return end
  local keys = vim.tbl_extend("force", M.defaults, opts.keys or {})
  local o = { noremap = true, silent = true }

  if keys.invoke then
    vim.keymap.set("n", keys.invoke, "<cmd>AutonomaInvoke<CR>",
      vim.tbl_extend("force", o, { desc = "Autonoma: invoke agent" }))
  end
  if keys.explain then
    vim.keymap.set("v", keys.explain, "<cmd>AutonomaExplain<CR>",
      vim.tbl_extend("force", o, { desc = "Autonoma: explain selection" }))
  end
  if keys.refactor then
    vim.keymap.set("v", keys.refactor, "<cmd>AutonomaRefactor<CR>",
      vim.tbl_extend("force", o, { desc = "Autonoma: refactor selection" }))
  end
  if keys.review then
    vim.keymap.set("v", keys.review, "<cmd>AutonomaReview<CR>",
      vim.tbl_extend("force", o, { desc = "Autonoma: review selection" }))
  end
  if keys.tests then
    vim.keymap.set("v", keys.tests, "<cmd>AutonomaGenerateTests<CR>",
      vim.tbl_extend("force", o, { desc = "Autonoma: generate tests" }))
  end
  if keys.tasks then
    vim.keymap.set("n", keys.tasks, "<cmd>AutonomaTasks<CR>",
      vim.tbl_extend("force", o, { desc = "Autonoma: task list" }))
  end
end

return M
