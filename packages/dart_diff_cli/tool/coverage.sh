#!/usr/bin/env bash
# Runs the tests with coverage, writes coverage/lcov.info and fails unless
# every line under lib/ is covered. Run from the package dir:
#   bash tool/coverage.sh
set -euo pipefail

dart pub global activate coverage > /dev/null
dart pub global run coverage:test_with_coverage

awk '
  /^SF:/ { file = substr($0, 4); keep = (file ~ /(^|[\/\\])lib[\/\\]/) }
  !keep { next }
  /^DA:/ { split(substr($0, 4), d, ","); if (d[2] == 0) print "Uncovered: " file ":" d[1] }
  /^LF:/ { lf += substr($0, 4) }
  /^LH:/ { lh += substr($0, 4) }
  END {
    if (lf == 0) { print "No coverage found for lib/"; exit 1 }
    printf "Line coverage of lib/: %.2f%% (%d/%d)\n", 100 * lh / lf, lh, lf
    exit (lh == lf ? 0 : 1)
  }
' coverage/lcov.info
