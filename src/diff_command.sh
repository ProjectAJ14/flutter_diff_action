#!/bin/bash

# Script: diff_command.sh
# Description: Executes Flutter commands with optional Melos support
# Usage: ./diff_command.sh -n <command> -f <use_melos>
#
# Options:
#   -n    Flutter command to execute
#   -f    Use Melos (true/false)
#   -p    Print debug information
#   -h    Show this help message

set -e  # Exit on any error

# Initialize variables with defaults
COMMAND=""
BASE_BRANCH="origin/main"
USE_MELOS="false"
DEBUG=false

# Function to display usage information
show_usage() {
    echo "Usage: $0 [-n command] [-b base_branch] [-f use_melos] [-p] [-h]"
    echo "Options:"
    echo "  -n    Flutter command to execute"
    echo "  -b    Base branch name to compare diff with"
    echo "  -f    Use Melos (true/false)"
    echo "  -p    Print debug information"
    echo "  -h    Show this help message"
    exit 1
}

# Parse command line options
while getopts "n:b:f:ph" opt; do
    case $opt in
        n) COMMAND="$OPTARG" ;;
        b) BASE_BRANCH="$OPTARG" ;;
        f) USE_MELOS="$OPTARG" ;;
        p) DEBUG=true ;;
        h) show_usage ;;
        ?) show_usage ;;
    esac
done

# Validate required parameters
if [ -z "$COMMAND" ]; then
    echo "Error: Command (-n) is required"
    show_usage
fi

# Validate USE_MELOS parameter
USE_MELOS=$(echo "$USE_MELOS" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
if [ "$USE_MELOS" != "true" ] && [ "$USE_MELOS" != "false" ]; then
    echo "Error: Use Melos (-f) must be 'true' or 'false'"
    show_usage
fi

# Debug output if requested
if [ "$DEBUG" = true ]; then
    echo "Configuration:"
    echo "- Command: $COMMAND"
    echo "- Base Branch: $BASE_BRANCH"
    echo "- Use Melos: $USE_MELOS"
fi

# Execute command
echo "Running command: $COMMAND"
if [ "$USE_MELOS" = "true" ]; then
    echo "Using Melos for execution"
    # Add Melos-specific command execution here
    if ! command -v melos &> /dev/null then
        echo "Melos not found. Installing Melos..."
        # dart pub global activate melos
    else
        echo "Melos is already installed. Version: $(melos --version)"
    fi
else
    # Add standard command execution here
    eval "$COMMAND"
fi

# Get the current directory (subdirectory) path
BASE_PATH=$(pwd)

# Get the repository root path
REPO_ROOT=$(git rev-parse --show-toplevel)

# Calculate the relative path of the current directory to the repository root
RELATIVE_BASE_PATH=${BASE_PATH#$REPO_ROOT/}

echo "Current directory: $BASE_PATH"
echo "Repository root: $REPO_ROOT"
echo "Relative base path: $RELATIVE_BASE_PATH"

# Fetch the list of modified Dart files relative to the git root
MODIFIED_FILES=$(git diff --name-only $BASE_BRANCH...HEAD | grep '\.dart$')

if [ -z "$MODIFIED_FILES" ]; then
  echo "No Dart files were modified."
  exit 0
fi

echo "Modified Dart files:"
echo "$MODIFIED_FILES"

# Capture the exit code of command
EXIT_CODE=$?
exit $EXIT_CODE