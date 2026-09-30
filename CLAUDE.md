# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Two things that ship together:

1. **GitHub Action** (`action.yaml`, composite): validates `branch`/`remote` (plain ref characters, no leading `-`), installs the CLI from its own checkout (`dart pub global activate --source path "$GITHUB_ACTION_PATH/packages/dart_diff_cli"`, after writing a `pubspec_overrides.yaml` with `resolution:` so the CLI resolves outside the root workspace), then runs `dart_diff [--verbose] exec --branch <b> --remote <r> -- <command>`. `debug: true` adds `--verbose`. With `use-melos: true` it runs `git fetch` once, then `melos exec --diff=<remote>/<branch> -- dart_diff exec --no-fetch ...` in each changed package. All inputs reach the scripts through `env:`; the non-melos step `eval`s `$DIFF_COMMAND` so shell quoting works (branch and remote are validated and stay quoted). `exec` uses `allowTrailingOptions: false`, because Melos 7 drops the `--` that `melos exec` passes on.
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

`dart_test.yaml` sets `concurrency: 1` because several tests change `Directory.current`, which the whole process shares. Git tests use `test/helpers/temp_repo.dart` (a temp repo with a bare `origin`); exec tests use a repo-local `git test` alias and a temp Dart script instead of `sh`, so they run on Windows too.

The `version-verify` tag (`test/ensure_build_test.dart`) is skipped by default in `dart_test.yaml`. Run it with `dart test --run-skipped -t version-verify`. It checks that build_runner output is committed, and it requires a clean git tree.

## CLI architecture (`packages/dart_diff_cli/lib/src`)

- `command_runner.dart`: `DartDiffCliCommandRunner` (`CompletionCommandRunner`). Handles `--version` / `--verbose`, registers commands, runs a pub.dev update check after every command except `update`. Maps `UsageException`/`FormatException` to 64 and `ProcessException` (git or the command missing) to 69.
- `commands/exec_command.dart`: the core flow:
  1. Requires `pubspec.yaml` in the cwd, a command after `--`, and a branch/remote not starting with `-` (exit 64).
  2. `getModifiedFiles` (`utils/git_utils.dart`) runs `git fetch` unless `--no-fetch` (a failure only warns), then `git diff --no-renames --relative --merge-base <remote>/<branch>` plus untracked files. Deletions are included (renames show as delete + add). `--relative` keeps paths relative to, and limited to, the cwd, which is how monorepo packages work. If there is no merge base (shallow clone), it falls back to diffing against the branch tip. It returns null (exit 1) when not in a git repo or the diff fails.
  3. For test commands (`isTestCommand`: `flutter test`, `dart test`, `fvm flutter test`), `affectsAllTests` changes (root `pubspec.yaml`/`pubspec.lock`/`dart_test.yaml`/`build.yaml`/`l10n.yaml`, non-`_test.dart` files under `test/`, non-Dart files under `lib/` or `assets/`) and deleted non-`_test.dart` Dart files run the full suite.
  4. Keeps only existing `.dart` files. For test commands, maps each to its test (`lib/x.dart` → `test/x_test.dart`; `_test.dart` files pass through). A file with no test file is skipped.
  5. `chunkArgs` splits the files so each command line stays under `maxCommandLength` (6000 on Windows, leaving room for `flutter.bat`'s expansion under cmd.exe's 8191; 100000 elsewhere). Each chunk runs with `Process.start` in `inheritStdio` mode (`runInShell` on Windows); all chunks run, and the first non-zero exit code is returned.
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
  - `test_simple_app` / `test_super_app`: run the Action (`uses: ./`) against `example/simple_app` (plain) and `example/super_app` (Melos, `app/**`, `feature/**`) across test/analyze/format commands. super_app is a pub workspace that works with Melos 6.3.2 (Flutter 3.27, reads its `melos.yaml`) and Melos 7 (stable, reads `workspace:`/`melos:`); CI activates `melos '>=6.3.2 <9.0.0'` globally.
  - `test_repo_root`: builds a fresh repo from `simple_app` (project = git root, bare `origin`) and checks the Action succeeds, and fails when a failing test is added.
  - `verify_tests` gates on all of them. These examples are the Action's integration fixtures.
