# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter/Dart tooling project that provides efficient diff-based command execution for Flutter/Dart projects. It consists of two main components:

1. **GitHub Action** (`action.yaml`): For CI/CD pipelines to run commands only on changed files
2. **Dart CLI Tool** (`packages/dart_diff_cli/`): A standalone CLI for local development

Both tools intelligently identify changed files via git diff and execute commands only on affected files, supporting both single projects and Melos mono-repo setups.

## Architecture

### Repository Structure
- **Root**: Contains GitHub Action definition (`action.yaml`) and workspace configuration (`melos.yaml`)
- **`packages/dart_diff_cli/`**: Core Dart CLI package with executable `dart_diff`
- **`example/`**: Contains sample Flutter projects (simple_app, super_app with mono-repo structure)
- **`tools/`**: Contains utility scripts like `update_cli_version.dart`

### Core Components
- **ExecCommand** (`packages/dart_diff_cli/lib/src/commands/exec_command.dart`): Main command that handles file diffing and command execution
- **Git Utils** (`packages/dart_diff_cli/lib/src/utils/git_utils.dart`): Git operations for finding changed files
- **Common Utils** (`packages/dart_diff_cli/lib/src/utils/common_utils.dart`): Project detection and test file mapping
- **PubspecUtils** (`packages/dart_diff_cli/lib/src/utils/pubspec_utils.dart`): Parsing and comparing pubspec.yaml files for dependency changes
- **DependencyAnalyzer** (`packages/dart_diff_cli/lib/src/utils/dependency_analyzer.dart`): Analyzing Dart files to find dependency usage

### Key Features
- Git diff analysis to identify changed files
- **Dependency change detection**: Detects changes in pubspec.yaml and finds files using those dependencies
- Automatic test file discovery for source files (`lib/` → `test/` with `_test.dart` suffix)
- Melos workspace support for mono-repositories
- Flexible command execution on filtered file sets
- Support for both regular and dev dependency tracking

## Common Development Commands

### Workspace Management (Melos)
```bash
# Install melos globally
dart pub global activate melos

# Bootstrap workspace
melos bootstrap

# Run version update (triggers post-hook)
melos version

# Run linting across all packages
melos run lint
```

### Build and Test
```bash
# From dart_diff_cli package directory
dart pub get
dart test
dart run build_runner build

# Run specific test
dart test test/src/commands/exec_command_test.dart

# Test with coverage
dart test --coverage=coverage
```

### Linting and Analysis
```bash
# Lint command (from melos.yaml)
dart format . --set-exit-if-changed && flutter analyze --fatal-infos .

# From individual package
flutter analyze --fatal-infos .
dart format . --set-exit-if-changed
```

### CLI Usage
```bash
# Activate CLI globally
dart pub global activate --source path packages/dart_diff_cli

# Basic exec command
dart_diff exec -- flutter test

# With custom branch/remote
dart_diff exec --branch develop --remote upstream -- flutter analyze

# Enable dependency change detection
dart_diff exec --include-dependency-tests -- flutter test

# With custom dependency scan paths
dart_diff exec --include-dependency-tests --dependency-scan-depth "lib/,test/,bin/" -- flutter test

# Using short alias
ddf exec -- dart format .
```

### GitHub Action Integration
The action automatically activates the CLI and runs commands with diff filtering:
```yaml
# Basic usage
- uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
    use-melos: true
    branch: ${{ github.base_ref }}

# With dependency change detection
- uses: ProjectAJ14/flutter_diff_action@v1
  with:
    command: 'flutter test'
    include-dependency-tests: true
    dependency-scan-depth: 'lib/,test/'
    use-melos: true
    branch: ${{ github.base_ref }}
```

## Project-Specific Notes

- Uses `mason_logger` for consistent logging across all components
- Uses `pubspec_parse` for parsing and comparing pubspec.yaml files
- Supports both `dart_diff` and `ddf` as executable aliases
- Test files follow the pattern: `lib/foo.dart` → `test/foo_test.dart`
- Includes version verification tests that should only run during PRs
- The CLI automatically detects Flutter/Dart projects by checking for `pubspec.yaml`
- Git operations require the current directory to be within a git repository

## Dependency Change Detection

### How It Works
1. **Detects pubspec.yaml changes**: Identifies modified pubspec.yaml files in git diff
2. **Compares dependencies**: Uses `pubspec_parse` to compare current vs previous dependencies
3. **Finds affected files**: Scans Dart files for import statements matching changed dependencies
4. **Includes corresponding tests**: Automatically finds and includes test files for affected source files

### Configuration Options
- `--include-dependency-tests`: Enable the feature (default: false)
- `--dependency-scan-depth`: Directories to scan (default: "lib/,test/")

### Supported Dependency Types
- Regular dependencies (`dependencies:`)
- Dev dependencies (`dev_dependencies:`)
- All dependency types: hosted, git, path, SDK

### Mono-repo Considerations
- Processes each package's pubspec.yaml independently
- Respects package boundaries when finding affected files
- Works seamlessly with Melos `--diff` functionality
- Handles cross-package dependencies correctly