# dart_diff_cli

Run Flutter/Dart commands with diff checking capabilities.

## Overview

`dart_diff_cli` is a command-line tool that helps you run Flutter or Dart commands only on changed files in your project. 
This makes your development workflow faster by focusing commands like testing, analysis, and formatting only on files that have changed.

## Installation

### From pub.dev

```bash
dart pub global activate dart_diff_cli
```

### From Source

```bash
# Clone the repository
git clone https://github.com/ProjectAJ14/flutter_diff_action.git

# Navigate to the package directory
cd flutter_diff_action/packages/dart_diff_cli

# Activate the package locally
dart pub global activate --source path .
```

## Usage

### Basic Command Structure

```bash
dart_diff exec [options] -- [command] [command-options]
```

### Options

- `-b, --branch`: Specify the base branch to compare against (default: `main`)
- `-r, --remote`: Specify the remote repository (default: `origin`)
- `-f, --flutter`: Run commands with Flutter instead of Dart
- `--verbose`: Enable verbose logging for detailed output

### Examples

#### Run tests on changed files

```bash
# Run tests on changed files compared to main branch
dart_diff exec -- test

# Run Flutter tests on changed files
dart_diff exec -f -- test

# Run tests against a different branch
dart_diff exec -b develop -- test

# Run tests with verbose output
dart_diff exec --verbose -- test
```

#### Run analyzer on changed files

```bash
# Run the analyzer on changed files
dart_diff exec -- analyze

# Run Flutter analyzer on changed files
dart_diff exec -f -- analyze
```

#### Format changed files

```bash
# Format changed files
dart_diff exec -- format
```

## Troubleshooting

### Command Not Found

If the `dart_diff` command is not found after installation, ensure that your Dart SDK's bin directory is in your PATH.

### No Files to Process

If you see "No files to process" and you expect there to be changes, check:
- That you're using the correct base branch with `-b`
- That you have uncommitted changes in your repository
- That the changes include Dart files

### Error: Not a git repository

The command needs to be run from within a Git repository. Change to the root directory of your project.

## Updating

To update to the latest version:

```bash
dart_diff update
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.