-- :checkhealth a6s entry point
return require("a6s").check and {
  check = function() require("a6s").check() end,
} or { check = function() end }
