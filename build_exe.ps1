# PowerShell script to build the Multi-Agent-CLI executable
# This script downloads the gpt-researcher repository, extracts it,
# and uses PyInstaller to create a standalone executable.

# Set environment variables for API keys
$env:PYTHONIOENCODING = "utf-8"

# Create a temporary directory for the download and extraction
$tempDir = Join-Path $env:TEMP "gpt-researcher-build"
$zipPath = Join-Path $tempDir "gpt-researcher.zip"
$extractPath = Join-Path $tempDir "extract"

# Create the temporary directory if it doesn't exist
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-Host "Created temporary directory: $tempDir"
}

# Clean up any previous extraction
if (Test-Path $extractPath) {
    Remove-Item $extractPath -Recurse -Force
    Write-Host "Cleaned up previous extraction"
}

# Create the extraction directory
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

# Download the repository ZIP file
Write-Host "Downloading gpt-researcher repository..."
$repoUrl = "https://github.com/assafelovic/gpt-researcher/archive/refs/heads/master.zip"
Invoke-WebRequest -Uri $repoUrl -OutFile $zipPath
Write-Host "Download complete: $zipPath"

# Extract the ZIP file
Write-Host "Extracting ZIP file..."
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
Write-Host "Extraction complete: $extractPath"

# Find the extracted directory (it will be named gpt-researcher-master)
$repoDir = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
Write-Host "Repository directory: $($repoDir.FullName)"

# Change to the repository directory
Set-Location $repoDir.FullName
Write-Host "Changed directory to: $($repoDir.FullName)"

# Clean up build artifacts
Remove-Item ./dist -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item ./build -Recurse -Force -ErrorAction SilentlyContinue

# Remove unnecessary files and folders
Remove-Item ./frontend -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item ./docs -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item ./evals -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item ./tests -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item ./mcp-server -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item ./CURSOR_RULES.md -Force -ErrorAction SilentlyContinue
Remove-Item ./CODE_OF_CONDUCT.md -Force -ErrorAction SilentlyContinue
Remove-Item ./CONTRIBUTING.md -Force -ErrorAction SilentlyContinue
Remove-Item ./LICENSE -Force -ErrorAction SilentlyContinue
Remove-Item ./Procfile -Force -ErrorAction SilentlyContinue
Remove-Item ./README-ja_JP.md -Force -ErrorAction SilentlyContinue
Remove-Item ./README-ko_KR.md -Force -ErrorAction SilentlyContinue
Remove-Item ./README-zh_CN.md -Force -ErrorAction SilentlyContinue
Remove-Item ./README.md -Force -ErrorAction SilentlyContinue
Remove-Item ./citation.cff -Force -ErrorAction SilentlyContinue

# Create Multi_Agent_CLI.py from embedded content
$multiAgentCliContent = @'
import asyncio
import argparse
import json
import os
import sys
import uuid
from copy import deepcopy

# Adjust path for importing multi_agents
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from multi_agents.agents import ChiefEditorAgent
from gpt_researcher.utils.enum import Tone # Assuming Tone is needed
from dotenv import load_dotenv

# Load default task configuration
DEFAULT_TASK = {
  "query": "Is AI in a hype cycle?",
  "max_sections": 3,
  "publish_formats": {
    "markdown": True,
    "pdf": True,
    "docx": True
  },
  "include_human_feedback": False,
  "follow_guidelines": False,
  "model": "gpt-4o",
  "guidelines": [
    "The report MUST be written in APA format",
    "Each sub section MUST include supporting sources using hyperlinks. If none exist, erase the sub section or rewrite it to be a part of the previous section",
    "The report MUST be written in spanish"
  ],
  "verbose": True
}

def deep_merge(dict1, dict2):
    """
    Deep merge two dictionaries. dict2 values override dict1 values.
    Handles nested dictionaries.
    """
    for key, value in dict2.items():
        if key in dict1 and isinstance(dict1[key], dict) and isinstance(value, dict):
            deep_merge(dict1[key], value)
        else:
            dict1[key] = value

def open_task():
    """
    Loads the task configuration from task.json in the config subdirectory relative to the executable.
    If task.json does not exist, it creates a default task.json file.
    """
    # Determine the path for task.json relative to the executable
    exe_dir = os.path.dirname(sys.executable)
    config_dir = os.path.join(exe_dir, 'config')
    task_json_path = os.path.join(config_dir, 'task.json')

    task = None

    # Check if the config directory exists, create if not
    if not os.path.exists(config_dir):
        try:
            os.makedirs(config_dir)
            print(f"Created config directory at '{config_dir}'")
        except OSError:
            print(f"Warning: Could not create config directory at '{config_dir}'")

    # Check if task.json exists
    if os.path.exists(task_json_path):
        try:
            with open(task_json_path, 'r') as f:
                task = json.load(f)
            print(f"Loaded task.json from '{task_json_path}'")
        except json.JSONDecodeError:
            print(f"Error: Could not decode JSON from '{task_json_path}'. Creating a default task.json.")
            task = None # Reset task to trigger default creation

    # If task.json did not exist or had a decoding error, create a default one
    if task is None:
        task = deepcopy(DEFAULT_TASK) # Use the loaded default task content
        try:
            with open(task_json_path, 'w') as f:
                json.dump(task, f, indent=2)
            print(f"Created default task.json at '{task_json_path}'")
        except IOError:
            print(f"Error: Could not write default task.json to '{task_json_path}'")
            # Fall back to using DEFAULT_TASK without writing to file
            task = deepcopy(DEFAULT_TASK)

    # Override model with STRATEGIC_LLM if defined in environment
    strategic_llm = os.environ.get("STRATEGIC_LLM")
    if strategic_llm and ":" in strategic_llm:
        # Extract the model name (part after the first colon)
        model_name = strategic_llm.split(":", 1)[1]
        task["model"] = model_name
    elif strategic_llm:
        task["model"] = strategic_llm # Use the full strategic_llm value if no colon

    return task

def load_task_config(args):
    """
    Load and assemble configuration based on the specified hierarchy:
    task.json (from open_task) -> Specified task file -> Query file -> Guidelines file -> Command-line arguments.
    """
    # 1. Start with configuration from open_task()
    config = open_task()

    # 2. Load from a specified task config file if provided
    if args.task_config:
        if not os.path.exists(args.task_config):
            print(f"Error: Task config file '{args.task_config}' not found.")
            sys.exit(1)
        try:
            with open(args.task_config, 'r') as f:
                task_from_file = json.load(f)
            deep_merge(config, task_from_file)
        except json.JSONDecodeError:
            print(f"Error: Could not decode JSON from '{args.task_config}'")
            sys.exit(1)

    # 3. Override with command-line arguments
    # Directly use parsed arguments, which argparse has already handled based on defined types
    args_dict = vars(args)
    for key in DEFAULT_TASK.keys(): # Iterate through default keys to apply overrides
        # Check if the argument was provided and is not the default value set by argparse
        # This requires comparing to the default value set in add_argument
        # A simpler approach is to check if the argument is present in the parsed args
        # and not None, assuming argparse handles defaults appropriately.
        # For boolean flags, argparse sets the value based on presence, so check if the key exists
        if key in args_dict and args_dict[key] is not None:
             # Special handling for boolean flags where the argument name might be different (--no-key)
            if isinstance(DEFAULT_TASK.get(key), bool):
                 # Check if the flag was explicitly set (either --key or --no-key)
                 # This is tricky with argparse's default handling.
                 # A more robust way is to check if the argument's source is not the default.
                 # For now, assume if the key is in args_dict and not None, it was set.
                 config[key] = args_dict[key]
            elif not isinstance(DEFAULT_TASK.get(key), bool): # Handle non-boolean overrides
                 config[key] = args_dict[key]

    # Handle query file argument - overrides default and task config query
    if args.query_file:
        if not os.path.exists(args.query_file):
            print(f"Error: Query file '{args.query_file}' not found.")
            sys.exit(1)
        try:
            with open(args.query_file, 'r') as f:
                config['query'] = f.read().strip()
        except IOError:
            print(f"Error: Could not read query file '{args.query_file}'")
            sys.exit(1)

    # Handle guidelines file argument - overrides default, task config, and query file
    if args.guidelines_file:
        if not os.path.exists(args.guidelines_file):
            print(f"Error: Guidelines file '{args.guidelines_file}' not found.")
            sys.exit(1)
        try:
            with open(args.guidelines_file, 'r') as f:
                # Assuming guidelines file contains a string or a JSON list
                # Adjust reading logic based on expected file format
                guidelines_content = f.read().strip()
                # If guidelines are expected to be a list, you might need to parse JSON
                # try:
                #     config['guidelines'] = json.loads(guidelines_content)
                # except json.JSONDecodeError:
                #     print(f"Warning: Could not decode JSON from guidelines file '{args.guidelines_file}'. Using raw content as string.")
                config['guidelines'] = guidelines_content.splitlines() # Assuming each line is a guideline
        except IOError:
            print(f"Error: Could not read guidelines file '{args.guidelines_file}'")
            sys.exit(1)

    # Handle the query argument separately as it's positional - overrides query file
    if args.query:
        config['query'] = args.query

    # Handle output folder argument - overrides default, task config, query file, and guidelines file
    if args.output_folder:
        config['output_folder'] = args.output_folder

    # Handle output filename argument - overrides default, task config, query file, guidelines file, and output folder
    if args.output_filename:
        config['output_file'] = args.output_filename

    # Handle nested publish_formats separately
    if args.publish_markdown is not None:
        config['publish_formats']['markdown'] = args.publish_markdown
    if args.publish_pdf is not None:
        config['publish_formats']['pdf'] = args.publish_pdf
    if args.publish_docx is not None:
        config['publish_formats']['docx'] = args.publish_docx


    return config

async def main():
    parser = argparse.ArgumentParser(description="Multi-agent research CLI")

    # Positional argument for the query
    parser.add_argument("--query", type=str, help="The research query (optional if provided in task config or query file).")

    # Optional argument for a task configuration file
    parser.add_argument("--task-config", type=str, help="Path to a task configuration JSON file.")

    # Optional argument for a query file
    parser.add_argument("--query-file", type=str, help="Path to a file containing the research query.")

    # Optional argument for guidelines file
    parser.add_argument("--guidelines-file", type=str, help="Path to a file containing the research guidelines.")

    # Optional argument for output folder
    parser.add_argument("--output-folder", type=str, help=f"Set the output folder (default: {DEFAULT_TASK.get('output_folder', 'outputs')})")

    # Optional argument for output filename
    parser.add_argument("--output-filename", type=str, help=f"Set the output filename (default: {DEFAULT_TASK.get('output_file', 'multi_agent_report_<uuid>.md')})")

    # Hardcoded arguments based on task.json
    parser.add_argument("--max-sections", type=int, help=f"Set max_sections (default: {DEFAULT_TASK.get('max_sections')})")

    # Arguments for publish_formats (nested dictionary)
    parser.add_argument("--publish-markdown", action=argparse.BooleanOptionalAction, help=f"Enable/disable markdown output (default: {DEFAULT_TASK.get('publish_formats', {}).get('markdown')})")
    parser.add_argument("--publish-pdf", action=argparse.BooleanOptionalAction, help=f"Enable/disable PDF output (default: {DEFAULT_TASK.get('publish_formats', {}).get('pdf')})")
    parser.add_argument("--publish-docx", action=argparse.BooleanOptionalAction, help=f"Enable/disable DOCX output (default: {DEFAULT_TASK.get('publish_formats', {}).get('docx')})")

    parser.add_argument("--include-human-feedback", action=argparse.BooleanOptionalAction, help=f"Enable/disable human feedback (default: {DEFAULT_TASK.get('include_human_feedback')})")
    parser.add_argument("--follow-guidelines", action=argparse.BooleanOptionalAction, help=f"Enable/disable following guidelines (default: {DEFAULT_TASK.get('follow_guidelines')})")
    parser.add_argument("--model", type=str, help=f"Set the model (default: {DEFAULT_TASK.get('model')})")
    parser.add_argument("--guidelines", nargs="+", type=str, help=f"Set guidelines (default: {DEFAULT_TASK.get('guidelines')})")
    parser.add_argument("--verbose", action=argparse.BooleanOptionalAction, help=f"Enable/disable verbose output (default: {DEFAULT_TASK.get('verbose')})")

    # Add arguments for API keys
    parser.add_argument("--openai-api-key", type=str, help="Set the OpenAI API key.")
    parser.add_argument("--tavily-api-key", type=str, help="Set the Tavily API key.")

    args = parser.parse_args()

    # --- API Key Handling ---
    openai_api_key = args.openai_api_key or os.environ.get("OPENAI_API_KEY")
    tavily_api_key = args.tavily_api_key or os.environ.get("TAVILY_API_KEY")

    keys_obtained_interactively = {}

    if not openai_api_key:
        openai_api_key = input("Please enter your OPENAI_API_KEY: ")
        keys_obtained_interactively["OPENAI_API_KEY"] = openai_api_key

    if not tavily_api_key:
        tavily_api_key = input("Please enter your TAVILY_API_KEY: ")
        keys_obtained_interactively["TAVILY_API_KEY"] = tavily_api_key

    # Write interactively obtained keys to .env file
    if keys_obtained_interactively:
        write_keys_to_env(keys_obtained_interactively)
        # Reload environment variables to include the newly written keys
        load_dotenv(override=True)

    # Ensure keys are available in environment for subsequent calls
    os.environ["OPENAI_API_KEY"] = openai_api_key
    os.environ["TAVILY_API_KEY"] = tavily_api_key
    # --- End API Key Handling ---


    # Load and assemble the task configuration based on the hierarchy
    task_config = load_task_config(args)

    # Ensure query is present after loading config
    if not task_config.get('query'):
        print("Error: No research query provided. Please specify a query via argument or in the task config.")
        sys.exit(1)

    # Instantiate and run the ChiefEditorAgent
    chief_editor = ChiefEditorAgent(task_config)
    print(f"Starting research for query: {task_config['query']}")
    research_report = await chief_editor.run_research_task(task_id=uuid.uuid4())

    if research_report is None:
        print("Error: Research task failed and returned None.")
        return # Exit the main function

    # Handle output (e.g., write to file)
    output_folder = task_config.get('output_folder', 'outputs')
    os.makedirs(output_folder, exist_ok=True)
    output_filename = task_config.get('output_file', f"multi_agent_report_{uuid.uuid4()}.md")
    output_path = os.path.join(output_folder, output_filename)

    # Determine publish formats - default to markdown if not specified
    publish_formats = task_config.get('publish_formats', {'markdown': True})

    # Basic handling for writing the report based on formats
    if publish_formats.get('markdown'):
        md_output_path = os.path.splitext(output_path)[0] + ".md"
        with open(md_output_path, "w", encoding='utf-8') as f:
            # Ensure research_report['report'] is not None before writing
            report_content = research_report.get('report') if research_report else "Research report content not available."
            f.write(report_content)
        print(f"Multi-agent report (Markdown) written to {md_output_path}")

    # Add logic here for PDF and DOCX if the ChiefEditorAgent returns them or if there's a separate publishing step

def write_keys_to_env(keys):
    """
    Writes or updates API keys in a .env file in the ./gpt-researcher/ directory.
    """
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    env_vars = {}

    # Read existing .env file if it exists
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    key, value = line.split('=', 1)
                    env_vars[key] = value

    # Update with new keys
    env_vars.update(keys)

    # Write back to .env file
    with open(env_path, 'w') as f:
        for key, value in env_vars.items():
            f.write(f"{key}={value}\n")
    print(f"Updated .env file at {env_path}")


if __name__ == "__main__":
    load_dotenv()
    asyncio.run(main())
'@

# Write the content to the Multi_Agent_CLI.py file
Set-Content -Path "Multi_Agent_CLI.py" -Value $multiAgentCliContent
Write-Host "Created Multi_Agent_CLI.py from embedded content"

# Determine if we're running from within the gpt-researcher directory or from a parent directory
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
$scriptName = Split-Path -Leaf $scriptPath

# Check if the script is being run from within the gpt-researcher directory
# The directory structure can have either gpt_researcher or gpt-researcher
$isInGptResearcherDir = (Test-Path (Join-Path $scriptDir "gpt_researcher")) -or (Test-Path (Join-Path $scriptDir "gpt-researcher"))

# Debug output
Write-Host "Script directory: $scriptDir"
Write-Host "Running from within gpt-researcher directory: $isInGptResearcherDir"

# Check if gpt_researcher or gpt-researcher directory exists
$gptResearcherPath = ""
if (Test-Path (Join-Path $scriptDir "gpt_researcher")) {
    $gptResearcherPath = "gpt_researcher"
} elseif (Test-Path (Join-Path $scriptDir "gpt-researcher")) {
    $gptResearcherPath = "gpt-researcher"
}

Write-Host "GPT Researcher path: $gptResearcherPath"

# Get absolute paths for PyInstaller
$currentDir = Get-Location
Write-Host "Current directory: $currentDir"

if ($isInGptResearcherDir) {
    # Running from within gpt-researcher directory
    $retrieversPath = Join-Path $scriptDir "$gptResearcherPath\retrievers"
    Write-Host "Retrievers path: $retrieversPath"
    
    # Use absolute paths for PyInstaller
    python -m PyInstaller --onefile Multi_Agent_CLI.py --add-data "$retrieversPath;gpt_researcher/retrievers" --add-data "$(python -c 'import tiktoken; import os; print(os.path.dirname(tiktoken.__file__))');tiktoken" --hidden-import tiktoken --hidden-import=tiktoken_ext.openai_public --hidden-import=tiktoken_ext
} else {
    # Running from parent directory
    $retrieversPath = Join-Path $currentDir "gpt-researcher\$gptResearcherPath\retrievers"
    Write-Host "Retrievers path: $retrieversPath"
    
    # Use absolute paths for PyInstaller
    python -m PyInstaller --onefile ./gpt-researcher/Multi_Agent_CLI.py --add-data "$retrieversPath;gpt_researcher/retrievers" --add-data "$(python -c 'import tiktoken; import os; print(os.path.dirname(tiktoken.__file__))');tiktoken" --hidden-import tiktoken --hidden-import=tiktoken_ext.openai_public --hidden-import=tiktoken_ext
}

# Note: Keeping the terminal open after the executable runs is controlled by the Python script itself,
# not by this build script. You need to add a pause command (like input() or os.system("pause"))
# to the end of gpt-researcher/multi_agents/main.py to keep the terminal open.

# Copy the executable to the original directory
$exePath = Join-Path (Get-Location) "dist\Multi_Agent_CLI.exe"
$destPath = Join-Path (Split-Path -Parent $PSCommandPath) "Multi_Agent_CLI.exe"

if (Test-Path $exePath) {
    Write-Host "Copying executable to: $destPath"
    Copy-Item $exePath $destPath -Force
    Write-Host "Executable copied successfully!"
} else {
    Write-Host "Error: Executable not found at $exePath"
}

# Clean up temporary files
Write-Host "Cleaning up temporary files..."
Set-Location (Split-Path -Parent $PSCommandPath)
Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Cleanup complete"

Write-Host "Build process completed. The executable is available at: $destPath"