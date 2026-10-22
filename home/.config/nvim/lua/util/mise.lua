-- Copyright 2026 BitWise Media Group Ltd
-- SPDX-License-Identifier: MIT

-- Locate tool configuration for the repository that owns a buffer.
--
-- Tools such as prettier and markdownlint-cli2 walk up from the file being
-- processed looking for their own config files. Some repositories keep those
-- files out of the root and under `.mise/` instead; this module finds a
-- repository-level config first and, only when none exists, falls back to the
-- `.mise/` copy so callers can pass it explicitly (`--config <path>`).

local M = {}

--- Directory, relative to the repository root, that holds fallback configs.
M.dir = ".mise"

--- Repository root for `path`: the nearest ancestor containing a `.git` entry
--- (directory or worktree file), or the current working directory.
---@param path string
---@return string
function M.root(path)
  return vim.fs.root(path, ".git") or vim.fn.getcwd()
end

--- Read a whole file, or return nil when it cannot be opened.
---@param path string
---@return string|nil
function M.read(path)
  local file = io.open(path, "r")
  if not file then
    return nil
  end
  local text = file:read("*a")
  file:close()
  return text
end

---@class util.mise.Config
---@field path string absolute path to the config file
---@field root string repository root the search ran in
---@field fallback boolean true when the file came from the `.mise/` directory

--- Find a tool config for the buffer that lives in `dirname`.
---
--- The repository is searched first, from `dirname` up to the repository
--- root, which mirrors how the tools discover their own config. When nothing
--- is found there, `<root>/.mise/` is checked for the same names, with and
--- without the leading dot (`.mise/.prettierrc.yaml`, `.mise/prettierrc.yaml`).
---
---@param dirname string|nil directory of the buffer being formatted or linted
---@param names string[] config file names the tool recognises
---@param is_match? fun(path: string): boolean extra check for a candidate, e.g. `package.json` only counts when it has the tool's key
---@return util.mise.Config|nil
function M.find(dirname, names, is_match)
  if dirname == nil or dirname == "" then
    return nil
  end

  local root = M.root(dirname)
  local function accept(path)
    return is_match == nil or is_match(path)
  end

  local in_repo = vim.fs.find(function(name, path)
    return vim.tbl_contains(names, name) and accept(vim.fs.joinpath(path, name))
  end, { path = dirname, upward = true, stop = vim.fs.dirname(root), type = "file" })[1]
  if in_repo then
    return { path = in_repo, root = root, fallback = false }
  end

  local dir = vim.fs.joinpath(root, M.dir)
  for _, name in ipairs(names) do
    local undotted = name:gsub("^%.", "")
    for _, candidate in ipairs(name == undotted and { name } or { name, undotted }) do
      local path = vim.fs.joinpath(dir, candidate)
      local stat = vim.uv.fs_stat(path)
      if stat and stat.type == "file" and accept(path) then
        return { path = path, root = root, fallback = true }
      end
    end
  end

  return nil
end

--- Extra command-line arguments that point a tool at its `.mise/` fallback
--- config, or an empty list when the repository already provides one (or none
--- exists at all, in which case the tool's own defaults apply).
---@param dirname string|nil
---@param names string[]
---@param is_match? fun(path: string): boolean
---@return string[]
function M.config_args(dirname, names, is_match)
  local found = M.find(dirname, names, is_match)
  if found and found.fallback then
    return { "--config", found.path }
  end
  return {}
end

return M
