#!/bin/sh

BASE="$1"
: ${BASE:=$HOME/smoosh}

cat <<EOF
development:
  shtepper_executable: $BASE/src/shtepper
  submissions_tmpdir: $BASE/web/submissions
  bind: 0.0.0.0
test:
  shtepper_executable: $BASE/src/shtepper
  submissions_tmpdir: $BASE/web/submissions
  bind: 0.0.0.0
production:
  shtepper_executable: $BASE/src/shtepper
  submissions_tmpdir: $BASE/web/submissions
  bind: 0.0.0.0
EOF
