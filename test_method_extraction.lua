-- Test script to analyze TreeSitter node types for method extraction
-- This will help us identify the correct node types for each language

local function analyze_treesitter_nodes(content, filetype)
  print("\n🔍 Analyzing TreeSitter nodes for " .. filetype .. ":")
  
  -- Create a temporary buffer with the content
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  vim.api.nvim_buf_set_option(buf, 'filetype', filetype)
  
  -- Wait for treesitter to parse
  vim.wait(100)
  
  local parser = vim.treesitter.get_parser(buf, filetype)
  if not parser then
    print("   ❌ No TreeSitter parser available for " .. filetype)
    vim.api.nvim_buf_delete(buf, {force = true})
    return
  end
  
  local tree = parser:parse()[1]
  if not tree then
    print("   ❌ Failed to parse content for " .. filetype)
    vim.api.nvim_buf_delete(buf, {force = true})
    return
  end
  
  local root = tree:root()
  
  -- Function to recursively walk the tree and find function-related nodes
  local function walk_tree(node, depth)
    local node_type = node:type()
    local indent = string.rep("  ", depth)
    
    -- Look for function-related nodes
    if node_type:match("function") or node_type:match("method") or 
       node_type:match("procedure") or node_type:match("subroutine") or
       node_type:match("def") then
      print(indent .. "🎯 " .. node_type)
      
      -- Analyze children to find name nodes
      for i = 0, node:child_count() - 1 do
        local child = node:child(i)
        if child then
          local child_type = child:type()
          print(indent .. "  └─ " .. child_type)
          if child_type:match("identifier") or child_type:match("name") then
            local text = vim.treesitter.get_node_text(child, buf)
            print(indent .. "     💡 NAME: " .. text)
          end
        end
      end
    else
      -- Continue recursively but only print function-related nodes
      for i = 0, node:child_count() - 1 do
        local child = node:child(i)
        if child then
          walk_tree(child, depth + 1)
        end
      end
    end
  end
  
  walk_tree(root, 0)
  vim.api.nvim_buf_delete(buf, {force = true})
end

-- Test cases for different languages
local test_cases = {
  {
    language = "c",
    content = [[
int add(int a, int b) {
    return a + b;
}

static void helper_function() {
    printf("Helper");
}

struct MyStruct {
    int value;
};
]]
  },
  {
    language = "cpp", 
    content = [[
class Calculator {
public:
    int add(int a, int b) {
        return a + b;
    }
    
    static void staticMethod() {
        std::cout << "Static method";
    }
};

namespace Utils {
    void utility_function() {
        // utility code
    }
}
]]
  },
  {
    language = "java",
    content = [[
public class Calculator {
    public int add(int a, int b) {
        return a + b;
    }
    
    private static void helperMethod() {
        System.out.println("Helper");
    }
    
    protected Calculator() {
        // constructor
    }
}
]]
  },
  {
    language = "python",
    content = [[
class Calculator:
    def add(self, a, b):
        return a + b
    
    @staticmethod
    def static_method():
        print("Static method")
    
    def __init__(self):
        pass

def standalone_function():
    return "standalone"

async def async_function():
    await some_operation()
]]
  },
  {
    language = "sh",
    content = [[
#!/bin/bash

function my_function() {
    echo "Function with function keyword"
}

another_function() {
    echo "Function without function keyword"
    local var="test"
}

main() {
    my_function
    another_function
}
]]
  },
  {
    language = "perl",
    content = [[
sub my_subroutine {
    my ($arg1, $arg2) = @_;
    return $arg1 + $arg2;
}

sub another_sub($arg1, $arg2) {
    return $arg1 * $arg2;
}

package MyPackage;

sub package_method {
    my $self = shift;
    return "method result";
}
]]
  }
}

print("🚀 TreeSitter Node Analysis for Method Extraction")
print("=" .. string.rep("=", 60))

for _, test_case in ipairs(test_cases) do
  analyze_treesitter_nodes(test_case.content, test_case.language)
end

print("\n✅ Analysis complete!")
print("Use this information to update the method extraction function.")