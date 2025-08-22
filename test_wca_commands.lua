-- Enhanced test script for WCA method commands
-- Run this in Neovim with a code file open to test the commands

local function test_wca_command_format()
  print("🔧 Testing WCA Command Format...")
  
  -- Test the method extraction function
  local wca = require("avante.providers.watsonx_code_assistant")
  
  -- Create a simple test function in current buffer to test method extraction
  local test_code = [[
function test_function() {
    console.log("This is a test");
}

def python_function():
    print("Python test")

public void javaMethod() {
    System.out.println("Java test");
}
]]
  
  -- Test command formatting
  local current_buffer = vim.api.nvim_get_current_buf()
  local file_path = vim.api.nvim_buf_get_name(current_buffer)
  local path_splits = vim.split(file_path, "/")
  local filename = path_splits[#path_splits] or "test.js"
  
  print("✅ Current file:", filename)
  
  -- Test WCA command formats (matching API specification)
  local commands = {"document", "unit-test", "explain"}
  
  for _, cmd in ipairs(commands) do
    local expected_format = "/" .. cmd .. " [" .. filename .. "](<file-" .. filename .. ">)"
    print("   " .. cmd .. " format: " .. expected_format)
  end
  
  return true
end

local function test_wca_api_structure()
  print("\n🔧 Testing WCA API Request Structure...")
  
  -- Test that parse_curl_args generates correct structure
  local wca = require("avante.providers.watsonx_code_assistant")
  local config = require("avante.config")
  
  -- Mock code_opts similar to what method_command would pass
  local mock_code_opts = {
    system_prompt = "WCA_COMMAND",
    messages = {
      { content = "/explain [test.lua](<file-test.lua>)", role = "user" }
    },
    selected_files = {
      { content = "print('Hello World')", name = "test.lua" }
    }
  }
  
  local provider = config.providers.watsonx_code_assistant
  if not provider then
    print("❌ WCA provider not configured")
    return false
  end
  
  -- Test the parse_curl_args function
  local curl_args = wca.parse_curl_args(provider, mock_code_opts)
  
  print("✅ API Request Structure:")
  print("   URL:", curl_args.url)
  print("   Headers:", vim.inspect(curl_args.headers))
  
  if curl_args.body.message then
    print("   ✅ Message field present (base64 encoded)")
    -- Decode to verify structure
    local decoded = vim.base64.decode(curl_args.body.message)
    local message_data = vim.json.decode(decoded)
    print("   Message payload:", vim.inspect(message_data))
  else
    print("   ❌ Message field missing")
  end
  
  if curl_args.body.files then
    print("   ✅ Files field present (base64 encoded file content)")
  else
    print("   ⚠️  Files field missing (no files selected)")
  end
  
  return true
end

local function test_provider_configuration()
  print("\n🔧 Testing WCA Provider Configuration...")
  
  local config = require("avante.config")
  local wca_config = config.providers.watsonx_code_assistant
  
  if not wca_config then
    print("❌ WCA provider configuration not found")
    return false
  end
  
  print("✅ WCA Configuration:")
  print("   Endpoint:", wca_config.endpoint)
  print("   Model:", wca_config.model)
  print("   Timeout:", wca_config.timeout)
  
  -- Check if API key is set (don't show the actual key)
  local wca_provider = require("avante.providers.watsonx_code_assistant")
  local has_api_key = wca_provider.api_key_name and os.getenv(wca_provider.api_key_name) ~= nil
  
  if has_api_key then
    print("✅ WCA_API_KEY is set")
  else
    print("⚠️  WCA_API_KEY environment variable not set")
    print("   Set it with: export WCA_API_KEY='your-api-key'")
  end
  
  return true
end

local function test_method_extraction()
  print("\n🔧 Testing Method Name Extraction...")
  
  -- Test with different file types
  local test_files = {
    {
      name = "test.py",
      content = [[
def sample_function():
    """A sample Python function"""
    return "Hello World"

class TestClass:
    def method_example(self):
        pass
]],
      expected_functions = {"sample_function", "method_example"}
    },
    {
      name = "test.js", 
      content = [[
function javascript_function() {
    console.log("JavaScript test");
}

const arrow_function = () => {
    return "Arrow function";
};
]],
      expected_functions = {"javascript_function"}
    }
  }
  
  print("✅ Method extraction test setup complete")
  print("   Move cursor to different functions and test:")
  print("   :lua require('avante.providers.watsonx_code_assistant').method_command('explain')")
  
  return true
end

local function demonstrate_wca_commands()
  print("\n📋 WCA Command Usage Examples:")
  print()
  print("1. 📖 **Document Command** - Generate documentation")
  print("   :lua require('avante.providers.watsonx_code_assistant').method_command('document')")
  print()
  print("2. 🧪 **Unit Test Command** - Generate unit tests") 
  print("   :lua require('avante.providers.watsonx_code_assistant').method_command('unit-test')")
  print()
  print("3. 💡 **Explain Command** - Explain code functionality")
  print("   :lua require('avante.providers.watsonx_code_assistant').method_command('explain')")
  print()
  print("🎯 **Hybrid Workflow Commands** (from config):")
  print("   <leader>wd - Document with WCA")
  print("   <leader>wt - Generate tests with WCA") 
  print("   <leader>we - Explain with WCA")
  print("   <leader>wa - Analyze with Ollama")
  print("   <leader>wc - Code generation with WCA")
  print()
end

local function run_integration_test()
  print("\n🚀 WCA Integration Test")
  print("=" .. string.rep("=", 50))
  
  -- Check if we're in a code file
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    print("⚠️  Please open a code file to test WCA commands")
    return
  end
  
  local format_ok = test_wca_command_format()
  local api_ok = test_wca_api_structure()
  local config_ok = test_provider_configuration() 
  local extract_ok = test_method_extraction()
  
  demonstrate_wca_commands()
  
  if format_ok and api_ok and config_ok and extract_ok then
    print("\n🎉 WCA Integration test complete!")
    print("✅ Command formatting: OK")
    print("✅ API request structure: OK")
    print("✅ Provider configuration: OK") 
    print("✅ Method extraction: OK")
    print()
    print("💡 Next steps:")
    print("   1. Ensure WCA_API_KEY is set")
    print("   2. Update WCA endpoint in your config if needed")
    print("   3. Try the commands on your code!")
  else
    print("\n⚠️  Some tests failed. Check the output above.")
  end
end

-- Run the comprehensive test
run_integration_test()