# 🚀 Hybrid WCA + Ollama Setup Guide

**AI Pair Programming with Enterprise Compliance**

This setup gives you the best of both worlds:
- **WCA** for compliant code generation 
- **Ollama** for local analysis and planning
- **Traditional Tools** for development workflow

## 📋 Prerequisites

✅ **Completed:**
- [x] Ollama installed and running
- [x] `nomic-embed-text` model downloaded  
- [x] `codestral:22b` downloading in background
- [x] Avante.nvim with WCA provider configured

## 🔧 Installation

### 1. Copy Configuration

```bash
# Copy the hybrid config to your Neovim setup
cp hybrid-wca-ollama-config.lua ~/.config/nvim/lua/config/avante.lua

# Or add to your existing lazy.nvim setup
```

### 2. Update Your WCA Endpoint

Edit the config file and replace:
```lua
endpoint = "https://your-wca-endpoint", -- Replace with your actual WCA endpoint
```

### 3. Restart Neovim

```bash
nvim
```

## 🎯 Workflow Commands

### **Quick Reference:**

| Command | Mode | Purpose |
|---------|------|---------|
| `<leader>wc` | 🔨 **Code Generation** | Use WCA for writing code |
| `<leader>wa` | 🧠 **Analysis** | Use Ollama to understand code |
| `<leader>wr` | 🔍 **Review** | Get code quality feedback |
| `<leader>wp` | 📋 **Planning** | Project architecture planning |
| `<leader>wd` | 📖 **Document** | Generate documentation |
| `<leader>wt` | 🧪 **Tests** | Generate unit tests |
| `<leader>we` | 💡 **Explain** | Explain code functionality |

### **Typical Workflow:**

```bash
# 1. Understand existing code
<leader>wa   # Analyze with Ollama

# 2. Plan your changes  
<leader>wp   # Plan with Ollama

# 3. Generate code
<leader>wc   # Code with WCA

# 4. Generate tests
<leader>wt   # Tests with WCA

# 5. Review everything
<leader>wr   # Review with Ollama
```

## 🔄 Model Management

### Check Status:
```
<leader>wm   # Check current models and providers
```

### Auto-Upgrade:
- System automatically detects when `codestral:22b` finishes downloading
- Upgrades Ollama config to use the better model
- Notification appears when upgrade happens

### Manual Model Switch:
```lua
-- In Neovim command mode
:lua vim.g.avante_provider = "ollama"      -- Switch to Ollama
:lua vim.g.avante_provider = "watsonx_code_assistant"  -- Switch to WCA
```

## 🛠️ Troubleshooting

### WCA Issues:
1. **"Invalid endpoint"** → Update WCA endpoint in config
2. **"Authentication failed"** → Check `WCA_API_KEY` environment variable
3. **"Command rejected"** → Use method commands (`<leader>wd`, `<leader>wt`, `<leader>we`)

### Ollama Issues:
1. **"Model not found"** → Run `ollama list` to check available models
2. **"Connection refused"** → Ensure Ollama is running (`ollama serve`)
3. **"Slow responses"** → Ollama is using CPU mode (normal with 22B model)

### RAG Issues:
1. **"RAG service not starting"** → Check Docker is running
2. **"No context found"** → Add files to context with `@` in sidebar

## 🎨 Customization

### Change Keybindings:
```lua
-- In your config
vim.keymap.set('n', '<leader>ai', function()
  -- Your custom AI workflow
end, { desc = 'Custom AI Command' })
```

### Add Custom Prompts:
```lua
-- Custom analysis prompt
vim.keymap.set('n', '<leader>wca', function()
  local sidebar = get_sidebar()
  sidebar:update_content("Analyze this code for security vulnerabilities.", { focus = true })
end, { desc = 'Security Analysis' })
```

### Provider Preferences:
```lua
-- Prefer different models
providers = {
  ollama = {
    model = "llama3.1:8b",  -- Change default model
  },
}
```

## 📊 Performance Tips

### For Better Performance:
1. **Use appropriate model for task:**
   - Quick questions → `llama3.1:8b`
   - Complex analysis → `codestral:22b` (when available)
   - Code generation → WCA

2. **Manage context:**
   - Add only relevant files to context (`@` in sidebar)
   - Use `<leader>wr` to remove unnecessary files

3. **Model management:**
   - Keep frequently used models loaded with `keep_alive`
   - Monitor memory usage with `htop`

## 🔒 Security Notes

- **WCA**: Enterprise-compliant, all data stays within your organization
- **Ollama**: Fully local, no external API calls
- **RAG**: Local Docker container, no data leaves your machine
- **Files**: Only files you explicitly add are shared with AI

## 🆘 Getting Help

1. **Check logs:** `:messages` in Neovim
2. **Model status:** `<leader>wm` 
3. **Restart services:** 
   ```bash
   # Restart Ollama
   pkill ollama && ollama serve
   
   # Restart RAG service  
   docker restart avante-rag-service
   ```

## 🚀 What's Next?

1. **Practice the workflow** with a small coding task
2. **Customize keybindings** to your preferences  
3. **Set up project-specific prompts** in `avante.md`
4. **Explore RAG capabilities** for large codebases

---

**Pro Tip:** Start with simple tasks like `<leader>we` (explain code) to get comfortable with the hybrid workflow before tackling complex generation tasks.