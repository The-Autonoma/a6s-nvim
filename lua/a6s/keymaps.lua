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
    vim.keymap.set("n", keys.invoke, "<cmd>A6sInvoke<CR>",
      vim.tbl_extend("force", o, { desc = "A6s: invoke agent" }))
  end
  if keys.explain then
    vim.keymap.set("v", keys.explain, "<cmd>A6sExplain<CR>",
      vim.tbl_extend("force", o, { desc = "A6s: explain selection" }))
  end
  if keys.refactor then
    vim.keymap.set("v", keys.refactor, "<cmd>A6sRefactor<CR>",
      vim.tbl_extend("force", o, { desc = "A6s: refactor selection" }))
  end
  if keys.review then
    vim.keymap.set("v", keys.review, "<cmd>A6sReview<CR>",
      vim.tbl_extend("force", o, { desc = "A6s: review selection" }))
  end
  if keys.tests then
    vim.keymap.set("v", keys.tests, "<cmd>A6sGenerateTests<CR>",
      vim.tbl_extend("force", o, { desc = "A6s: generate tests" }))
  end
  if keys.tasks then
    vim.keymap.set("n", keys.tasks, "<cmd>A6sTasks<CR>",
      vim.tbl_extend("force", o, { desc = "A6s: task list" }))
  end
end

return M
