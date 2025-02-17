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
BASE_BRANCH="${BASE_BRANCH:-main}"

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


# Main script execution
main() {
    # Parse command line arguments
    while getopts "n:b:f:p" opt; do
        case $opt in
            n) COMMAND="$OPTARG"      ;;
            b) BASE_BRANCH="$OPTARG"  ;;
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

    eval "dart pub global activate -sgit https://github.com/Droyder7/dart_diff"

    DART_DIFF_COMMAND="dart_diff exec -b $BASE_BRANCH -- \"$COMMAND\""

    if [ "$USE_MELOS" == "true" ]; then
        echo "Using Melos for execution"
        # Add Melos-specific command execution here
        if command -v melos &> /dev/null; then
            echo "Melos is already installed. Version: $(melos --version)"
        else
            echo "Melos not found. Installing Melos..."
            eval "dart pub global activate melos"
        fi
        eval "melos exec --diff=$BASE_BRANCH -- $DART_DIFF_COMMAND"
    else
        # Add standard command execution here
        eval "$DART_DIFF_COMMAND"
    fi

    log_info "Script execution completed"
}

# Execute main function with all arguments
main "$@"