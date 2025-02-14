#!/bin/bash

# Usage: ./diff_command.sh <COMMAND> <USE_MELOS>

set -e  # Exit on any error

COMMAND=$1
USE_MELOS=${2:-false}  # Use provided value or default to false if not specified


# Validate required parameters
if [ -z "$COMMAND" ]; then
  echo "Error: COMMAND is required"
  exit 1
fi

# Validate optional parameters

if [ "$USE_MELOS" != true ] && [ "$USE_MELOS" != false ]; then
  echo "Error: USE_MELOS must be 'true' or 'false'"
  exit 1
fi


echo "Running command: $COMMAND"
