#!/bin/sh

if [ "$#" -ne 1 ]
then
    echo "Expected 1 argument, got $#: '$@'"
    exit 2
fi

CMD="$1"

SHELLS="smoosh bash dash zsh osh mksh ksh yash"

for SH in $SHELLS
do
    $SH -c "$CMD" >$SH.out 2>$SH.err
    echo $? >$SH.ec
    printf "%6s: OUT [%s] ERR [%s] EC [%d]\n" "$SH" "$(cat $SH.out)" "$(cat $SH.err)" "$(cat $SH.ec)"
done
