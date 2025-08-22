-- Test script for WCA + Ollama Hybrid Setup
-- Run this in Neovim to test the configuration

local function test_wca_integration()
  print("🔧 Testing WCA Integration...")
  
  -- Check if WCA provider is available
  local providers = require("avante.providers")
  local config = require("avante.config")
  
  -- Test 1: Check if WCA provider is registered
  local wca_provider = config.providers.watsonx_code_assistant
  if wca_provider then
    print("✅ WCA provider is registered")
    print("   Endpoint:", wca_provider.endpoint)
    print("   Model:", wca_provider.model)
  else
    print("❌ WCA provider not found")
    return false
  end
  
  -- Test 2: Check if WCA module loads
  local ok, wca_module = pcall(require, "avante.providers.watsonx_code_assistant")
  if ok then
    print("✅ WCA module loads successfully")
    if wca_module.method_command then
      print("   Method commands available: document, unit-test, explain")
    end
  else
    print("❌ WCA module failed to load:", wca_module)
    return false
  end
  
  -- Test 3: Check Ollama availability
  local ollama_provider = config.providers.ollama
  if ollama_provider then
    print("✅ Ollama provider is registered")
    print("   Endpoint:", ollama_provider.endpoint)
  else
    print("❌ Ollama provider not found")
  end
  
  -- Test 4: Check if ollama service is running
  local handle = io.popen("curl -s http://localhost:11434/api/tags 2>/dev/null")
  if handle then
    local result = handle:read("*a")
    handle:close()
    if result and result:find("models") then
      print("✅ Ollama service is running")
      -- Parse available models
      local ok_json, models_data = pcall(vim.json.decode, result)
      if ok_json and models_data.models then
        print("   Available models:")
        for _, model in ipairs(models_data.models) do
          print("     -", model.name)
        end
      end
    else
      print("⚠️  Ollama service not responding")
    end
  end
  
  print("\n🎯 WCA Method Command Test")
  print("To test WCA method commands, try:")
  print("1. Open a code file")
  print("2. Use :lua require('avante.providers.watsonx_code_assistant').method_command('explain')")
  print("3. Or use the keybindings from the hybrid config")
  
  return true
end

local function test_hybrid_workflow()
  print("\n🔄 Testing Hybrid Workflow Setup...")
  
  -- Test keybinding setup
  local keymap_found = false
  for _, map in ipairs(vim.api.nvim_get_keymap('n')) do
    if map.lhs and map.lhs:find('<leader>w') then
      keymap_found = true
      break
    end
  end
  
  if keymap_found then
    print("✅ Hybrid workflow keybindings are set")
  else
    print("⚠️  Hybrid workflow keybindings not found")
    print("   Make sure to load the hybrid config")
  end
  
  -- Check RAG service config
  local rag_config = require("avante.config").rag_service
  if rag_config and rag_config.enabled then
    print("✅ RAG service is enabled")
    print("   LLM provider:", rag_config.llm.provider)
    print("   LLM model:", rag_config.llm.model)
  else
    print("⚠️  RAG service not enabled")
  end
  
  print("\n📋 Quick Workflow Test:")
  print("1. <leader>wa - Analysis with Ollama")
  print("2. <leader>wc - Code generation with WCA") 
  print("3. <leader>wd - Document with WCA")
  print("4. <leader>wt - Tests with WCA")
  print("5. <leader>we - Explain with WCA")
end

-- Run tests
print("🚀 Hybrid WCA + Ollama Setup Test\n")
local wca_ok = test_wca_integration()
test_hybrid_workflow()

if wca_ok then
  print("\n🎉 Setup looks good! You can now use the hybrid workflow.")
  print("💡 Next steps:")
  print("   1. Set WCA_API_KEY environment variable")
  print("   2. Update WCA endpoint in your config")
  print("   3. Try the workflow commands")
else
  print("\n⚠️  Some issues found. Check the output above.")
end