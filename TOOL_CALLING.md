# Tool Calling in Avante.nvim

This document provides a comprehensive guide to tool calling implementation in Avante.nvim, covering architecture, setup, custom tool development, and how LLMs understand and execute tools.

## Table of Contents

- [How Tool Calling is Implemented](#how-tool-calling-is-implemented)
- [How LLMs Know About Tool Schemas](#how-llms-know-about-tool-schemas)
- [How to Set Up Tool Calling](#how-to-set-up-tool-calling)
- [How to Add Custom Tools](#how-to-add-custom-tools)
- [Tool Execution and Result Handling](#tool-execution-and-result-handling)

## How Tool Calling is Implemented

### Architecture Overview

The tool calling system consists of several key components:

1. **Tool Definition Layer** (`lua/avante/llm_tools/`): Individual tool modules with standardized interfaces
2. **Tool Registry** (`lua/avante/llm_tools/init.lua`): Central registry for loading and managing tools
3. **Schema Translation Layer** (`lua/avante/providers/`): Provider-specific tool schema conversion
4. **Execution Engine** (`lua/avante/llm_tools/helpers.lua`): Tool execution with permission control and error handling
5. **UI Integration** (`lua/avante/sidebar.lua`): Tool result rendering and user interaction

### Core Tool Structure

Each tool follows a standardized pattern:

```lua
-- Example: lua/avante/llm_tools/example.lua
local Base = require("avante.llm_tools.base")

---@class AvanteLLMTool
local M = setmetatable({}, Base)

M.name = "tool_name"  -- Unique identifier for the tool

M.description = "Tool description for the LLM"  -- Or M.get_description() function

-- Optional: Enable/disable based on conditions
M.enabled = function(opts) 
  return require("avante.config").mode == "agentic" 
end

-- Tool parameters schema
M.param = {
  type = "table",
  fields = {
    {
      name = "parameter_name",
      description = "Parameter description",
      type = "string",  -- string, number, boolean, array, object
      optional = false,  -- Whether parameter is required
    },
  },
}

-- Expected return values
M.returns = {
  {
    name = "result",
    description = "Description of return value",
    type = "string",
    optional = false,
  },
}

-- Main execution function
---@type AvanteLLMToolFunc<{parameter_name: string}>
function M.func(input, opts)
  -- Tool implementation
  local on_complete = opts.on_complete
  local result = "tool result"
  if on_complete then
    on_complete(result, nil)  -- (result, error)
  end
  return result, nil
end

return M
```

### Built-in Tool Categories

**File System Tools:**
- `view` - Read file contents with truncation support
- `create` - Create new files
- `str_replace` - Replace text in files
- `ls` - List directory contents
- `glob` - Pattern-based file matching
- `grep` - Search file contents

**Execution Tools:**
- `bash` - Execute shell commands with security controls
- `python` - Run Python code snippets

**Navigation Tools:**
- `go_to_line` - Navigate to specific line numbers

**Workflow Tools:**
- `think` - LLM reasoning and planning
- `attempt_completion` - Mark task completion
- `rag_search` - Search knowledge base (when RAG enabled)

**Context Tools:**
- `add_file_to_context` - Add files to conversation context
- `remove_file_from_context` - Remove files from context

### Tool Permission System

Tools implement a comprehensive permission system:

```lua
-- From helpers.lua:28
function M.confirm(message, callback, confirm_opts, session_ctx, tool_name)
  -- Auto-approval logic
  local Config = require("avante.config")
  local auto_approve = Config.behaviour.auto_approve_tool_permissions
  
  -- If auto_approve is true, auto-approve all tools
  if auto_approve == true then
    callback(true)
    return
  end
  
  -- If auto_approve is a table, check if this tool is in the list
  if type(auto_approve) == "table" and vim.tbl_contains(auto_approve, tool_name) then
    callback(true)
    return
  end
  
  -- Show confirmation dialog
end
```

**Security Features:**
- File system access restricted to project root and config directories
- Git ignore pattern respect for file operations
- Command blacklisting for bash tool
- User confirmation prompts with "yes/no/all" options
- Permission caching per session

## How LLMs Know About Tool Schemas

### Schema Conversion Pipeline

The system dynamically converts tool definitions into provider-specific schemas:

**1. Tool Parameter Schema Generation** (`utils/init.lua:1490`):
```lua
function M.llm_tool_param_fields_to_json_schema(fields)
  local properties = {}
  local required = {}
  
  for _, field in ipairs(fields) do
    if field.type == "object" and field.fields then
      -- Recursive object handling
      local properties_, required_ = M.llm_tool_param_fields_to_json_schema(field.fields)
      properties[field.name] = {
        type = field.type,
        description = field.description,
        properties = properties_,
        required = required_,
      }
    elseif field.type == "array" and field.items then
      -- Array type handling
      properties[field.name] = {
        type = field.type,
        description = field.description,
        items = converted_item_schema,
      }
    else
      -- Primitive types
      properties[field.name] = {
        type = field.type,
        description = field.description,
      }
      if field.choices then 
        properties[field.name].enum = field.choices 
      end
    end
    
    if not field.optional then 
      table.insert(required, field.name) 
    end
  end
  
  return properties, required
end
```

**2. Provider-Specific Transformation:**

**Claude Format** (`providers/claude.lua:38`):
```lua
function M:transform_tool(tool)
  local input_schema_properties, required = Utils.llm_tool_param_fields_to_json_schema(tool.param.fields)
  return {
    name = tool.name,
    description = tool.get_description and tool.get_description() or tool.description,
    input_schema = {
      type = "object",
      properties = input_schema_properties,
      required = required,
    },
  }
end
```

**OpenAI Format** (`providers/openai.lua:25`):
```lua
function M:transform_tool(tool)
  local input_schema_properties, required = Utils.llm_tool_param_fields_to_json_schema(tool.param.fields)
  local parameters = nil
  if not vim.tbl_isempty(input_schema_properties) then
    parameters = {
      type = "object",
      properties = input_schema_properties,
      required = required,
      additionalProperties = false,
    }
  end
  return {
    type = "function",
    ["function"] = {
      name = tool.name,
      description = tool.description,
      parameters = parameters,
    },
  }
end
```

**Gemini Format** (`providers/gemini.lua:19`):
```lua
function M:transform_tool(tool)
  local input_schema_properties, required = Utils.llm_tool_param_fields_to_json_schema(tool.param.fields)
  return {
    name = tool.name,
    description = tool.description,
    parameters = {
      type = "OBJECT",
      properties = convert_to_gemini_format(input_schema_properties),
      required = required,
    },
  }
end
```

### Dynamic Tool Loading

Tools are dynamically loaded and filtered:

```lua
-- From llm_tools/init.lua:606
function M.get_tools(user_input, history_messages)
  local tools = {}
  
  -- Load all built-in tools
  for tool_name in pairs(tool_modules) do
    local tool = require("avante.llm_tools." .. tool_name)
    if tool.enabled == nil or tool.enabled({ 
      user_input = user_input, 
      history_messages = history_messages 
    }) then
      table.insert(tools, tool)
    end
  end
  
  -- Add custom tools from config
  local Config = require("avante.config")
  if Config.custom_tools then
    for _, custom_tool in ipairs(Config.custom_tools) do
      table.insert(tools, custom_tool)
    end
  end
  
  -- Filter out disabled tools
  tools = vim.tbl_filter(function(tool)
    return not vim.tbl_contains(Config.disabled_tools, tool.name)
  end, tools)
  
  return tools
end
```

### Tool Guidelines Integration

The system includes comprehensive tool usage guidelines in `templates/_tools-guidelines.avanterules`:

```
TOOLS USAGE GUIDE

- You have access to tools, but only use them when necessary
- Please DON'T be so aggressive in using tools
- Files will be provided to you as context through <file> tag
- You should make good use of the `thinking` tool for complex tasks
- Before using the `view` tool each time, check if the file is in <file> tag
- If the `rag_search` tool exists, prioritize using it
- Keep the `query` parameter of `rag_search` tool concise (within five words)
- When attempting to modify files not in context, use `ls` and `glob` first
- When generating files, first use `ls` to read directory structure
- After `web_search`, use `fetch` tool for detailed information
- Use `run_python` for mathematical calculations
- Do not use tools to read/modify files when other options exist
```

## How to Set Up Tool Calling

### 1. Basic Configuration

Tool calling is controlled through the main Avante configuration:

```lua
require('avante').setup({
  -- Tool calling is enabled by default
  -- Most tools work in any mode, but some require "agentic" mode
  
  behaviour = {
    -- Auto-approve tool permissions (optional)
    auto_approve_tool_permissions = false,  -- or true, or {"tool1", "tool2"}
    
    -- Enable fast apply mode (disables some tools)
    enable_fastapply = false,
  },
  
  -- Disable specific tools while keeping others enabled
  disabled_tools = {}, -- e.g., {"bash", "python", "create"}
  
  -- Add custom tools (see custom tools section)
  custom_tools = {},
})
```

### 2. Mode-Specific Tool Availability

**Planning Mode** (default):
- Most tools available: `view`, `ls`, `glob`, `grep`, `think`
- File modification tools available: `str_replace`
- Limited execution tools

**Agentic Mode**:
- All tools available including: `bash`, `python`, `create`, `attempt_completion`
- Full autonomous operation capabilities
- Enhanced permission system

**To enable agentic mode:**
```lua
require('avante').setup({
  mode = "agentic",  -- Enable full tool access
})
```

### 3. Permission Configuration

**Auto-approve all tools:**
```lua
behaviour = {
  auto_approve_tool_permissions = true,
}
```

**Auto-approve specific tools:**
```lua
behaviour = {
  auto_approve_tool_permissions = {"view", "ls", "glob", "grep", "think"},
}
```

**Manual approval (default):**
```lua
behaviour = {
  auto_approve_tool_permissions = false,  -- User confirmation required
}
```

### 4. Tool-Specific Configuration

Some tools have additional configuration options:

**Bash tool security:**
- Automatic command blacklisting: `curl`, `wget`, `nc`, `telnet`, browsers
- Working directory restrictions
- Timeout controls (default: 30 minutes)

**View tool limits:**
- File size truncation at ~200KB
- Automatic chunking for large files
- Support for line range viewing

**Python tool environment:**
- Isolated execution environment
- Import restrictions for security
- Result formatting controls

### 5. Provider-Specific Setup

**Claude/Anthropic:**
- Native tool calling support
- Full schema conversion
- Streaming tool execution

**OpenAI:**
- Function calling format
- Support for reasoning models (o1, o3)
- ReAct prompt mode available

**Local Models (Ollama):**
- Tool calling depends on model capabilities
- ReAct format for models without native tool support
- Custom prompt templates

## How to Add Custom Tools

### 1. Simple Command-Based Tools

For tools that execute shell commands, use the simplified format:

```lua
require('avante').setup({
  custom_tools = {
    {
      name = "run_tests",
      description = "Run project tests and return results",
      command = "npm test",  -- Shell command to execute
      param = {
        type = "table",
        fields = {
          {
            name = "test_file",
            description = "Specific test file to run (optional)",
            type = "string",
            optional = true,
          },
        },
      },
      returns = {
        {
          name = "result",
          description = "Test execution output",
          type = "string",
        },
        {
          name = "error",
          description = "Error message if tests failed",
          type = "string",
          optional = true,
        },
      },
      func = function(params, on_log, on_complete)
        local test_file = params.test_file or ""
        local command = test_file ~= "" and ("npm test " .. test_file) or "npm test"
        
        if on_log then on_log("Running: " .. command) end
        
        local result = vim.fn.system(command)
        local exit_code = vim.v.shell_error
        
        if exit_code == 0 then
          return result  -- Success
        else
          return false, "Tests failed: " .. result  -- Error
        end
      end,
    },
  },
})
```

### 2. Advanced Custom Tools

For more complex functionality, create full tool modules:

```lua
-- Custom API integration tool
{
  name = "fetch_api_data",
  description = "Fetch data from REST API endpoints",
  
  enabled = function(opts)
    -- Only enable if API key is configured
    return os.getenv("API_KEY") ~= nil
  end,
  
  param = {
    type = "table",
    fields = {
      {
        name = "url",
        description = "API endpoint URL",
        type = "string",
      },
      {
        name = "method",
        description = "HTTP method",
        type = "string",
        choices = {"GET", "POST", "PUT", "DELETE"},
        optional = true,
      },
      {
        name = "headers",
        description = "Request headers",
        type = "object",
        fields = {
          {
            name = "content_type",
            description = "Content-Type header",
            type = "string",
            optional = true,
          },
        },
        optional = true,
      },
      {
        name = "body",
        description = "Request body (for POST/PUT)",
        type = "string",
        optional = true,
      },
    },
  },
  
  returns = {
    {
      name = "data",
      description = "API response data",
      type = "string",
    },
    {
      name = "status",
      description = "HTTP status code",
      type = "number",
    },
    {
      name = "error",
      description = "Error message if request failed",
      type = "string",
      optional = true,
    },
  },
  
  func = function(input, opts)
    local curl = require("plenary.curl")
    local on_complete = opts.on_complete
    local on_log = opts.on_log
    
    if on_log then on_log("Fetching: " .. input.url) end
    
    local curl_opts = {
      url = input.url,
      method = input.method or "GET",
      headers = input.headers or {},
      body = input.body,
      timeout = 30000,  -- 30 seconds
    }
    
    -- Add authentication
    if os.getenv("API_KEY") then
      curl_opts.headers.Authorization = "Bearer " .. os.getenv("API_KEY")
    end
    
    if on_complete then
      -- Async execution
      curl.request(curl_opts, function(response)
        if response.status == 200 then
          on_complete({
            data = response.body,
            status = response.status
          }, nil)
        else
          on_complete(false, "API request failed: " .. response.status)
        end
      end)
    else
      -- Sync execution
      local response = curl.request(curl_opts)
      if response.status == 200 then
        return {
          data = response.body,
          status = response.status
        }, nil
      else
        return false, "API request failed: " .. response.status
      end
    end
  end,
},
```

### 3. Tool with UI Integration

Tools can provide custom rendering for their output:

```lua
{
  name = "system_info",
  description = "Get system information and display formatted output",
  
  param = {
    type = "table",
    fields = {
      {
        name = "detailed",
        description = "Include detailed system information",
        type = "boolean",
        optional = true,
      },
    },
  },
  
  -- Custom rendering function
  on_render = function(input, opts)
    local Line = require("avante.ui.line")
    local Highlights = require("avante.highlights")
    
    local lines = {}
    table.insert(lines, Line:new({{"🖥️  System Information", Highlights.AVANTE_TITLE}}))
    table.insert(lines, Line:new({{""}})
    
    -- Parse and format system info
    local info = vim.split(input.result or "", "\n")
    for _, line in ipairs(info) do
      table.insert(lines, Line:new({{"> " .. line}}))
    end
    
    return lines
  end,
  
  func = function(input, opts)
    local detailed = input.detailed or false
    local info = {}
    
    -- Gather system information
    table.insert(info, "OS: " .. vim.loop.os_uname().sysname)
    table.insert(info, "Architecture: " .. vim.loop.os_uname().machine)
    table.insert(info, "Neovim: " .. vim.version().major .. "." .. vim.version().minor)
    
    if detailed then
      table.insert(info, "Memory: " .. vim.fn.system("free -h | grep '^Mem:'"):match("Mem:%s*(%S+)"))
      table.insert(info, "Disk: " .. vim.fn.system("df -h / | tail -1"):match("(%S+%%)"))
    end
    
    local result = table.concat(info, "\n")
    
    if opts.on_complete then
      opts.on_complete({result = result}, nil)
    end
    
    return {result = result}, nil
  end,
},
```

### 4. Dynamic Tool Generation

Tools can be generated dynamically based on project context:

```lua
-- Function that returns tools based on project
custom_tools = function()
  local tools = {}
  
  -- Detect project type and add relevant tools
  local package_json = vim.fn.filereadable("package.json") == 1
  local go_mod = vim.fn.filereadable("go.mod") == 1
  local cargo_toml = vim.fn.filereadable("Cargo.toml") == 1
  
  if package_json then
    table.insert(tools, {
      name = "npm_run",
      description = "Run npm scripts defined in package.json",
      command = "npm run",
      -- ... rest of tool definition
    })
  end
  
  if go_mod then
    table.insert(tools, {
      name = "go_test",
      description = "Run Go tests with coverage",
      command = "go test -cover ./...",
      -- ... rest of tool definition
    })
  end
  
  if cargo_toml then
    table.insert(tools, {
      name = "cargo_check",
      description = "Check Rust code for errors",
      command = "cargo check",
      -- ... rest of tool definition
    })
  end
  
  return tools
end,
```

### 5. Best Practices for Custom Tools

**Security Guidelines:**
- Always validate input parameters
- Use safe command execution methods
- Implement proper error handling
- Restrict file system access appropriately

**Performance Considerations:**
- Use async execution for long-running operations
- Implement timeouts for external calls
- Provide progress feedback via `on_log`
- Cache results when appropriate

**User Experience:**
- Write clear, descriptive tool descriptions
- Provide helpful error messages
- Use progress indicators for long operations
- Implement proper cancellation support

**Integration Guidelines:**
- Follow the established tool interface patterns
- Use consistent parameter naming conventions
- Implement proper streaming support when needed
- Test tools in different modes (planning vs. agentic)

## Tool Execution and Result Handling

### 1. Execution Pipeline

**Tool Call Detection:**
1. LLM generates tool call in provider-specific format
2. Provider parses tool call and extracts tool name + parameters
3. Tool registry looks up tool implementation
4. Permission system checks for user approval

**Tool Execution:**
1. Input validation against parameter schema
2. Tool function execution with context
3. Result capture and error handling
4. UI rendering of tool output

**Result Processing:**
1. Tool results converted to provider format
2. Results added to conversation history
3. LLM receives results for next generation step

### 2. Execution Modes

**Synchronous Execution:**
```lua
function M.func(input, opts)
  -- Direct execution
  local result = perform_operation(input)
  return result, nil  -- (result, error)
end
```

**Asynchronous Execution:**
```lua
function M.func(input, opts)
  local on_complete = opts.on_complete
  
  -- Start async operation
  perform_async_operation(input, function(result, error)
    on_complete(result, error)
  end)
  
  -- Return immediately for async
  return nil
end
```

**Streaming Execution:**
```lua
M.support_streaming = true

function M.func(input, opts)
  local is_streaming = opts.streaming or false
  
  if is_streaming then
    -- Don't execute during streaming, wait for completion
    return
  end
  
  -- Execute when streaming is complete
  local result = perform_operation(input)
  opts.on_complete(result, nil)
end
```

### 3. Error Handling

**Tool-Level Error Handling:**
```lua
function M.func(input, opts)
  -- Validation
  if not input.required_param then
    return false, "required_param is missing"
  end
  
  -- Safe execution
  local success, result = pcall(risky_operation, input)
  if not success then
    return false, "Operation failed: " .. tostring(result)
  end
  
  return result, nil
end
```

**Provider-Level Error Handling:**
- Invalid tool calls result in error messages to LLM
- Permission denials are communicated back as tool results
- Network/system errors are caught and reported

**User-Level Error Handling:**
- Clear error messages displayed in UI
- Retry mechanisms for transient failures
- Graceful degradation when tools unavailable

### 4. Result Formats

**Standard Result Format:**
```lua
-- Success
return result_data, nil

-- Error  
return false, "Error description"

-- Complex result
return {
  data = "main result",
  metadata = {
    timestamp = os.time(),
    source = "tool_name"
  }
}, nil
```

**Provider-Specific Conversion:**
- Claude: `tool_result` content blocks
- OpenAI: `tool` role messages
- Gemini: Function response parts

### 5. Performance Optimizations

**Caching:**
- File content caching for repeated `view` operations
- Command result caching for expensive operations
- Permission decision caching per session

**Batching:**
- Multiple file operations batched when possible
- Bulk grep/glob operations
- Efficient history message processing

**Resource Management:**
- Automatic cleanup of temporary files
- Process timeout enforcement
- Memory usage monitoring for large operations

The tool calling system in Avante.nvim provides a powerful, secure, and extensible foundation for LLM-driven code assistance, with comprehensive support for both built-in and custom tool development.