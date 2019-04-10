#!/bin/bash
# we need bash for kill -l

set -e

SIGNALS="SIGABRT SIGALRM SIGBUS SIGCHLD SIGCONT SIGFPE SIGHUP SIGILL SIGINT SIGKILL SIGPIPE SIGQUIT SIGSEGV SIGSTOP SIGTERM SIGTSTP SIGTTIN SIGTTOU SIGUSR1 SIGUSR2 SIGTRAP SIGURG SIGXCPU SIGXFSZ"

cat <<EOF 
open import Smoosh_prelude

val platform_int_of_signal : signal -> nat
let platform_int_of_signal signal =
  match signal with  
  |    EXIT ->  0
EOF
for sig in $SIGNALS; do
    if [ ${#sig} -lt 7 ]; then sig="$sig "; fi
    code=$(kill -l $sig)
    if [ "$code" -lt 10 ]; then code=" $code"; fi
    echo "  | $sig -> $code"
done
echo "  end"

echo

cat <<EOF
val signal_of_platform_int : nat -> maybe signal
let signal_of_platform_int n =
  match n with
  |  0 -> Just    EXIT
EOF
(for sig in $SIGNALS; do 
     code=$(kill -l $sig)
     if [ "$code" -lt 10 ]; then code=" $code"; fi
     echo "  | $code -> Just $sig"
done) | sort -k 2 -n
echo "  | _  -> Nothing"
echo "  end"

cat <<EOF

val platform_int_of_ocaml_signal : int -> nat
let platform_int_of_ocaml_signal ocaml_signal =
  platform_int_of_signal (signal_of_ocaml_signal ocaml_signal)
EOF
