cat <<EOF
development:
  shtepper_executable: $HOME/src/shtepper
  submissions_tmpdir: $HOME/web/submissions
  bind: 0.0.0.0
test:
  shtepper_executable: $HOME/src/shtepper
  submissions_tmpdir: $HOME/web/submissions
  bind: 0.0.0.0
production:
  shtepper_executable: $HOME/src/shtepper
  submissions_tmpdir: $HOME/web/submissions
  bind: 0.0.0.0
EOF
