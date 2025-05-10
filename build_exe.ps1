Remove-Item ./gpt-researcher/multi_agents/task.json
# PowerShell script to build the Multi-Agent-CLI executable
# This script uses PyInstaller to create a standalone executable.

# Navigate to the directory containing the main script if necessary
# Set-Location ./gpt-researcher/multi_agents

# Run PyInstaller
# Run PyInstaller
# Add --add-data "path/to/site-packages/tiktoken;tiktoken" to include tiktoken data files.
# You may need to adjust the 'path/to/site-packages' based on your Python environment.
# Set environment variables for API keys
$env:PYTHONIOENCODING = "utf-8"

python -m PyInstaller --onefile gpt-researcher/Multi_Agent_CLI.py --add-data "gpt-researcher/gpt_researcher/retrievers;gpt_researcher/retrievers" --add-data "$(python -c 'import tiktoken; import os; print(os.path.dirname(tiktoken.__file__))');tiktoken" --hidden-import tiktoken --hidden-import=tiktoken_ext.openai_public --hidden-import=tiktoken_ext

# Note: Keeping the terminal open after the executable runs is controlled by the Python script itself,
# not by this build script. You need to add a pause command (like input() or os.system("pause"))
# to the end of gpt-researcher/multi_agents/main.py to keep the terminal open.