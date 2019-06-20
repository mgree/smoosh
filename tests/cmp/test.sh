#!/bin/sh

flags() {
    if [ "$#" -ne 1 ]
    then
        echo "expected shell for flags, got '$@'"
        exit 3
    fi

    case $1 in
        ( bash | yash ) echo "-o posix";;
        ( zsh ) echo "--emulate sh";;
        ( * ) return 1;
    esac

    return 0
}

if [ "$#" -ne 1 ]
then
    echo "Expected 1 argument, got $#: '$@'"
    exit 2
fi

CMD="$1"

SHELLS="smoosh bash dash zsh osh mksh ksh yash"

# calculate field width
for SH in $SHELLS
do
    if [ "${WIDTH:-0}" -lt "${#SH}" ]
    then
        WIDTH="${#SH}"
    fi
done
WIDTH=$((WIDTH+6))

for SH in $SHELLS
do
    flags=$(flags $SH)
    if [ "$?" -eq 0 ] # got flags
    then
        $SH $flags -c "$CMD" >$SH-posix.out 2>$SH-posix.err
        echo $? >$SH-posix.ec
        printf "%${WIDTH}s: OUT [%s] ERR [%s] EC [%d]\n" "$SH-posix" "$(cat $SH-posix.out)" "$(cat $SH-posix.err)" "$(cat $SH-posix.ec)"
    fi

    $SH -c "$CMD" >$SH.out 2>$SH.err
    echo $? >$SH.ec

    printf "%${WIDTH}s: OUT [%s] ERR [%s] EC [%d]\n" "$SH" "$(cat $SH.out)" "$(cat $SH.err)" "$(cat $SH.ec)"
done
