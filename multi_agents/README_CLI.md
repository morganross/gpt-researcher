# Multi-Agent CLI Argument Reference

This document describes the command-line arguments available for the Multi-Agent CLI executable, built from `gpt-researcher/Multi_Agent_CLI.py`.

## Usage

The executable can be run from your terminal. The basic usage is:

```bash
./main.exe --query "<your research query>" [options]
```

Where `main.exe` is the name of the executable (this might vary depending on how it was built).

## Arguments

Here are the available arguments:

### Optional Arguments

*   **`--query`**
    *   **Type:** string
    *   **Description:** The research query to conduct research on (optional if provided in task config or query file).


*   **`--task-config`**
    *   **Type:** string
    *   **Description:** Path to a task configuration JSON file.

*   **`--query-file`**
    *   **Type:** string
    *   **Description:** Path to a file containing the research query.

*   **`--guidelines-file`**
    *   **Type:** string
    *   **Description:** Path to a file containing the research guidelines.

*   **`--output-folder`**
    *   **Type:** string
    *   **Description:** Set the output folder (default: outputs).

*   **`--output-filename`**
    *   **Type:** string
    *   **Description:** Set the output filename (default: multi_agent_report_<uuid>.md).

*   **`--max-sections`**
    *   **Type:** integer
    *   **Description:** Set max_sections (default: value from task config).

*   **`--publish-markdown`**
    *   **Type:** boolean flag (use `--publish-markdown` to enable, `--no-publish-markdown` to disable)
    *   **Description:** Enable/disable markdown output (default: value from task config).

*   **`--publish-pdf`**
    *   **Type:** boolean flag (use `--publish-pdf` to enable, `--no-publish-pdf` to disable)
    *   **Description:** Enable/disable PDF output (default: value from task config).

*   **`--publish-docx`**
    *   **Type:** boolean flag (use `--publish-docx` to enable, `--no-publish-docx` to disable)
    *   **Description:** Enable/disable DOCX output (default: value from task config).

*   **`--include-human-feedback`**
    *   **Type:** boolean flag (use `--include-human-feedback` to enable, `--no-include-human-feedback` to disable)
    *   **Description:** Enable/disable human feedback (default: value from task config).

*   **`--follow-guidelines`**
    *   **Type:** boolean flag (use `--follow-guidelines` to enable, `--no-follow-guidelines` to disable)
    *   **Description:** Enable/disable following guidelines (default: value from task config).

*   **`--model`**
    *   **Type:** string
    *   **Description:** Set the model (default: value from task config).

*   **`--guidelines`**
    *   **Type:** list of strings (can provide multiple values separated by spaces)
    *   **Description:** Set guidelines (default: value from task config).

*   **`--verbose`**
    *   **Type:** boolean flag (use `--verbose` to enable, `--no-verbose` to disable)
    *   **Description:** Enable/disable verbose output (default: value from task config).