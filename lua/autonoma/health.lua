-- :checkhealth autonoma entry point
return require("autonoma").check and {
  check = function() require("autonoma").check() end,
} or { check = function() end }
