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
    log_info "Script execution completed"
}

# Execute main function with all arguments
main "$@"