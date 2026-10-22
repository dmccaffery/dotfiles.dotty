-- Copyright 2026 BitWise Media Group Ltd
-- SPDX-License-Identifier: MIT

-- Point markdownlint-cli2 at `.mise/markdownlint-cli2.*` when the repository
-- root carries no markdownlint config of its own. See `util.mise`.

local mise = require("util.mise")

-- https://github.com/DavidAnson/markdownlint-cli2#configuration
local config_names = {
  ".markdownlint-cli2.jsonc",
  ".markdownlint-cli2.yaml",
  ".markdownlint-cli2.cjs",
  ".markdownlint-cli2.mjs",
  ".markdownlint.jsonc",
  ".markdownlint.json",
  ".markdownlint.yaml",
  ".markdownlint.yml",
  ".markdownlint.cjs",
  ".markdownlint.mjs",
  "package.json",
}

--- `package.json` only counts when it carries a `markdownlint-cli2` key.
---@param path string
---@return boolean
local function is_config(path)
  if vim.fs.basename(path) ~= "package.json" then
    return true
  end
  local text = mise.read(path)
  return text ~= nil and text:find('"markdownlint%-cli2"%s*:') ~= nil
end

return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "mmdc" } },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          -- markdownlint-cli2 stops its own config walk at the working
          -- directory, so run it from the repository root.
          cwd = function(_, ctx)
            return mise.root(ctx.dirname)
          end,
          prepend_args = function(_, ctx)
            return mise.config_args(ctx.dirname, config_names, is_config)
          end,
        },
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        -- A function linter is re-evaluated on every run, so the config lookup
        -- tracks whichever buffer is being linted.
        ["markdownlint-cli2"] = function()
          local linter = vim.deepcopy(require("lint.linters.markdownlint-cli2"))
          local dirname = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
          local found = mise.find(dirname, config_names, is_config)
          if found and found.fallback then
            linter.cwd = found.root
            linter.args = { "--config", found.path, "-" }
          elseif found then
            -- The linter reads the buffer over stdin, which markdownlint-cli2
            -- treats as a file in its working directory, so run it where the
            -- config was found for that config to apply.
            linter.cwd = vim.fs.dirname(found.path)
          end
          return linter
        end,
      },
    },
  },
}
