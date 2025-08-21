# RAG (Retrieval-Augmented Generation) in Avante.nvim

This document provides a comprehensive guide to the RAG implementation in Avante.nvim, covering architecture, setup, automation, and local model integration.

## Table of Contents

- [How RAG is Implemented](#how-rag-is-implemented)
- [How to Set Up RAG](#how-to-set-up-rag)
- [How to Automate RAG Setup](#how-to-automate-rag-setup)
- [Using Local Models (Ollama)](#using-local-models-ollama)

## How RAG is Implemented

### Architecture Overview

The RAG implementation consists of two main components:

1. **Python RAG Service** (`py/rag-service/`): A FastAPI-based microservice that handles document indexing, vector storage, and retrieval
2. **Lua Interface** (`lua/avante/rag_service.lua`): Neovim Lua code that communicates with the Python service

### Core Technologies Used

- **LlamaIndex**: Core RAG framework for document processing and indexing
- **ChromaDB**: Vector database for storing embeddings 
- **FastAPI**: REST API framework for the service
- **Tree-sitter**: Code parsing for better code document splitting
- **Docker/Nix**: Containerization options for service deployment

### RAG Pipeline Implementation

1. **Document Ingestion** (`main.py:972-1017`)
   - Supports both local directories and remote HTTPS resources
   - Automatic file watching using Python's `watchdog` library
   - Respects `.gitignore` patterns and excludes binary files
   - Special handling for code files using Tree-sitter for better chunking

2. **Document Processing** (`main.py:502-594`)
   - Text validation and cleaning for binary content detection
   - Code-aware splitting using `CodeSplitter` with language detection
   - Batch processing for performance optimization
   - Metadata preservation and URI injection for document tracking

3. **Vector Storage** (`main.py:323-408`)
   - ChromaDB persistent storage in `~/.local/share/nvim/avante/rag_service/`
   - Automatic index loading/creation on startup
   - Configuration change detection (clears index when models change)

4. **Retrieval & Generation** (`main.py:1145-1298`)
   - Semantic search with similarity scoring
   - Directory-scoped filtering for targeted searches
   - Source document tracking for attribution
   - LLM-powered response generation

### Provider Support Matrix

The implementation supports multiple LLM and embedding providers:

| Provider   | LLM Support | Embedding Support | Local |
|------------|-------------|-------------------|--------|
| ollama     | ✅          | ✅                | ✅     |
| openai     | ✅          | ✅                | ❌     |
| dashscope  | ✅          | ✅                | ❌     |
| openrouter | ✅          | ❌                | ❌     |

### Service Management

- **Container Support**: Runs as `avante-rag-service` Docker container or Nix shell
- **Health Monitoring**: Built-in health checks and status endpoints  
- **Leader Election**: File-based locking for multi-instance coordination
- **Resource Management**: Automatic startup/shutdown with file watching

### API Endpoints

Key REST endpoints provided:
- `POST /api/v1/add_resource` - Add directories/URLs for indexing
- `POST /api/v1/retrieve` - Semantic search and retrieval
- `GET /api/v1/resources` - List all indexed resources
- `POST /api/v1/indexing_status` - Check indexing progress

The RAG service integrates seamlessly with the Avante.nvim AI coding assistant, allowing it to provide context-aware responses based on your project's codebase and documentation.

## How to Set Up RAG

### 1. Configuration Setup

Add RAG configuration to your Avante config in Neovim:

```lua
require('avante').setup({
  -- ... other config
  rag_service = {
    enabled = true,  -- Enable the RAG service
    host_mount = os.getenv("HOME"),  -- Host mount path (Docker will mount this)
    runner = "docker",  -- Use "docker" or "nix"
    
    -- LLM Configuration
    llm = {
      provider = "ollama",  -- or "openai", "dashscope", "openrouter"
      endpoint = "http://localhost:11434",  -- Ollama endpoint
      api_key = "",  -- Not needed for Ollama
      model = "llama2",  -- Your Ollama model name
      extra = nil,  -- Optional extra parameters
    },
    
    -- Embedding Configuration  
    embed = {
      provider = "ollama",  -- or "openai", "dashscope"
      endpoint = "http://localhost:11434",
      api_key = "",  -- Not needed for Ollama
      model = "nomic-embed-text",  -- Your embedding model
      extra = {
        embed_batch_size = 10,
      },
    },
    
    docker_extra_args = "",  -- Extra Docker arguments if needed
  },
})
```

### 2. Prerequisites

**For Docker runner (recommended):**
- Docker installed and running
- Internet access to pull the service image

**For Nix runner:**
- Nix package manager installed
- All dependencies available in Nix environment

### 3. Model Setup (for Ollama)

If using Ollama, ensure you have the required models pulled:

```bash
# Pull LLM model
ollama pull llama2  # or your preferred model

# Pull embedding model  
ollama pull nomic-embed-text
```

### 4. Service Startup

The RAG service starts automatically when:
1. RAG is enabled in config (`rag_service.enabled = true`)
2. You use any Avante RAG functionality
3. The service detects configuration changes

**Manual startup checking:**
- Service runs on port `20250` by default
- Container name: `avante-rag-service`
- Data stored in: `~/.local/share/nvim/avante/rag_service/`

### 5. Adding Resources

Once configured, you can add directories or web resources for indexing:

**Through Neovim commands** (if available in UI):
- Add your project directory for indexing
- Add documentation URLs for reference

**Direct API calls** (for testing):
```bash
# Add local directory
curl -X POST http://localhost:20250/api/v1/add_resource \
  -H "Content-Type: application/json" \
  -d '{"name": "my-project", "uri": "file:///path/to/your/project"}'

# Add web resource  
curl -X POST http://localhost:20250/api/v1/add_resource \
  -H "Content-Type: application/json" \
  -d '{"name": "docs", "uri": "https://example.com/docs"}'
```

### 6. Verification

Check if RAG is working:

```bash
# Health check
curl http://localhost:20250/api/health

# List resources
curl http://localhost:20250/api/v1/resources

# Check indexing status
curl -X POST http://localhost:20250/api/v1/indexing_status \
  -H "Content-Type: application/json" \
  -d '{"uri": "file:///path/to/your/project"}'
```

The service will automatically index supported file types (code, markdown, text files) while respecting `.gitignore` patterns and excluding binary files.

## How to Automate RAG Setup

The project provides several automation options for RAG service deployment and management:

### 1. Docker Automation (Recommended)

**Pre-built Container:**
```bash
# The RAG service uses a pre-built container image
docker pull quay.io/yetoneful/avante-rag-service:0.0.11

# Automatic container management through Avante
# Service starts automatically when RAG is enabled in config
```

**Custom Docker Build:**
```bash
# Build custom RAG service image
make build-image
# This builds: quay.io/yetoneful/avante-rag-service:0.0.11

# Push to registry (if needed)
make push-image
```

### 2. Nix Environment Automation

**Automated Nix Setup (`py/rag-service/run.sh`):**
```bash
#!/usr/bin/env bash
# Copies service files to target directory
TARGET_DIR=${1:-"$HOME/.local/state/avante-rag-service"}
mkdir -p "$TARGET_DIR"
cp -r src/ requirements.txt shell.nix "$TARGET_DIR"
cd "$TARGET_DIR"
nix-shell  # Automatically installs dependencies and starts service
```

**Nix Shell Features (`shell.nix`):**
- Automatic Python 3.11 + UV package manager setup
- Dependency installation via `uv pip install -r requirements.txt`
- FastAPI service startup with 3 workers
- Comprehensive logging to `shell_log.txt`
- Environment variable support

### 3. Infrastructure as Code Options

**Docker Compose Setup (create this):**
```yaml
# docker-compose.yml
version: '3.8'
services:
  rag-service:
    image: quay.io/yetoneful/avante-rag-service:0.0.11
    ports:
      - "20250:20250"
    environment:
      - ALLOW_RESET=TRUE
      - DATA_DIR=/data
      - RAG_EMBED_PROVIDER=ollama
      - RAG_EMBED_ENDPOINT=http://host.docker.internal:11434
      - RAG_EMBED_MODEL=nomic-embed-text
      - RAG_LLM_PROVIDER=ollama
      - RAG_LLM_ENDPOINT=http://host.docker.internal:11434
      - RAG_LLM_MODEL=llama2
    volumes:
      - rag-data:/data
      - ${HOME}:/host:ro
    restart: unless-stopped
    
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama-data:/root/.ollama
    restart: unless-stopped

volumes:
  rag-data:
  ollama-data:
```

**Kubernetes Deployment:**
```yaml
# rag-service-k8s.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: avante-rag-service
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: rag-service
        image: quay.io/yetoneful/avante-rag-service:0.0.11
        ports:
        - containerPort: 20250
        env:
        - name: RAG_EMBED_PROVIDER
          value: "ollama"
        - name: RAG_LLM_PROVIDER  
          value: "ollama"
        volumeMounts:
        - name: data
          mountPath: /data
        - name: host-mount
          mountPath: /host
          readOnly: true
```

### 4. Automated Neovim Configuration

**Configuration Template Script:**
```lua
-- setup-rag.lua
local function setup_ollama_rag()
  return {
    rag_service = {
      enabled = true,
      host_mount = os.getenv("HOME"),
      runner = "docker",
      llm = {
        provider = "ollama",
        endpoint = "http://localhost:11434",
        api_key = "",
        model = "llama2",
      },
      embed = {
        provider = "ollama", 
        endpoint = "http://localhost:11434",
        api_key = "",
        model = "nomic-embed-text",
        extra = { embed_batch_size = 10 },
      },
    }
  }
end

-- Auto-detect and setup
require('avante').setup(setup_ollama_rag())
```

### 5. CI/CD Integration

The Makefile provides CI-friendly commands:
```bash
# Test RAG service
make luatest          # Run Lua tests including RAG tests
make build-image      # Build Docker image in CI
make push-image       # Push to registry

# Development workflow
make lint             # Code quality checks
make lua-typecheck    # Type checking
```

### 6. Environment Setup Scripts

**Complete Automation Script:**
```bash
#!/bin/bash
# setup-avante-rag.sh

# 1. Setup Ollama
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve &
ollama pull llama2
ollama pull nomic-embed-text

# 2. Setup Docker (if not present)
command -v docker >/dev/null || curl -fsSL https://get.docker.com | sh

# 3. Configure Avante with RAG
cat > ~/.config/nvim/lua/rag-config.lua << 'EOF'
require('avante').setup({
  rag_service = {
    enabled = true,
    host_mount = os.getenv("HOME"),
    runner = "docker",
    llm = { provider = "ollama", endpoint = "http://localhost:11434", model = "llama2" },
    embed = { provider = "ollama", endpoint = "http://localhost:11434", model = "nomic-embed-text" },
  }
})
EOF

echo "RAG setup complete! Add 'require('rag-config')' to your Neovim config."
```

The automation focuses on making RAG deployment as seamless as possible, with automatic service management, dependency resolution, and configuration templating.

## Using Local Models (Ollama)

**Yes, absolutely!** Ollama is fully supported as both an LLM and embedding provider for the RAG service. Here's the comprehensive breakdown:

### 1. Ollama Provider Support

From the analysis of `py/rag-service/src/providers/ollama.py` and the configuration, Ollama has:

✅ **LLM Support** - Any Ollama model (llama2, mistral, codellama, etc.)  
✅ **Embedding Support** - Embedding models like `nomic-embed-text`  
✅ **No API Key Required** - Local authentication  
✅ **Custom Endpoint Support** - Configure your Ollama server URL

### 2. Configuration for Ollama

**Complete Ollama RAG Setup:**
```lua
require('avante').setup({
  rag_service = {
    enabled = true,
    host_mount = os.getenv("HOME"),  -- Your project files location
    runner = "docker",  -- or "nix"
    
    -- LLM Configuration (for generating responses)
    llm = {
      provider = "ollama",
      endpoint = "http://localhost:11434",  -- Default Ollama endpoint
      api_key = "",  -- Not needed for Ollama
      model = "llama2",  -- Your choice: llama2, mistral, codellama, etc.
      extra = {
        temperature = 0.7,  -- Optional: control response randomness
        top_p = 0.9,       -- Optional: nucleus sampling
      },
    },
    
    -- Embedding Configuration (for document indexing)
    embed = {
      provider = "ollama",
      endpoint = "http://localhost:11434",
      api_key = "",  -- Not needed for Ollama
      model = "nomic-embed-text",  -- Recommended embedding model
      extra = {
        embed_batch_size = 10,  -- Process 10 documents at once
      },
    },
  },
})
```

### 3. Required Ollama Models

**Pull the necessary models:**
```bash
# Start Ollama service
ollama serve

# Pull LLM model (choose one or more)
ollama pull llama2          # 7B general purpose
ollama pull codellama       # Code-optimized
ollama pull mistral         # Alternative general purpose
ollama pull llama3.1        # Latest Meta model

# Pull embedding model (required for RAG)
ollama pull nomic-embed-text  # Best embedding model for Ollama
ollama pull all-minilm      # Alternative smaller embedding model
```

### 4. Ollama-Specific Features

**Automatic Model Detection:**
- The factory pattern (`providers/factory.py`) dynamically loads Ollama providers
- No hardcoded limitations on model names
- Supports any model available in your Ollama instance

**Local Privacy:**
- All processing happens locally
- No data sent to external APIs
- Full control over model versions and updates

**Resource Optimization:**
- Batch processing for embeddings (`embed_batch_size`)
- Configurable worker processes
- Memory-efficient document chunking

### 5. Advanced Ollama Setup

**Custom Ollama Server:**
```lua
-- For remote Ollama server
embed = {
  provider = "ollama",
  endpoint = "http://192.168.1.100:11434",  -- Remote Ollama server
  model = "nomic-embed-text",
}
```

**Multiple Model Strategy:**
```lua
-- Use different models for different purposes
llm = {
  provider = "ollama",
  model = "codellama",  -- Code generation
},
embed = {
  provider = "ollama", 
  model = "nomic-embed-text",  -- Document embedding
}
```

### 6. Performance Considerations

**Hardware Requirements:**
- **LLM Models**: 8GB+ RAM for 7B models, 16GB+ for 13B+
- **Embedding Models**: 2-4GB RAM typically sufficient
- **GPU**: Ollama supports CUDA/Metal acceleration automatically

**Optimization Tips:**
```lua
embed = {
  provider = "ollama",
  model = "nomic-embed-text",
  extra = {
    embed_batch_size = 20,  -- Increase for faster processing
  },
}
```

### 7. Verification Commands

**Test Ollama Integration:**
```bash
# Check Ollama models
ollama list

# Test embedding model
curl http://localhost:11434/api/embeddings \
  -d '{"model": "nomic-embed-text", "prompt": "test document"}'

# Test LLM model  
curl http://localhost:11434/api/generate \
  -d '{"model": "llama2", "prompt": "Hello"}'
```

The RAG service seamlessly integrates with Ollama, giving you a completely local, private, and customizable RAG solution that runs entirely on your hardware without any external API dependencies.

## Summary

The RAG implementation in Avante.nvim is production-ready with features like:

- **Comprehensive Architecture**: FastAPI + LlamaIndex + ChromaDB
- **Easy Setup**: Simple Neovim configuration with automatic service management
- **Multiple Deployment Options**: Docker, Nix, Docker Compose, Kubernetes
- **Full Local Support**: Complete Ollama integration for privacy and control
- **Smart Document Processing**: Code-aware chunking, file watching, .gitignore respect
- **Provider Flexibility**: Support for OpenAI, Ollama, DashScope, and more

You can run a completely local RAG solution using Ollama models for maximum privacy and control over your development workflow.