-- LSP Context Extractor for Enhanced AI Prompts
-- Efficiently gathers and filters LSP information for AI context

local M = {}

-- Cache for LSP responses to avoid repeated expensive operations
local lsp_cache = {}
local cache_ttl = 5000 -- 5 seconds

---@class LSPContext
---@field symbol_info table|nil
---@field hover_info table|nil  
---@field diagnostics table[]
---@field references table[]|nil
---@field signature_help table|nil
---@field completion_context table|nil
---@field workspace_symbols table[]|nil

---@class ContextConfig
---@field include_hover boolean
---@field include_diagnostics boolean
---@field include_references boolean
---@field include_signature boolean
---@field include_completion boolean
---@field include_workspace_symbols boolean
---@field max_references number
---@field max_diagnostics number
---@field max_workspace_symbols number

-- Default configuration for context extraction
M.default_config = {
  include_hover = true,
  include_diagnostics = true,
  include_references = true,
  include_signature = true,
  include_completion = false, -- Can be expensive
  include_workspace_symbols = false, -- Can be very large
  max_references = 10,
  max_diagnostics = 5,
  max_workspace_symbols = 20,
  cache_ttl = 5000,
}

-- Cache management
local function get_cache_key(method, params)
  return method .. ":" .. vim.json.encode(params or {})
end

local function is_cache_valid(cache_entry)
  return cache_entry and (vim.loop.hrtime() - cache_entry.timestamp) < (M.config.cache_ttl * 1000000)
end

local function cache_set(key, value)
  lsp_cache[key] = {
    value = value,
    timestamp = vim.loop.hrtime()
  }
end

local function cache_get(key)
  local entry = lsp_cache[key]
  if is_cache_valid(entry) then
    return entry.value
  end
  return nil
end

-- Async LSP request with caching
local function async_lsp_request(method, params, callback)
  local cache_key = get_cache_key(method, params)
  local cached = cache_get(cache_key)
  
  if cached then
    callback(nil, cached)
    return
  end
  
  local clients = vim.lsp.get_active_clients()
  if #clients == 0 then
    callback("No active LSP clients", nil)
    return
  end
  
  -- Use first available client that supports the method
  for _, client in ipairs(clients) do
    if client.server_capabilities[method] then
      client.request(method, params, function(err, result)
        if not err and result then
          cache_set(cache_key, result)
        end
        callback(err, result)
      end)
      return
    end
  end
  
  callback("No client supports " .. method, nil)
end

-- Get hover information at current cursor position
function M.get_hover_info(bufnr, position, callback)
  if not M.config.include_hover then
    callback(nil, nil)
    return
  end
  
  local params = vim.lsp.util.make_position_params()
  async_lsp_request("textDocument/hover", params, callback)
end

-- Get diagnostics for current buffer
function M.get_diagnostics(bufnr, callback)
  if not M.config.include_diagnostics then
    callback(nil, {})
    return
  end
  
  local diagnostics = vim.diagnostic.get(bufnr)
  
  -- Filter and limit diagnostics
  local filtered = {}
  local count = 0
  
  -- Prioritize errors, then warnings, then hints
  local priority_order = {
    [vim.diagnostic.severity.ERROR] = 1,
    [vim.diagnostic.severity.WARN] = 2,
    [vim.diagnostic.severity.INFO] = 3,
    [vim.diagnostic.severity.HINT] = 4,
  }
  
  table.sort(diagnostics, function(a, b)
    return priority_order[a.severity] < priority_order[b.severity]
  end)
  
  for _, diagnostic in ipairs(diagnostics) do
    if count >= M.config.max_diagnostics then break end
    
    table.insert(filtered, {
      severity = diagnostic.severity,
      message = diagnostic.message,
      source = diagnostic.source,
      range = diagnostic.range,
      code = diagnostic.code,
    })
    count = count + 1
  end
  
  callback(nil, filtered)
end

-- Get references for symbol at cursor
function M.get_references(bufnr, position, callback)
  if not M.config.include_references then
    callback(nil, nil)
    return
  end
  
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }
  
  async_lsp_request("textDocument/references", params, function(err, references)
    if err or not references then
      callback(err, nil)
      return
    end
    
    -- Limit and process references
    local limited_refs = {}
    for i = 1, math.min(#references, M.config.max_references) do
      local ref = references[i]
      table.insert(limited_refs, {
        uri = ref.uri,
        range = ref.range,
        -- Add context around the reference
        context = M.get_reference_context(ref)
      })
    end
    
    callback(nil, limited_refs)
  end)
end

-- Get signature help at cursor position
function M.get_signature_help(bufnr, position, callback)
  if not M.config.include_signature then
    callback(nil, nil)
    return
  end
  
  local params = vim.lsp.util.make_position_params()
  async_lsp_request("textDocument/signatureHelp", params, callback)
end

-- Get workspace symbols relevant to current context
function M.get_workspace_symbols(query, callback)
  if not M.config.include_workspace_symbols then
    callback(nil, nil)
    return
  end
  
  local params = { query = query or "" }
  async_lsp_request("workspace/symbol", params, function(err, symbols)
    if err or not symbols then
      callback(err, nil)
      return
    end
    
    -- Limit and filter workspace symbols
    local filtered = {}
    local count = 0
    
    for _, symbol in ipairs(symbols) do
      if count >= M.config.max_workspace_symbols then break end
      
      -- Filter by relevance (could be more sophisticated)
      if query and query ~= "" then
        if symbol.name:lower():find(query:lower(), 1, true) then
          table.insert(filtered, symbol)
          count = count + 1
        end
      else
        table.insert(filtered, symbol)
        count = count + 1
      end
    end
    
    callback(nil, filtered)
  end)
end

-- Get context around a reference location
function M.get_reference_context(reference)
  local uri = reference.uri
  local range = reference.range
  
  -- Try to get a few lines around the reference
  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    return nil
  end
  
  local start_line = math.max(0, range.start.line - 1)
  local end_line = math.min(vim.api.nvim_buf_line_count(bufnr) - 1, range["end"].line + 1)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line + 1, false)
  return table.concat(lines, "\n")
end

-- Main function to gather comprehensive LSP context
function M.get_comprehensive_context(bufnr, position, config, callback)
  M.config = vim.tbl_deep_extend("force", M.default_config, config or {})
  
  local context = {}
  local pending_requests = 0
  local completed_requests = 0
  
  local function check_completion()
    completed_requests = completed_requests + 1
    if completed_requests >= pending_requests then
      callback(nil, context)
    end
  end
  
  -- Helper to start an async request
  local function start_request(fn, ...)
    pending_requests = pending_requests + 1
    fn(...)
  end
  
  -- Gather hover information
  start_request(M.get_hover_info, bufnr, position, function(err, hover)
    context.hover_info = hover
    check_completion()
  end)
  
  -- Gather diagnostics
  start_request(M.get_diagnostics, bufnr, function(err, diagnostics)
    context.diagnostics = diagnostics or {}
    check_completion()
  end)
  
  -- Gather references
  start_request(M.get_references, bufnr, position, function(err, references)
    context.references = references
    check_completion()
  end)
  
  -- Gather signature help
  start_request(M.get_signature_help, bufnr, position, function(err, signature)
    context.signature_help = signature
    check_completion()
  end)
  
  -- If no requests were started, return empty context
  if pending_requests == 0 then
    callback(nil, context)
  end
end

-- Enhanced context specifically for cursor position
function M.get_cursor_context(callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local position = vim.api.nvim_win_get_cursor(0)
  local lsp_position = {
    line = position[1] - 1, -- LSP is 0-indexed
    character = position[2]
  }
  
  M.get_comprehensive_context(bufnr, lsp_position, M.default_config, callback)
end

-- Format LSP context for AI prompts
function M.format_context_for_prompt(context)
  local formatted = {}
  
  if context.hover_info and context.hover_info.contents then
    table.insert(formatted, "## Symbol Information")
    table.insert(formatted, "```")
    if type(context.hover_info.contents) == "string" then
      table.insert(formatted, context.hover_info.contents)
    elseif type(context.hover_info.contents) == "table" then
      for _, content in ipairs(context.hover_info.contents) do
        if type(content) == "string" then
          table.insert(formatted, content)
        elseif content.value then
          table.insert(formatted, content.value)
        end
      end
    end
    table.insert(formatted, "```")
  end
  
  if context.signature_help and context.signature_help.signatures then
    table.insert(formatted, "## Function Signatures")
    for _, sig in ipairs(context.signature_help.signatures) do
      table.insert(formatted, "- " .. sig.label)
      if sig.documentation then
        table.insert(formatted, "  " .. sig.documentation)
      end
    end
  end
  
  if context.diagnostics and #context.diagnostics > 0 then
    table.insert(formatted, "## Current Issues")
    for _, diag in ipairs(context.diagnostics) do
      local severity = {"ERROR", "WARN", "INFO", "HINT"}[diag.severity] or "UNKNOWN"
      table.insert(formatted, string.format("- %s: %s", severity, diag.message))
      if diag.source then
        table.insert(formatted, string.format("  Source: %s", diag.source))
      end
    end
  end
  
  if context.references and #context.references > 0 then
    table.insert(formatted, "## References")
    table.insert(formatted, string.format("Found %d references to this symbol", #context.references))
  end
  
  return table.concat(formatted, "\n")
end

-- Integration point for enhanced WCA commands
function M.enhance_wca_prompt(base_prompt, callback)
  M.get_cursor_context(function(err, context)
    if err or not context then
      callback(base_prompt) -- Fallback to base prompt
      return
    end
    
    local enhanced_prompt = base_prompt .. "\n\n" .. M.format_context_for_prompt(context)
    callback(enhanced_prompt)
  end)
end

return M