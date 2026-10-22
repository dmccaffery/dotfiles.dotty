-- Copyright 2026 BitWise Media Group Ltd
-- SPDX-License-Identifier: MIT

-- Point prettier at `.mise/.prettierrc*` when the repository root carries no
-- prettier config of its own. See `util.mise`.

local mise = require("util.mise")

-- https://prettier.io/docs/configuration
local config_names = {
  "package.json",
  "package.yaml",
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.yml",
  ".prettierrc.yaml",
  ".prettierrc.json5",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  ".prettierrc.ts",
  ".prettierrc.cts",
  ".prettierrc.mts",
  ".prettierrc.toml",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
  "prettier.config.ts",
  "prettier.config.cts",
  "prettier.config.mts",
}

--- `package.json` / `package.yaml` only count when they carry a `prettier` key.
---@param path string
---@return boolean
local function is_config(path)
  local name = vim.fs.basename(path)
  if name == "package.json" then
    local text = mise.read(path)
    return text ~= nil and text:find('"prettier"%s*:') ~= nil
  elseif name == "package.yaml" then
    local text = mise.read(path)
    return text ~= nil and (text:find("^prettier%s*:") ~= nil or text:find("\nprettier%s*:") ~= nil)
  end
  return true
end

return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        prettier = {
          prepend_args = function(_, ctx)
            return mise.config_args(ctx.dirname, config_names, is_config)
          end,
        },
      },
    },
  },
}
