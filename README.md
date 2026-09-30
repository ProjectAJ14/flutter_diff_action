<p align="center">
  <a href="https://pub.dev/packages/dart_diff_cli">
    <img src="packages/dart_diff_cli/images/dart-diff-cli-icon-v2.svg" alt="Dart Diff CLI icon" width="128" height="128" />
  </a>
</p>

<p align="center">
  <h1 align="center">Flutter Diff Action</h1>
  <p align="center">Run Dart/Flutter tests, analysis and formatting only for what a change affects</p>
</p>

<p align="center">
  <a href="https://github.com/ProjectAJ14/flutter_diff_action/releases"><img src="https://img.shields.io/github/v/release/ProjectAJ14/flutter_diff_action?style=for-the-badge&logo=github&color=blue" alt="GitHub Release"></a>
  <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge" alt="License: MIT"></a>
</p>

Runs `flutter test` on the tests that use the changed code, `flutter analyze` only in the packages a change reaches, and `dart format` on the changed files, in CI (GitHub Action) or locally (CLI).

## Table of Contents

- [Overview](#overview)
- [Project Components](#project-components)
- [When not to use it](#when-not-to-use-it)
- [GitHub Action](#github-action)
- [How It Works](#how-it-works)
- [Contributing](#contributing)

## Overview

Flutter Diff Action provides tools to make your development and CI workflows more efficient by focusing on what's changed:

- 🧪 **Affected tests**: runs every test that imports a changed file, directly or through other files, across local packages
- 📦 **Mono-repo friendly**: Melos and pub workspaces, including the packages that depend on a changed one
- 🔁 **Pull requests and pushes**: compares with the PR base, the merge group base, or the commit before a push
- 📤 **Outputs and summary**: what ran and why, as step outputs (JSON) and a job summary

## Project Components

This repository contains two complementary tools:

1. **GitHub Action**: For CI/CD pipelines to efficiently run commands on changed files
2. **Dart CLI Tool**: For local development to speed up testing and analysis workflows

Both tools intelligently identify changes, run commands only on affected files, and support mono-repo setups.

## When not to use it

A partial run is only as safe as the rules that pick it. Know these limits:

- **Coverage gates.** A partial test run writes a partial `lcov.info`. Gate on coverage only when the `full-suite` output is `true`, or set `run-all: true` in the job that collects coverage.
- **Tests that don't import what they test.** Tests are picked by following `import`, `export` and `part` directives. A test that reaches code another way (reflection, a generated registry, a file read at runtime) is not picked. List such inputs in `run-all-on`.
- **Codegen.** A change to a model reaches the tests importing it. A generator that reads many libraries (e.g. a DI or router config) is not followed; add its inputs to `run-all-on`.
- **Setup cost.** The Action compiles its CLI once per job (a few seconds, plus `dart pub get` for its dependencies). It pays off when the full suite takes clearly longer than that.

## GitHub Action

The GitHub Action component runs your command only on what a change affects, in CI.

### Requirements

- Flutter 3.27.0 or newer (Dart 3.6 or newer). CI tests the Action on Flutter 3.27.0 and the latest stable.
- Your dependencies installed (`flutter pub get`), so the Action can follow `package:` imports into your local packages.
- A checkout with enough history to find the merge base, e.g. `fetch-depth: 0`. In a shallow clone the Action fetches more history (1 commit, which is enough for a pull request's merge commit, then 100, then 1000); if it still finds no merge base, it warns and compares with the base itself, which also picks up what changed on the base.
- For `use-melos: true`, Melos installed and the workspace set up: `melos bootstrap`, or for a pub workspace `dart pub get` at the root (Melos 6's bootstrap can't link workspace packages that depend on each other).

### Setup

```yaml
on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: subosito/flutter-action@v2
      - run: flutter pub get

      - name: Test what changed
        uses: ProjectAJ14/flutter_diff_action@v2
        with:
          command: 'flutter test'
```

With no `base` or `branch`, a pull request compares with its base branch, a merge queue with its base commit, and a push with the commit before the push. A new branch's first push runs everything; other events compare with `main`.

For security-sensitive workflows, pin the Action to a full commit SHA instead of `@v2`, which moves with every v2 release: `uses: ProjectAJ14/flutter_diff_action@<sha> # v2.x.y`.

### Configuration Options

| Parameter            | Description | Default |
|----------------------|-------------|---------|
| `command`            | Command to run, e.g. `flutter test`. Empty: only set the outputs (see [fan out](#fan-out-a-matrix-per-package)). | `''` |
| `mode`               | What to pass to the command: `test`, `files`, `package` or `auto` (see [How It Works](#how-it-works)). | `auto` |
| `base`               | Commit or ref to compare with, e.g. `${{ github.event.before }}`. | from the event |
| `branch`             | Base branch to compare with, as `<remote>/<branch>`. | from the event, else `main` |
| `remote`             | Remote repository name. | `origin` |
| `run-all`            | Run on everything, without looking at the changes. | `false` |
| `run-all-on`         | Newline-separated globs, relative to the repository root. A changed file matching one runs everything. No spaces. | `''` |
| `use-melos`          | Run in each changed Melos package. | `false` |
| `include-dependents` | With `use-melos`, also run in the packages that depend on a changed package. | `true` |
| `working-dir`        | Working directory for the command. | `.` |
| `debug`              | Show verbose output (`dart_diff --verbose`). | `false` |

`base`, `branch` and `remote` may only contain `A-Za-z0-9._/@+-` and can't start with `-`.

### Outputs

| Output          | Value |
|-----------------|-------|
| `ran`           | `none`, `partial` or `full`. With Melos, `full` only when every package looked at ran in full |
| `full-suite`    | `true` when the command ran on everything |
| `skipped`       | `true` when nothing ran |
| `changed-files` | JSON array of the changed files |
| `files`         | JSON array of the files passed to the command |
| `test-files`    | JSON array of the test files passed to the command |
| `packages`      | JSON array of the package directories where the command ran (or, without a `command`, would run) |

Paths are relative to the repository root. The job summary shows the same, with the reason for each package.

### Examples

#### Analyze and format

```yaml
- name: Analyze affected packages
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter analyze --fatal-infos'

- name: Check formatting of changed files
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'dart format --set-exit-if-changed'
```

`analyze` runs on the whole package (mode `package`), because an error can show up in a file that uses the changed one. `dart format` gets only the changed files (mode `files`).

#### Coverage gate on full runs

```yaml
- name: Test
  id: test
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test --coverage'
    run-all-on: |
      .github/workflows/**
      tool/**

- name: Check coverage
  if: steps.test.outputs.full-suite == 'true'
  run: ./tool/check_coverage.sh
```

#### For Mono-Repos

```yaml
- uses: actions/checkout@v5
  with:
    fetch-depth: 0
- uses: subosito/flutter-action@v2

- name: Set up Melos
  run: |
    dart pub global activate melos
    melos bootstrap   # for a pub workspace, `dart pub get` at the root instead

- name: Test changed packages and their dependents
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test --no-pub'
    use-melos: true
```

In each package, the tests that use a changed file, in that package or in a package it depends on, run. A change to a root file such as `pubspec.lock`, `pubspec.yaml`, `melos.yaml` or `analysis_options.yaml` runs every package in full.

Melos leaves out the workspace root package. If the root has tests of its own, set `useRootAsPackage: true` in the Melos config (the `melos:` key of the root `pubspec.yaml`, or `melos.yaml` on Melos 6); otherwise they never run.

#### Fan out a matrix per package

```yaml
jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      packages: ${{ steps.diff.outputs.packages }}
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: subosito/flutter-action@v2
      - run: dart pub global activate melos && melos bootstrap
      - id: diff
        uses: ProjectAJ14/flutter_diff_action@v2
        with:
          use-melos: true   # no command: only work out the packages

  test:
    needs: changes
    if: needs.changes.outputs.packages != '[]'
    strategy:
      matrix:
        package: ${{ fromJSON(needs.changes.outputs.packages) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
        working-directory: ${{ matrix.package }}
      - uses: ProjectAJ14/flutter_diff_action@v2
        with:
          command: 'flutter test'
          working-dir: ${{ matrix.package }}
```

#### With a custom base

```yaml
- name: Test changes since develop
  uses: ProjectAJ14/flutter_diff_action@v2
  with:
    command: 'flutter test'
    branch: 'develop'
    remote: 'upstream'
```

## How It Works

1. Compiles the `dart_diff` CLI from the Action's own checkout, once per job, so `@v2` (or any tag or SHA) always runs the CLI code of that same tag. Nothing is downloaded from pub.dev except the CLI's dependencies, at the versions pinned in `packages/dart_diff_cli/tool/action.lock`, so a new release of one of them can't change the Action.
2. Finds the files changed against the merge base with the base, plus untracked files, across the repository.
3. Picks what to run, by mode (`auto` picks `test` for `flutter test`, `dart test` and `fvm flutter test`, `package` for `flutter analyze` and `dart analyze`, `files` otherwise):
   - **test**: every `test/**_test.dart` that imports, exports or includes as a part a changed file, directly or through other files, plus changed test files. Imports are followed into local packages (pub workspace members, path dependencies) with `.dart_tool/package_config.json`. A deleted file's importers are followed the same way. The **full** test suite runs instead when:
     - `pubspec.yaml`, `pubspec.lock`, `pubspec_overrides.yaml`, `dart_test.yaml`, `build.yaml` or `l10n.yaml` changed,
     - a root `pubspec.yaml`, `pubspec.lock`, `melos.yaml` or `analysis_options.yaml` in a parent directory changed (the workspace),
     - `flutter_test_config.dart` changed, or a non-Dart file under `test/`, `lib/` or `assets/` (fixtures, goldens, l10n),
     - a changed file matches `run-all-on`, `run-all` is set, or a new branch was pushed,
     - every test is picked anyway (so `full-suite` is `true`),
     - the tests don't fit on one command line.
   - **package**: the command runs, with no files, when a file in the package changed, a file it imports (in another local package) changed, or the workspace changed.
   - **files**: the command runs on the changed Dart files in the package. Long lists are split over several runs to stay under the OS command-line limit; the Action fails if any run fails.
4. The command's exit code is the step's exit code. The outputs and the job summary are written even when the command fails.

With `use-melos: true` the Action runs `git fetch` once, then `melos exec --diff=<base> --include-dependents` runs `dart_diff exec --no-fetch` in each selected package. When a file at the Melos root changed, or `run-all-on` is set, `--diff` is dropped and `dart_diff` decides in every package.

Inputs are passed to the scripts through environment variables, never pasted into them. `command` keeps shell quoting (e.g. `flutter test --plain-name "login flow"`), since it is your own workflow's input; don't build it from untrusted text such as PR titles.

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