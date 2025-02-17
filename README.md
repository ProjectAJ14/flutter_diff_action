# flutter_diff_action

[![GitHub release (latest by date)](https://img.shields.io/github/v/release/ProjectAJ14/flutter_diff_action)](https://github.com/ProjectAJ14/flutter_diff_action/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

🎯 Run Flutter commands on changed files with style! ⭐

Originally created by [Ajay Kumar] & [Dipangshu Roy]

## Overview

This action runs Flutter commands (test, analyze, format) only on changed files in your project. It supports both standard Flutter projects and Melos-based mono-repos. The action is smart enough to:

- Run tests for changed files and their corresponding test files
- Handle format and analyze commands for changed files
- Support Melos workspaces for mono-repo setups
- Work with both Pull Requests and direct pushes

## Usage

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

## Inputs

| Input         | Description                                             | Required | Default |
|---------------|---------------------------------------------------------|----------|---------|
| `command`     | Flutter/Dart command to execute (test, analyze, format) | Yes      | -       |
| `use-melos`   | Whether to use Melos for mono-repo support              | No       | `false` |
| `debug`       | Enable debug output for troubleshooting                 | No       | `false` |
| `base-branch` | Base branch to compare changes against                  | No       | `main`  |

## Supported Commands

The action supports various Flutter and Dart commands:

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

## Related Documentation

- [Changelog](CHANGELOG.md)
- [License](LICENSE)

## Contributing

We welcome contributions in various forms:

- Proposing new features or enhancements
- Reporting and fixing bugs
- Engaging in discussions to help make decisions
- Improving documentation
- Sending Pull Requests

A big thank you to all our contributors! 🙌

<div align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/graphs/contributors">
    <img src="https://contrib.rocks/image?repo=ProjectAJ14/flutter_diff_action" alt="contributors"/>
  </a>
</div>

[Ajay Kumar]: https://github.com/ProjectAJ14
[Dipangshu Roy]: https://github.com/droyder7
```