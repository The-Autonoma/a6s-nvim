std = "lua51+luajit"
globals = { "vim", "bit" }
read_globals = { "describe", "it", "before_each", "after_each", "assert" }
max_line_length = false
ignore = {
  "212", -- unused argument
  "213", -- unused loop variable
  "631", -- line is too long
}
exclude_files = { "tests/minimal_init.lua" }
