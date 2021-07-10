# https://github.com/hvdijk/gwsh/commit/76d14113e08818a5eb82378c385b11720df34d64

set +o pipefail
false  | false  ; echo $?  # 1
false  | true   ; echo $?  # 0
true   | false  ; echo $?  # 1
true   | true   ; echo $?  # 0
exit 2 |(exit 3); echo $?  # 3
set -o pipefail
false  | false  ; echo $?  # 1
false  | true   ; echo $?  # 1
true   | false  ; echo $?  # 1
true   | true   ; echo $?  # 0
exit 2 |(exit 3); echo $?  # 3
set +o pipefail
false  | true &
set -o pipefail
wait $!         ; echo $?  # 0
false  | true &
set +o pipefail
wait $!         ; echo $?  # 1
