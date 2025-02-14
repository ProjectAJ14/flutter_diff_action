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
USE_MELOS="false"
DEBUG=false

# Function to display usage information
show_usage() {
    echo "Usage: $0 [-n command] [-f use_melos] [-p] [-h]"
    echo "Options:"
    echo "  -n    Flutter command to execute"
    echo "  -f    Use Melos (true/false)"
    echo "  -p    Print debug information"
    echo "  -h    Show this help message"
    exit 1
}

# Parse command line options
while getopts "n:f:ph" opt; do
    case $opt in
        n) COMMAND="$OPTARG" ;;
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
    echo "- Use Melos: $USE_MELOS"
fi

# Execute command
echo "Running command: $COMMAND"
if [ "$USE_MELOS" = "true" ]; then
    echo "Using Melos for execution"
    # Add Melos-specific command execution here
else
    # Add standard command execution here
    eval "$COMMAND"
fi