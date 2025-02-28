# flutter_diff_action

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ProjectAJ14/flutter_diff_action)](https://github.com/ProjectAJ14/flutter_diff_action/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

🎯 Run Flutter commands on changed files with style! ⭐

Originally created by [Ajay Kumar] & [Dipangshu Roy]

## Overview

This project consists of two main components:

1. **GitHub Action**: A GitHub Action that runs Flutter commands only on changed files
2. **Dart CLI Tool**: A standalone CLI tool for running commands on changed files locally

Both components support standard Flutter projects and Melos-based mono-repos, with features like:

- Running tests for changed files and their corresponding test files
- Handling format and analyze commands for changed files
- Supporting Melos workspaces for mono-repo setups
- Working with both Pull Requests and direct pushes

## Quick Start

### Using as GitHub Action

Add the action to your workflow:

```yaml
- name: Run Flutter command
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: "flutter test"
    use-melos: false
```

### Using the CLI Tool

Install the CLI tool:

```bash
dart pub global activate dart_diff_cli
```

Run a command on changed files:

```bash
dart_diff exec -- test
```

## Package Structure

This repository is organized as follows:

- **GitHub Action**: Root directory contains the action configuration
- **CLI Tool**: Located in `packages/dart_diff_cli`

## GitHub Action Usage

### Basic Flutter Project

```yaml
steps:
  - name: Clone repository
    uses: actions/checkout@v4
  - name: Set up Flutter
    uses: subosito/flutter-action@v2
    with:
      flutter-version: 3.19.6

  - name: Run Flutter command
    uses: ProjectAJ14/flutter_diff_action@v1
    with:
      command: "flutter test"
      use-melos: false
```

### Melos-based Mono-repo

```yaml
steps:
  - name: Clone repository
    uses: actions/checkout@v4
  - name: Set up Flutter
    uses: subosito/flutter-action@v2
    with:
      flutter-version: 3.19.6
      
  - name: Install Melos
    run: dart pub global activate melos
    
  - name: Run Flutter command
    uses: ProjectAJ14/flutter_diff_action@v1
    with:
      command: "flutter test"
      use-melos: true
```

## Action Inputs

| Input         | Description                                             | Required | Default |
|---------------|---------------------------------------------------------|----------|---------|
| `command`     | Flutter/Dart command to execute (test, analyze, format) | Yes      | -       |
| `use-melos`   | Whether to use Melos for mono-repo support              | No       | `false` |
| `debug`       | Enable debug output for troubleshooting                 | No       | `false` |

## CLI Tool Usage

For detailed information about using the CLI tool, see the [dart_diff_cli README](packages/dart_diff_cli/README.md).

Basic usage:

```bash
# Run tests on changed files
dart_diff exec -- test

# With verbose output
dart_diff exec --verbose -- test

# Compare against a different branch
dart_diff exec -b develop -- test

# Format changed files
dart_diff exec -- format
```

## Supported Commands

Both the GitHub Action and CLI tool support various Flutter and Dart commands:

- `flutter test` / `flutter test --no-pub --coverage`
- `flutter analyze` / `flutter analyze --fatal-infos`
- `dart format` / `dart format --set-exit-if-changed`

## Full Workflow Example

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

## Contributing

We welcome contributions in various forms:

1. **Code Contributions**
   - Fork the repository
   - Create a feature branch
   - Submit a pull request

2. **Bug Reports and Feature Requests**
   - Use the GitHub Issues section
   - Provide detailed information for bug reports
   - Explain use cases for feature requests

3. **Documentation Improvements**
   - Help improve README, inline documentation, or examples

A big thank you to all our contributors! 🙌

<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action" alt="contributors"/>
  </a>
</div>

## Related Documentation

- [Changelog](CHANGELOG.md)
- [License](LICENSE)
- [CLI Tool Documentation](packages/dart_diff_cli/README.md)

[Ajay Kumar]: https://github.com/ProjectAJ14
[Dipangshu Roy]: https://github.com/droyder7