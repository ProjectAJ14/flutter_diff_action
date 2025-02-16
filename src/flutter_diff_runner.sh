#!/bin/bash

set -e  # Exit on any error

# Initialize variables with defaults
COMMAND=""
BASE_BRANCH="origin/main"
DEBUG=false

# Function to display usage information
show_usage() {
    echo "Usage: $0 [-n command] [-b base_branch] [-f use_melos] [-p] [-h]"
    echo "Options:"
    echo "  -n    Flutter command to execute"
    echo "  -b    Base branch name to compare diff with"
    echo "  -p    Print debug information"
    echo "  -h    Show this help message"
    exit 1
}

# Parse command line options
while getopts "n:b:f:ph" opt; do
    case $opt in
        n) COMMAND="$OPTARG" ;;
        b) BASE_BRANCH="$OPTARG" ;;
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
MODIFIED_FILES=$(git diff $BASE_BRANCH...HEAD --name-only | grep '\.dart$')

if [ -z "$MODIFIED_FILES" ]; then
  echo "No Dart files were modified."
  exit 0
fi

FILES=""
# Initialize an array to store valid test files
TEST_FILES=()

# Function to calculate the corresponding test file path
calculate_test_file() {
  local file_path=$1
  if [[ $file_path == lib/* ]]; then
    echo "${file_path/lib\//test/}" | sed 's/\.dart$/_test.dart/'
  else
    echo "${file_path%.dart}_test.dart"
  fi
}

# Collect files & test files (existing ones and their respective test counterparts)
for FILE in $MODIFIED_FILES; do
  # Check if the file is within the current subdirectory
  if [[ $FILE == $RELATIVE_BASE_PATH/* ]]; then
    # Calculate the relative path to the current directory
    RELATIVE_PATH=${FILE#$RELATIVE_BASE_PATH/}

    # Check if the file exists
    if [[ -f $RELATIVE_PATH ]]; then
      FILES+="$RELATIVE_PATH "
      if [[ $RELATIVE_PATH == *_test.dart ]]; then
        # Directly add test files
        TEST_FILES+=("$RELATIVE_PATH")
      else
        # Calculate and check the existence of the corresponding test file
        TEST_FILE=$(calculate_test_file "$RELATIVE_PATH")
        if [[ -f $TEST_FILE ]]; then
          TEST_FILES+=("$TEST_FILE")
        else
          echo "No test file found for $RELATIVE_PATH. Skipping..."
        fi
      fi
    else
      echo "File $RELATIVE_PATH does not exist in the current directory. Skipping..."
    fi
  else
    echo "File $FILE is outside the current subdirectory. Skipping..."
  fi
done

echo "$FILES"

if [[ "$COMMAND" == *"test"* ]]; then
  COMMAND+=" $TEST_FILES"
else
  COMMAND+=" $FILES"
fi

eval "$COMMAND"

# Capture the exit code of flutter test
EXIT_CODE=$?
exit $EXIT_CODE