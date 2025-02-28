# dart_diff_cli

[![dart_diff_cli](https://img.shields.io/pub/v/dart_diff_cli.svg?label=dart_diff_cli&logo=dart&color=blue&style=for-the-badge)](https://pub.dev/packages/dart_diff_cli)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

A command-line interface for running Flutter and Dart commands efficiently on changed files.

## Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Global Options](#global-options) 
- [Commands](#commands)
  - [exec](#exec)
  - [update](#update)
- [Common Workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)

## Overview

The `dart_diff_cli` tool optimizes your Flutter/Dart development workflow by running commands only on files that have changed. This significantly speeds up testing, analysis, and formatting during development by focusing only on the files that matter.

Key features include:
- Running commands only on changed files
- Automatically identifying corresponding test files
- Supporting both standard projects and Melos-based mono-repos
- Providing detailed logging for troubleshooting

## Installation

Install the latest version:

```bash
dart pub global activate dart_diff_cli
```

Install a specific version:

```bash
dart pub global activate dart_diff_cli <version>
```

> If you haven't already, you might need to
> [set up your path](https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path).

Alternative usage (e.g., in CI environments):

```bash
dart pub global run dart_diff_cli:dart_diff <command> <args>
```

## Global Options

The following options can be used with any command:

| Option      | Alias | Description                                         |
|-------------|-------|-----------------------------------------------------|
| `--version` | `-v`  | Print the current version of the CLI                |
| `--verbose` |       | Enable verbose logging including all shell commands |
| `--help`    | `-h`  | Display help information for commands               |

## Commands

### exec

Executes Flutter/Dart commands on changed files.

```bash
dart_diff exec [options] -- [command] [command-args]
```

**Options:**

| Option          | Alias | Description                           | Default  |
|-----------------|-------|---------------------------------------|----------|
| `--branch`      | `-b`  | Base branch for comparison            | `main`   |
| `--remote`      | `-r`  | Remote repository name                | `origin` |

**Examples:**

**Run tests on changed files**

```bash
# Run tests on changed files compared to main branch
dart_diff exec -- test

# Run tests against a different branch
dart_diff exec -b develop -- test

# Run tests with verbose output
dart_diff exec --verbose -- test
```

**Run analyzer on changed files**

```bash
# Run the analyzer on changed files
dart_diff exec -- analyze

# Run analyzer with specific options
dart_diff exec -- analyze --fatal-infos
```

**Format changed files**

```bash
# Format changed files
dart_diff exec -- format

# Format with specific options
dart_diff exec -- format --set-exit-if-changed
```

### update

Updates the dart_diff_cli to the latest version.

```bash
dart_diff update
```

The command:
1. Checks the current installed version
2. Compares it with the latest version available on pub.dev
3. Updates to the latest version if needed

## Common Workflows

### Speeding up test runs during development

```bash
# Check what files have been modified compared to main
git diff --name-only main

# Run tests only on the modified files
dart_diff exec -- test

# Run tests with coverage
dart_diff exec -- test --coverage
```

### Pre-commit checks

```bash
# Format only changed files
dart_diff exec -- format --set-exit-if-changed

# Analyze only changed files
dart_diff exec -- analyze

# Run tests for changed files
dart_diff exec -- test
```

### CI/CD optimization

```bash
# In your CI pipeline, compare against the target branch
dart_diff exec -b main -- test --no-pub --coverage
```

## Troubleshooting

### Command Not Found

If the `dart_diff` command is not found after installation, ensure that your Dart SDK's bin directory is in your PATH.

For Unix-based systems:
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

For Windows:
```bash
set PATH=%PATH%;%LOCALAPPDATA%\Pub\Cache\bin
```

### No Files to Process

If you see "No files to process" and expect there to be changes, check:

- That you're using the correct base branch with `-b`
- That you have uncommitted changes in your repository
- That the changes include Dart files
- That the file paths are correctly detected

Try running with `--verbose` to see more detailed output.

### Error: Not a git repository

The command must be run from within a Git repository. Change to the root directory of your project.

### Command execution fails

If your command fails to execute:

1. Try running the command directly without dart_diff to see if it works
2. Verify that the command is available in your environment
3. Run with the `--verbose` flag to see detailed logs
4. Check if the specified branch exists and is accessible

## Contributing

Contributions are welcome! Please feel free to:

- Report bugs and issues
- Suggest new features or improvements
- Submit pull requests with bug fixes or features

See the [contributing guidelines](https://github.com/ProjectAJ14/flutter_diff_action/blob/main/CONTRIBUTING.md) for more details.

---

<br></br>
<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action"  alt="contributors"/>
  </a>
</div>
