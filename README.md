<p align="center">
  <h1 align="center">Flutter Diff Action</h1>
  <p align="center">Run Flutter commands on changed files with intelligence</p>
</p>

<p align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/releases"><img src="https://img.shields.io/github/v/release/ProjectAJ14/flutter_diff_action?style=for-the-badge&logo=github&color=blue" alt="GitHub Release"></a>
  <a href="https://pub.dev/packages/dart_diff_cli"><img src="https://img.shields.io/pub/v/dart_diff_cli.svg?style=for-the-badge&logo=dart&color=blue" alt="Pub Version"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License: MIT"></a>
</p>

This project optimizes Flutter/Dart development workflows by running commands only on changed files, significantly speeding up CI/CD pipelines and local development.

## Table of Contents

- [Overview](#overview)
- [Project Components](#project-components)
- [Quick Start Guide](#quick-start-guide)
- [GitHub Action](#github-action)
- [CLI Tool](#cli-tool)
- [How It Works](#how-it-works)
- [Contributing](#contributing)

## Overview

Flutter Diff Action provides tools to make your development and CI workflows more efficient by focusing on what's changed:

- ⚡ **Faster workflows**: Run commands only on files that have changed
- 🧪 **Smarter testing**: Automatically find and run corresponding test files
- 📦 **Mono-repo friendly**: Full support for Melos-based workspaces
- 🛠️ **Flexible**: Works with testing, analysis, and formatting commands

## Project Components

This repository contains two complementary tools:

1. **GitHub Action**: For CI/CD pipelines to efficiently run commands on changed files
2. **Dart CLI Tool**: For local development to speed up testing and analysis workflows

Both tools intelligently identify changes, run commands only on affected files, and support mono-repo setups.

## Quick Start Guide

### GitHub Action

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: "flutter test"
    use-melos: false
```

### CLI Tool

```bash
# Install
dart pub global activate dart_diff_cli

# Run tests only on changed files
dart_diff exec -- test
```

## GitHub Action

The GitHub Action component lets you run Flutter commands only on changed files in your CI/CD workflows.

### Setup

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: '3.19.6'
  
  - name: Run on changed files
    uses: ProjectAJ14/flutter_diff_action@v1
    with:
      command: 'flutter test'
```

### Configuration Options

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `command` | Command to execute on changed files | Yes | - |
| `use-melos` | Enable Melos support for mono-repos | No | `false` |
| `debug` | Show verbose debug output | No | `false` |

### Examples

#### Basic Test Workflow

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
```

#### With Analysis & Coverage

```yaml
- name: Analyze & test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter analyze && flutter test --coverage'
    debug: true
```

#### For Mono-Repos

```yaml
- name: Setup Melos
  run: dart pub global activate melos

- name: Test changed packages
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
    use-melos: true
```

## CLI Tool

For detailed information about using the CLI tool, see the [dart_diff_cli README](packages/dart_diff_cli/README.md).

### Installation

```bash
dart pub global activate dart_diff_cli
```

> If you haven't already, you might need to
> [set up your path](https://dart.dev/tools/pub/cmd/pub-global#running-a-script-from-your-path).

### Basic Usage

```bash
# Run tests
dart_diff exec -- test

# Run analyzer
dart_diff exec -- analyze

# Format changed files
dart_diff exec -- format
```

### Advanced Options

```bash
# Specify base branch for comparison
dart_diff exec -b develop -- test

# Enable verbose logging
dart_diff exec --verbose -- test

# Run commands with additional options
dart_diff exec -- analyze --fatal-infos
```

## Common Workflows

### CI/CD Pipeline

```yaml
name: Flutter CI

on:
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.6'
      
      - name: Run Tests
        uses: ProjectAJ14/flutter_diff_action@v1
        with:
          command: 'flutter test --no-pub --coverage'
          use-melos: true
          debug: true
```

### Local Development

```bash
# Pre-commit checks
dart_diff exec -- format --set-exit-if-changed
dart_diff exec -- analyze
dart_diff exec -- test

# Focus on specific branch changes
dart_diff exec -b feature/login -- test
```

## How It Works

1. Determines changed files by comparing against the base branch
2. Filters the list to relevant Dart/Flutter files
3. For test commands, finds corresponding test files
4. Executes the requested command only on the affected files
5. Provides detailed output of results

## Contributing

Contributions are welcome and appreciated! Here's how you can contribute:

- **Report bugs**: Open an issue describing the bug and how to reproduce it
- **Suggest features**: Open an issue describing your idea and its benefits
- **Submit PRs**: Implement bug fixes or features (please open an issue first)
- **Improve docs**: Fix typos, clarify explanations, add examples

Please see our [contributing guidelines](CONTRIBUTING.md) for more details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

Special thanks to all contributors who have helped improve this project.

<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action" alt="contributors"/>
  </a>
</div>
