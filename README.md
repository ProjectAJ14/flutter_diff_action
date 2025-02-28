<p align="center">
  <h1 align="center">Flutter Diff Action</h1>
  <p align="center">Run Flutter/Dart commands on changed files with intelligence</p>
</p>

<p align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/releases"><img src="https://img.shields.io/github/v/release/ProjectAJ14/flutter_diff_action?style=for-the-badge&logo=github&color=blue" alt="GitHub Release"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License: MIT"></a>
</p>

This project optimizes Flutter/Dart development workflows by running commands only on changed files, significantly speeding up CI/CD pipelines and local development.

## Table of Contents

- [Overview](#overview)
- [Project Components](#project-components)
- [GitHub Action](#github-action)
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

## GitHub Action

The GitHub Action component lets you run Flutter commands only on changed files in your CI/CD workflows.

### Setup

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: subosito/flutter-action@v2
  
  - name: Run on changed files
    uses: ProjectAJ14/flutter_diff_action@v1
    with:
      command: 'flutter test'
      branch: ${{ github.base_ref }}
```

### Configuration Options

| Parameter     | Description                         | Required | Default   |
|---------------|-------------------------------------|----------|-----------|
| `command`     | Command to execute on changed files | Yes      | -         |
| `use-melos`   | Enable Melos support for mono-repos | No       | `false`   |
| `working-dir` | Working directory for the command   | No       | `.`       |
| `branch`      | Base branch for comparison          | No       | `main`    |
| `remote`      | Remote repository name              | No       | `origin`  |
| `debug`       | Show verbose debug output           | No       | `false`   |

### Examples

#### Basic Test Workflow

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
```

#### With Analysis

```yaml
- name: Analyze & test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter analyze'
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

#### With Custom Base Branch

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
    branch: 'develop'
```

#### With Custom Remote

```yaml
- name: Test changed files
  uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
    remote: 'upstream'
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
          branch: ${{ github.base_ref }}
          use-melos: true
          debug: true
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

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgements

Originally created by [Ajay Kumar] & [Dipangshu Roy].

Special thanks to all contributors who have helped improve this project.

<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action" alt="contributors"/>
  </a>
</div>

[Ajay Kumar]: https://github.com/ProjectAJ14
[Dipangshu Roy]: https://github.com/droyder7