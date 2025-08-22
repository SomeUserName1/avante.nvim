-- Hybrid WCA + Ollama Configuration for Avante.nvim
-- This creates a powerful AI pair programming setup with WCA for code generation 
-- and Ollama for project analysis/planning
--
-- Copy this to your Neovim config (e.g., ~/.config/nvim/lua/config/avante.lua)

return {
  "yetone/avante.nvim",
  event = "VeryLazy",
  lazy = false,
  version = false,
  opts = {
    -- Primary provider: Watson Code Assistant for code generation
    provider = "watsonx_code_assistant",
    
    -- Enable agentic mode for full tool access
    mode = "agentic",
    
    -- Behavior settings optimized for hybrid workflow
    behaviour = {
      auto_suggestions = false,        -- Disable to reduce WCA API calls
      auto_set_highlight_group = true,
      auto_set_filetype = true,
      auto_apply_diff_after_generation = false,
      support_paste_from_clipboard = true,
    },
    
    -- Enable RAG with Ollama for project analysis and orchestration
    rag_service = {
      enabled = true,
      host_mount = os.getenv("HOME"),
      runner = "docker",
      
      -- Use existing llama model initially, will switch to codestral when ready
      llm = {
        provider = "ollama",
        endpoint = "http://localhost:11434",
        api_key = "",
        model = "granite-code:8b", -- Use available granite model
        extra = {
          temperature = 0.1,    -- Lower for analytical tasks
          num_ctx = 16384,      -- Larger context for analysis
          keep_alive = "10m",   -- Keep model loaded longer
        },
      },
      
      -- Use nomic-embed-text for embeddings
      embed = {
        provider = "ollama",
        endpoint = "http://localhost:11434", 
        api_key = "",
        model = "nomic-embed-text",
        extra = {
          embed_batch_size = 15, -- Increased batch size
        },
      },
    },
    
    -- Provider configurations
    providers = {
      -- Watson Code Assistant configuration
      watsonx_code_assistant = {
        endpoint = "https://your-wca-endpoint", -- Replace with your actual endpoint
        model = "granite-code",
        timeout = 30000,
        context_window = 8192,
        extra_request_body = {
          temperature = 0.3, -- Lower for more consistent code generation
        },
      },
      
      -- Ollama configuration for analysis/planning
      ollama = {
        endpoint = "http://localhost:11434",
        model = "granite-code:8b", -- Will update to codestral when available
        timeout = 45000, -- Longer timeout for analysis tasks
        extra_request_body = {
          options = {
            temperature = 0.1,
            num_ctx = 16384,
            keep_alive = "10m",
          },
        },
      },
    },
    
    -- Optimized UI settings
    windows = {
      position = "right",
      width = 35,
      wrap = true,
      sidebar_header = {
        enabled = true,
        align = "center", 
        rounded = true,
      },
      input = {
        prefix = "🤖 ",
        height = 8,
      },
    },
    
    -- Enhanced mappings for hybrid workflow
    mappings = {
      ask = "<leader>aa",
      edit = "<leader>ae", 
      refresh = "<leader>ar",
      diff = {
        ours = "co",
        theirs = "ct",
        all_theirs = "ca",
        both = "cb",
        cursor = "cc",
        next = "]x",
        prev = "[x",
      },
      sidebar = {
        apply_all = "A",
        apply_cursor = "a",
        retry_user_request = "r",
        edit_user_request = "e",
        switch_windows = "<Tab>",
        reverse_switch_windows = "<S-Tab>",
        add_file = "@",
        remove_file = "d",
      },
    },
  },
  
  build = "make",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "stevearc/dressing.nvim",
    "nvim-lua/plenary.nvim", 
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
    {
      "nvim-telescope/telescope.nvim",
      optional = true,
    },
  },
  
  config = function(_, opts)
    require("avante").setup(opts)
    
    -- WCA Provider reference
    local wca = require("avante.providers.watsonx_code_assistant")
    
    -- Helper function to get current sidebar
    local function get_sidebar()
      local sidebar = require("avante").get()
      if not sidebar then
        require("avante.api").ask()
        sidebar = require("avante").get()
      end
      if not sidebar:is_open() then 
        sidebar:open({}) 
      end
      return sidebar
    end
    
    -- Helper function to switch providers  
    local function switch_provider(provider_name)
      -- Note: This assumes Avante has a provider switching function
      -- You may need to adjust based on actual Avante API
      vim.g.avante_provider = provider_name
      vim.notify("Switched to " .. provider_name, vim.log.levels.INFO)
    end
    
    -- WCA Method Commands (Direct code generation)
    vim.keymap.set('n', '<leader>wd', function()
      -- Ensure we're using WCA provider
      require("avante.config").override({ provider = "watsonx_code_assistant" })
      wca.method_command('document')
    end, { desc = 'WCA: Document code' })
    
    vim.keymap.set('n', '<leader>wt', function()
      require("avante.config").override({ provider = "watsonx_code_assistant" })
      wca.method_command('unit-test')
    end, { desc = 'WCA: Generate unit tests' })
    
    vim.keymap.set('n', '<leader>we', function()
      require("avante.config").override({ provider = "watsonx_code_assistant" })
      wca.method_command('explain')
    end, { desc = 'WCA: Explain code' })
    
    -- Hybrid Workflow Commands
    vim.keymap.set('n', '<leader>wc', function()
      -- Code generation mode with WCA
      switch_provider("watsonx_code_assistant")
      local sidebar = get_sidebar()
      sidebar.file_selector:add_current_buffer()
      vim.notify("🔨 Code Generation Mode (WCA)", vim.log.levels.INFO)
      vim.cmd('AvanteAsk')
    end, { desc = 'Code Generation Mode (WCA)' })
    
    vim.keymap.set('n', '<leader>wa', function()
      -- Analysis/Planning mode with Ollama
      switch_provider("ollama")
      local sidebar = get_sidebar()
      sidebar.file_selector:add_current_buffer()
      vim.notify("🧠 Analysis Mode (Ollama)", vim.log.levels.INFO)
      sidebar:update_content("Please analyze this code structure, identify patterns, and suggest improvements or explain the architecture.", { focus = true })
    end, { desc = 'Analysis Mode (Ollama)' })
    
    vim.keymap.set('n', '<leader>wr', function()
      -- Code review mode with Ollama
      switch_provider("ollama")
      local sidebar = get_sidebar()
      sidebar.file_selector:add_current_buffer()
      vim.notify("🔍 Code Review Mode (Ollama)", vim.log.levels.INFO)
      sidebar:update_content("Please review this code for:\n1. Code quality and best practices\n2. Potential bugs or issues\n3. Performance improvements\n4. Security considerations\n5. Maintainability suggestions", { focus = true })
    end, { desc = 'Code Review Mode (Ollama)' })
    
    vim.keymap.set('n', '<leader>wp', function()
      -- Project planning mode with Ollama
      switch_provider("ollama")
      local sidebar = get_sidebar()
      -- Add multiple files for broader context
      sidebar.file_selector:add_current_buffer()
      vim.notify("📋 Planning Mode (Ollama)", vim.log.levels.INFO)
      sidebar:update_content("Based on the project structure, help me plan the implementation approach. Consider:\n1. Architecture decisions\n2. File organization\n3. Dependencies and relationships\n4. Implementation steps", { focus = true })
    end, { desc = 'Project Planning Mode (Ollama)' })
    
    vim.keymap.set('n', '<leader>wg', function()
      -- Quick generation mode (WCA)
      switch_provider("watsonx_code_assistant")
      vim.notify("⚡ Quick Generation Mode (WCA)", vim.log.levels.INFO)
      vim.cmd('AvanteAsk')
    end, { desc = 'Quick Generation Mode (WCA)' })
    
    -- Utility commands
    vim.keymap.set('n', '<leader>wm', function()
      -- Check model status
      local current_provider = vim.g.avante_provider or "watsonx_code_assistant"
      vim.notify("Current Provider: " .. current_provider, vim.log.levels.INFO)
      
      -- Check if codestral is available
      local handle = io.popen("ollama list | grep codestral")
      local result = handle:read("*a")
      handle:close()
      
      if result and result ~= "" then
        vim.notify("✅ Codestral available! Consider upgrading Ollama model.", vim.log.levels.INFO)
      else
        vim.notify("⏳ Codestral still downloading...", vim.log.levels.WARN)
      end
    end, { desc = 'Check model status' })
    
    -- Auto-upgrade to codestral when available
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.defer_fn(function()
          -- Check for codestral after 30 seconds
          local handle = io.popen("ollama list | grep codestral")
          local result = handle:read("*a")
          handle:close()
          
          if result and result ~= "" then
            -- Update config to use codestral
            local config = require("avante.config")
            if config.providers.ollama then
              config.providers.ollama.model = "codestral:22b"
              config.rag_service.llm.model = "codestral:22b"
              vim.notify("🚀 Upgraded to Codestral for better code analysis!", vim.log.levels.INFO)
            end
          end
        end, 30000) -- 30 second delay
      end,
    })
    
    -- Which-key integration if available
    local ok, wk = pcall(require, "which-key")
    if ok then
      wk.register({
        ["<leader>w"] = {
          name = "🤖 AI Workflow",
          c = "🔨 Code Generation (WCA)",
          a = "🧠 Analysis (Ollama)", 
          r = "🔍 Code Review (Ollama)",
          p = "📋 Planning (Ollama)",
          g = "⚡ Quick Generation (WCA)",
          d = "📖 Document (WCA)",
          t = "🧪 Tests (WCA)",
          e = "💡 Explain (WCA)",
          m = "📊 Model Status",
        },
        ["<leader>a"] = {
          name = "Avante",
          a = "Ask",
          e = "Edit", 
          r = "Refresh",
        },
      })
    end
    
    -- Startup message
    vim.notify("🚀 Hybrid WCA + Ollama AI Workflow Ready!", vim.log.levels.INFO)
    vim.notify("Use <leader>w + [c/a/r/p/g] for different AI modes", vim.log.levels.INFO)
  end,
}