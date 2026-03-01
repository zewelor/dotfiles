-- Dockerfile specific settings
-- Align RUN commands by using 4 spaces for indentation (matching 'RUN ')
--

-- ~/.config/nvim/after/indent/dockerfile.lua

vim.opt_local.expandtab = true
vim.opt_local.tabstop = 4
vim.opt_local.softtabstop = 4
vim.opt_local.shiftwidth = 4

vim.opt_local.autoindent = true
vim.opt_local.smartindent = false
vim.opt_local.cindent = false

local DEFAULT_INDENTEXPR = vim.bo.indentexpr
local RUN_CONT = 4 -- kolejne linie po "RUN ... \" mają 4 spacje
local SHELL_NEST = 2 -- wnętrze then/do/case ma +2 spacje

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function strip_cont(s)
	-- usuń końcowe "\" z ewentualnymi spacjami
	return trim((s:gsub("\\%s*$", "")))
end

local function ends_with_backslash(s)
	return s:match("\\%s*$") ~= nil
end

local function prev_nonblank(lnum)
	return vim.fn.prevnonblank(lnum)
end

local function find_run_start(lnum)
	-- szukamy po poprzednich liniach, bo bieżąca może być jeszcze pusta
	local i = prev_nonblank(lnum - 1)
	while i > 0 do
		local line = vim.fn.getline(i)
		if line:match("^%s*RUN%s+") then
			if ends_with_backslash(line) then
				return i
			end
			return nil
		end
		if not ends_with_backslash(line) then
			return nil
		end
		i = prev_nonblank(i - 1)
	end
	return nil
end

local function nearest_case_idx(stack)
	for i = #stack, 1, -1 do
		if stack[i].kind == "case" then
			return i
		end
	end
	return nil
end

local function pop_kind(stack, kind)
	for i = #stack, 1, -1 do
		if stack[i].kind == kind then
			table.remove(stack, i)
			return
		end
	end
end

local function active_case_arms(stack)
	local n = 0
	for _, frame in ipairs(stack) do
		if frame.kind == "case" and frame.in_arm then
			n = n + 1
		end
	end
	return n
end

local function is_case_open(line)
	return line:match("^case%s+.+%s+in%s*;?$") ~= nil
end

local function is_case_close(line)
	return line:match("^esac%s*;?$") ~= nil
end

local function is_block_open(line)
	if line:match("^elif%s+.+;%s*then%s*;?$") then
		return false
	end
	if line:match("^else%s*;?$") then
		return false
	end
	return line:match("then%s*;?$") ~= nil or line:match("do%s*;?$") ~= nil
end

local function is_block_close(line)
	return line:match("^fi%s*;?$") ~= nil or line:match("^done%s*;?$") ~= nil
end

local function is_else_like(line)
	return line:match("^else%s*;?$") ~= nil or line:match("^elif%s+.+;%s*then%s*;?$") ~= nil
end

local function is_case_break(line)
	return line:match("^;;%s*$") ~= nil or line:match("^;&%s*$") ~= nil or line:match("^;;&%s*$") ~= nil
end

local function is_case_label(line, stack)
	if not nearest_case_idx(stack) then
		return false
	end

	if line:match("^(case|if|elif|else|fi|for|while|until|do|done|esac)%f[%A]") then
		return false
	end

	-- prosta heurystyka: "foo)", "foo|bar)", "*)", "*.deb)" itd.
	return line:match("^[^%s].-%)%s*;?$") ~= nil
end

local function default_indentexpr_value()
	if DEFAULT_INDENTEXPR ~= "" and DEFAULT_INDENTEXPR ~= "v:lua.DockerfileRunIndent()" then
		local ok, value = pcall(vim.fn.eval, DEFAULT_INDENTEXPR)
		if ok then
			local n = tonumber(value)
			if n then
				return n
			end
		end
	end
	return -1
end

function _G.DockerfileRunIndent()
	local lnum = vim.v.lnum
	local run_start = find_run_start(lnum)
	local cur = trim(vim.fn.getline(lnum))

	if not run_start then
		if cur:match("^#") then
			return 0
		end
		return default_indentexpr_value()
	end

	local base_indent = vim.fn.indent(run_start) + RUN_CONT
	local prev = prev_nonblank(lnum - 1)
	local stack = {}

	-- Zbuduj kontekst z poprzednich linii RUN-a
	if prev >= run_start + 1 then
		for i = run_start + 1, prev do
			local line = strip_cont(vim.fn.getline(i))
			if line ~= "" then
				if is_block_close(line) then
					pop_kind(stack, "block")
				elseif is_case_close(line) then
					pop_kind(stack, "case")
				elseif is_else_like(line) then
				-- zamyka i otwiera ten sam poziom => netto bez zmian
				elseif is_case_break(line) then
					local idx = nearest_case_idx(stack)
					if idx then
						stack[idx].in_arm = false
					end
				elseif is_case_label(line, stack) then
					local idx = nearest_case_idx(stack)
					if idx then
						stack[idx].in_arm = true
					end
				elseif is_case_open(line) then
					table.insert(stack, { kind = "case", in_arm = false })
				elseif is_block_open(line) then
					table.insert(stack, { kind = "block" })
				end
			end
		end
	end

	cur = strip_cont(vim.fn.getline(lnum))
	local indent = base_indent + (#stack * SHELL_NEST) + (active_case_arms(stack) * SHELL_NEST)

	-- dedent bieżącej linii, jeśli sama jest "zamykająca"
	if is_block_close(cur) or is_else_like(cur) then
		indent = indent - SHELL_NEST
	elseif is_case_close(cur) then
		indent = indent - SHELL_NEST
		local idx = nearest_case_idx(stack)
		if idx and stack[idx].in_arm then
			indent = indent - SHELL_NEST
		end
	elseif is_case_label(cur, stack) then
		local idx = nearest_case_idx(stack)
		if idx and stack[idx].in_arm then
			indent = indent - SHELL_NEST
		end
	end

	return math.max(indent, 0)
end

vim.bo.indentexpr = "v:lua.DockerfileRunIndent()"

-- przy indentexpr to 'indentkeys' steruje kiedy przeliczać wcięcie
vim.bo.indentkeys = "o,O,*<Return>,0=fi,0=done,0=esac,0=else,0=elif"
