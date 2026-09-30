# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two things that ship together:

1. **GitHub Action** (`action.yaml`, composite), three steps: (a) `setup` copies the CLI's `bin/`, `lib/` and `pubspec.yaml` (minus `dev_dependencies`, stripped with `awk`) to `$RUNNER_TEMP/dart_diff`, writes `pubspec_overrides.yaml` with `resolution:` (so it resolves outside the root workspace), `dart pub get` + `dart compile exe`, adds it to `$GITHUB_PATH` (reused within a job for the same action path), and makes a report dir (`mktemp -d`); (b) the run step picks the base (`base` input, else `branch`, else `github.base_ref`, merge group base, push `github.event.before`; all-zero before → `--all`; else `main`), validates base/branch/remote (plain ref characters, no leading `-`) and `mode`, then runs `dart_diff [--verbose] exec --report <dir> ... -- <command>` (`eval`s `$DIFF_COMMAND` so shell quoting works); empty `command` → `--dry-run`. With `use-melos: true` it fetches (and deepens a shallow clone) once, then `melos exec --diff=<ref> [--include-dependents] -- dart_diff exec --no-fetch ...`; `--diff` is dropped when a root-level file changed or `run-all-on` is set, so `dart_diff` decides per package; (c) `report` (`if: always()`) runs `dart_diff report` into `$GITHUB_OUTPUT`/`$GITHUB_STEP_SUMMARY`, which feed the Action's outputs (`ran`, `full-suite`, `skipped`, `changed-files`, `files`, `test-files`, `packages`). All inputs reach the scripts through `env:`. `exec` uses `allowTrailingOptions: false`, because Melos 7 drops the `--` that `melos exec` passes on.
2. **Dart CLI** (`packages/dart_diff_cli`, published to pub.dev as `dart_diff_cli`; executables `dart_diff` and alias `ddf`).

The Action runs the CLI source of the same tag/SHA, so CLI changes are tested by the Action's CI right away. pub.dev is only for people installing the CLI themselves.

## Commands

Root is a pub workspace (`workspace: [packages/dart_diff_cli]`) managed by Melos 7. The Melos config is the `melos:` key in the root `pubspec.yaml`; there is no `melos.yaml`. Root tooling (melos 7) needs Dart 3.9+, while the CLI supports Dart 3.6+. To work on the CLI with an older SDK, put `resolution:` in `packages/dart_diff_cli/pubspec_overrides.yaml` (gitignored) so it resolves on its own.

```bash
dart pub get                    # resolve the workspace (from the root)
dart run melos run lint         # dart format --set-exit-if-changed packages tools + dart analyze --fatal-infos

# CLI tests (run from packages/dart_diff_cli)
dart test
dart test test/src/commands/update_command_test.dart            # single file
dart test --name "some test name"                               # single test
dart run build_runner build --delete-conflicting-outputs        # regenerate lib/src/version.dart
bash tool/coverage.sh           # tests with coverage; fails unless lib/ has 100% line coverage

# Run the CLI locally
dart run bin/dart_diff.dart exec -b main -- flutter test
```

`dart_test.yaml` sets `concurrency: 1` because several tests change `Directory.current`, which the whole process shares. Git tests use `test/helpers/temp_repo.dart` (a temp repo with a bare `origin`); exec tests use a repo-local `git test` alias (so `detectMode` sees a test command) and a temp Dart script instead of `sh`, so they run on Windows too.

The `version-verify` tag (`test/ensure_build_test.dart`) is skipped by default in `dart_test.yaml`. Run it with `dart test --run-skipped -t version-verify`. It checks that build_runner output is committed, and it requires a clean git tree.

## CLI architecture (`packages/dart_diff_cli/lib/src`)

- `command_runner.dart`: `DartDiffCliCommandRunner` (`CompletionCommandRunner`). Handles `--version` / `--verbose`, registers commands, runs a pub.dev update check after every command except `update`. Maps `UsageException`/`FormatException` to 64 and `ProcessException` (git or the command missing) to 69.
- `commands/exec_command.dart`: the core flow:
  1. Requires `pubspec.yaml` in the cwd, a command after `--` (unless `--dry-run`), and branch/remote/`--base` not starting with `-` (exit 64).
  2. `getModifiedFiles` (`utils/git_utils.dart`) runs `git fetch` unless `--no-fetch` (branch mode uses an explicit `+refs/heads/<b>:refs/remotes/<r>/<b>` refspec so single-branch clones update the tracking ref; a failure only warns), computes `git merge-base <base> HEAD` (deepening a shallow clone by 1, which is enough for a PR merge commit, then 100 and 1000, fetching base and HEAD separately because one fetch deepens only one), and diffs against it with `--no-renames` across the whole repo, plus untracked files. Each `ChangedFile` has `path` (cwd-relative, `../` when outside the package) and `repoPath`. No merge base → warns, diffs against the base; merge base == HEAD → warns. Returns null (exit 1) outside git, for an unknown base, or when the diff fails.
  3. `--mode` (`Mode` in `common_utils.dart`; `auto` → `detectMode`: `test` for `flutter/dart/fvm flutter test`, `package` for `analyze` or no command, else `files`). Full-run triggers: `--all`, `--run-all-on` globs (`globToRegExp`, matched on `repoPath`), `affectsWorkspace` (parent-dir `pubspec.*`/`melos.yaml`/`analysis_options.yaml`, test/package modes) and `affectsAllTests` (test mode: package config files, `flutter_test_config.dart`, non-Dart under `test/`/`lib/`/`assets/`).
  4. `test`: `dependentFiles` (`utils/import_graph.dart`) parses `import`/`export`/`part` directives from `lib`/`bin`/`test`/`integration_test`/`test_driver`, follows them into local packages via `.dart_tool/package_config.json` (relative `rootUri` = local; falls back to the pubspec `name`), and walks the reverse graph from the changed files. Selected: `test/**_test.dart` among dependents plus changed local `_test.dart`; when that is every `test/**_test.dart`, it is a full run (so `full-suite` is true). `package`: full run if any local change or a dependent exists. `files`: existing changed local `.dart` files (`listDartFiles` for a full run).
  5. `chunkArgs` splits the files so each command line stays under `maxCommandLength` (6000 on Windows, leaving room for `flutter.bat`'s expansion under cmd.exe's 8191; 100000 elsewhere); a test run needing >1 chunk becomes a full run. Each chunk runs with `Process.start` in `inheritStdio` mode (`runInShell` on Windows); all chunks run, and the first non-zero exit code is returned.
  6. `--report <dir>` writes one JSON file per run (`<pid>-<micros>.json`; appending to one file from concurrent melos processes loses lines). Warnings go through `_warn`, which prints `::warning::` annotations when `GITHUB_ACTIONS=true` (the environment is injected; tests pass `{}`).
- `commands/report_command.dart`: `dart_diff report [--output f] [--summary f] <dir>` aggregates the run files (sorted by package): `ran` is `none` if all none, `full` if all full, else `partial`.
- The update check against pub.dev is skipped when the `CI` env var is set. Tests inject `environment: {}` so CI doesn't change their behavior.
- The package has its own `analysis_options.yaml` (`package:lints`). The root one also uses `package:lints` and excludes `example/**`.
- `utils/constants.dart`: the `Options` enum holds the CLI option names, abbreviations and defaults (`branch`/`b`/`main`, `remote`/`r`/`origin`).

### Version file

`lib/src/version.dart` is generated by `build_version` (build_runner) and also rewritten by `tools/update_cli_version.dart`, which runs as the Melos `version` preCommit hook and stages the file, so the release commit and tag include it. Both must produce identical content, or the `version-verify` test fails.

## Release / CI

- Commits must follow Conventional Commits: `npm install` sets up a husky `commit-msg` hook running commitlint (`commitlint.config.js`), and the commitlint workflow checks PRs.
- Releases are automatic on every push to `main` (`.github/workflows/semantic-release.yaml`, one run at a time):
  1. `release_cli`: `melos version --yes` bumps the CLI from conventional commits under `packages/dart_diff_cli` (no-op if none), pushes the `chore(release): publish packages` commit and `dart_diff_cli-v<version>` tag atomically; the tag push triggers `publish.yaml`. Both jobs push with a release GitHub App token (`vars.RELEASE_APP_ID`, `secrets.RELEASE_APP_PRIVATE_KEY`); the App is a bypass actor on the `main` ruleset (PRs + required checks), and runs for `chore(release)` head commits are skipped so its pushes don't loop.
  2. `create_release`: semantic-release (`.releaserc.yaml`) tags the Action `v<version>`, updates `CHANGELOG.md`, and on `main` force-moves the `v<major>` tag users pin. Manual `workflow_dispatch` on other branches skips the CLI job and uses `.releaserc.prerelease.yaml`.
- `publish.yaml` publishes to pub.dev via OIDC (`dart-lang/setup-dart` reusable workflow, `pub.dev` environment). pub.dev's automated publishing for `dart_diff_cli` must allow this repo, tag pattern `dart_diff_cli-v{{version}}`, and `workflow_dispatch` events.
- `.github/workflows/test.yaml` jobs (Flutter 3.27.0, the minimum, and latest stable):
  - `test_cli`: ubuntu/macOS/Windows × Dart 3.6.0/stable in `packages/dart_diff_cli`: pub get, format, `dart analyze --fatal-infos`, `dart test`; `bash tool/coverage.sh` on ubuntu + stable. On 3.6.0 it writes the `resolution:` override first.
  - `test_simple_app` / `test_super_app`: one job per Flutter version with one `if: !cancelled()` step per command (Flutter set up and the CLI compiled once). The diff-based steps usually run nothing, since a PR rarely changes the examples; the `run-all: true` steps (`--coverage`, `--plain-name`, `--fatal-infos`, `--set-exit-if-changed`) run the command for real. They run the Action (`uses: ./`) against `example/simple_app` (plain) and `example/super_app` (Melos, `app/**`, `feature/**`; `app` → `auth` → `core` path dependencies, `api` standalone) across test/analyze/format commands. super_app is a pub workspace that works with Melos 6.3.2 (Flutter 3.27, reads its `melos.yaml`) and Melos 7 (stable, reads `workspace:`/`melos:`); CI activates `melos '>=6.3.2 <9.0.0'` globally.
  - `test_repo_root`: builds a fresh repo from `simple_app` (project = git root, bare `origin`) and checks the Action succeeds, and fails when a failing test is added.
  - `test_outputs`: builds a fresh repo from `super_app` and checks the Action's outputs: a `core` change runs `core`, `auth` and `app` tests under Melos (not `api`), `base: <sha>` in one package, a dry run (no `command`) in `api` is skipped, and a root `pubspec.yaml` change runs every package in full.
  - The workflow has `concurrency` with `cancel-in-progress`, so a new push to a PR cancels the older run.
  - `verify_tests` gates on all of them. These examples are the Action's integration fixtures.
