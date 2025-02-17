#!/bin/bash

# Constants for colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default values
COMMAND=""
USE_MELOS="false"
DEBUG="false"
BASE_BRANCH="${BASE_BRANCH:-origin/main}"

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG}" = "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Usage information
usage() {
    echo -e "${BLUE}Usage: ./script.sh -n <command> -f <use_melos> [-p debug]${NC}"
    echo "Parameters:"
    echo "  -n command   - Flutter/Dart command to execute"
    echo "  -f use_melos - Use Melos (true/false)"
    echo "  -p          - Enable debug mode"
    exit 1
}

# Validate parameters
validate_parameters() {
    if [[ -z "$COMMAND" ]]; then
        log_error "Command is required"
        usage
    fi
}

# Function to get changed files
get_changed_files() {
    log_debug "Getting changed files..."
    git diff --name-only "$BASE_BRANCH" | grep "\.dart$" || true
}

# Function to get test files for changed lib files
get_test_files() {
    local LIB_FILES=$1
    local TEST_FILES=""

    log_debug "Finding test files for changed lib files..."
    for lib_file in $LIB_FILES; do
        if [[ $lib_file == *"/lib/"* ]]; then
            potential_test_file=$(echo $lib_file | sed 's/lib\//test\//' | sed 's/\.dart$/_test.dart/')
            log_debug "Checking for test file: $potential_test_file"

            if [ -f "$potential_test_file" ]; then
                log_debug "Found test file: $potential_test_file"
                TEST_FILES="$TEST_FILES$WORKSPACE_ROOT/$potential_test_file"$'\n'
            fi
        fi
    done
    echo "$TEST_FILES"
}

# Function to prepare files for processing
prepare_files() {
    local FILES_FILE=$1

    if [[ "$COMMAND" == *"test"* ]]; then
        log_info "Preparing test files..."
        prepare_test_files "$FILES_FILE"
    else
        log_info "Preparing changed files..."
        prepare_changed_files "$FILES_FILE"
    fi
}

prepare_test_files() {
    local FILES_FILE=$1

    # Get changed files
    CHANGED_FILES=$(get_changed_files)

    # Get test files for changed lib files
    TEST_FILES=$(get_test_files "$CHANGED_FILES")

    # Get directly changed test files
    CHANGED_TESTS=$(echo "$CHANGED_FILES" | grep "test/.*_test.dart$" || true)

    # Combine and save all test files
    echo "$TEST_FILES" > "$FILES_FILE"
    while IFS= read -r test; do
        if [ ! -z "$test" ]; then
            echo "$WORKSPACE_ROOT/$test" >> "$FILES_FILE"
        fi
    done <<< "$CHANGED_TESTS"
}

prepare_changed_files() {
    local FILES_FILE=$1

    CHANGED_FILES=$(get_changed_files)
    while IFS= read -r file; do
        if [ ! -z "$file" ]; then
            echo "$WORKSPACE_ROOT/$file" >> "$FILES_FILE"
        fi
    done <<< "$CHANGED_FILES"
}

# Function to execute commands
execute_commands() {
    local FILES_FILE=$1
    local TEMP_SCRIPT=$2

    if [ "$USE_MELOS" = "true" ]; then
        log_info "Executing with Melos..."
        melos exec --diff="$BASE_BRANCH" --dir-exists="lib" --flutter -- "$TEMP_SCRIPT" "$FILES_FILE"
    else
        log_info "Executing without Melos..."
        "$TEMP_SCRIPT" "$FILES_FILE"
    fi
}

# Main script execution
main() {
    # Parse command line arguments
    while getopts "n:f:p" opt; do
        case $opt in
            n) COMMAND="$OPTARG"      ;;
            f) USE_MELOS="$OPTARG"    ;;
            p) DEBUG="true"           ;;
            *) usage                  ;;
        esac
    done

    log_info "Starting script execution"
    log_debug "Command: $COMMAND"
    log_debug "Use Melos: $USE_MELOS"
    log_debug "Base Branch: $BASE_BRANCH"

    # Validate parameters
    validate_parameters

    WORKSPACE_ROOT=$(pwd)
    log_debug "Workspace root: $WORKSPACE_ROOT"

    # Prepare files
    FILES_FILE=$(mktemp)
    prepare_files "$FILES_FILE"

    if [ ! -s "$FILES_FILE" ]; then
        log_warning "No files to process"
        rm "$FILES_FILE"
        exit 0
    fi

    log_debug "Files to process:"
    log_debug "$(cat "$FILES_FILE")"

    # Create execution script
    TEMP_SCRIPT=$(mktemp)
    cat << EOF > "$TEMP_SCRIPT"
#!/bin/bash
echo "Current directory: \$PWD"
while IFS= read -r file; do
    if [[ "\$file" == "\$PWD"* ]]; then
        echo "Running command: $COMMAND \$file"
        $COMMAND "\$file"
    else
        log_debug "Path mismatch - File: \$file"
        log_debug "               - PWD: \$PWD"
    fi
done < "\$1"
EOF

    chmod +x "$TEMP_SCRIPT"

    # Execute commands
    execute_commands "$FILES_FILE" "$TEMP_SCRIPT"

    # Cleanup
    rm "$TEMP_SCRIPT" "$FILES_FILE"
    log_info "Script execution completed"
}

# Execute main function with all arguments
main "$@"