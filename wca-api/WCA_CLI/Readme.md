# Watsonx Code Assistant CLI Documentation

The Watsonx Code Assistant CLI (`wca cli`) is a command-line tool designed to interact with the IBM Watsonx Code Assistant (WCA) service. It provides functionalities like code completion, documentation generation, code explanation, unit test generation, and code translation.

## Prerequisites

1. **API Key**: Set the `IAM_APIKEY` environment variable with your IBM Cloud API key.
2. **Python**: Ensure Python 3.7+ is installed.
3. **Dependencies**: Install the required dependencies with:
   ```bash
   pip install requests typer
   ```

## Setup

Export the `IAM_APIKEY` environment variable:
```bash
export IAM_APIKEY=your_api_key_here
```

## Commands

### 1. **`prompt`**
Send a text prompt to the Watsonx Code Assistant service.

#### Usage:
```bash
python WCA_CLI/wca_cli.py prompt "<your_prompt>" [OPTIONS]
```

#### Options:
- `--source-file <file>`: Include a source file in the prompt.
- `--iam-apikey <key>`: API key for authentication (optional if `IAM_APIKEY` is set).
- `--allowed-licenses <licenses>`: Comma-separated list of allowed licenses (e.g., `mitlicense,Apache2.0`).
- `--to-file <output_file>`: Save the response to a file.

#### Example:
```bash
python WCA_CLI/wca_cli.py prompt "Generate a REST API in Python, based on the following swagger spec" --source-file OpenAPI.json
```


### 2. **`docs`**
Query IBM or Red Hat product documentation.

#### Usage:
```bash
python WCA_CLI/wca_cli.py docs "<query>" [OPTIONS]
```

#### Options:
- `--iam-apikey <key>`: API key for authentication (optional if IAM_APIKEY is set).
- `--to-file <output_file>`: Save the response to a file.

#### Example:
```bash
python WCA_CLI/wca_cli.py docs "How can I do an online backup of a partitioned db2 database? Format the command as markdown"
```


### 3. **`explain`**
Generate explaination for a source fle.

#### Usage:
```bash
python WCA_CLI/wca_cli.py explain <source_file> [OPTIONS]
```

#### Options:
- `--iam-apikey <key>`: API key for authentication (optional if IAM_APIKEY is set).
- `--to-file <output_file>`: Save the explanation to a file.

#### Example:
```bash
python WCA_CLI/wca_cli.py explain my_script.py --to-file explanation.txt
```


### 4. **`document`**
Generate documentation for a code file.

#### Usage:
```bash
python WCA_CLI/wca_cli.py document <source_file> [OPTIONS]
```

#### Options:
- `--iam-apikey <key>`: API key for authentication (optional if IAM_APIKEY is set).
- `--to-file <output_file>`: Save the documentation to a file.

#### Example:
```bash
python WCA_CLI/wca_cli.py document my_code.py
```


### 5. **`unit-test`**
Generate unit tests for a source file.

#### Usage:
```bash
python WCA_CLI/wca_cli.py unit-test <source_file> [OPTIONS]
```

#### Options:
- `--using <framework>`: Specify the unit test framework (e.g., `pytest`).
- `--similar-to <file>`: Provide a file with an example of desired unit test structure.
- `--iam-apikey <key>`: API key for authentication (optional if IAM_APIKEY is set).
- `--to-file <output_file>`: Save the unit tests to a file.

#### Example:
```bash
python WCA_CLI/wca_cli.py unit-test my_code.py --using pytest
```


### 6. **`translate`**
Translate code from one programming language to another.

#### Usage:
```bash
python WCA_CLI/wca_cli.py translate <source_file> --to <target_language> [OPTIONS]
```

#### Options:
- `--from <source_language>`: Specify the source language (optional).
- `--iam-apikey <key>`: API key for authentication (optional if IAM_APIKEY is set).
- `--to-file <output_file>`: Save the translated code to a file.

#### Example:
```bash
python WCA_CLI/wca_cli.py translate my_code.py --to java --to-file translated_code.java
```
