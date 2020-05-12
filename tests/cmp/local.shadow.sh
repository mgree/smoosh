ORIG=5
NEW=6
OVERRIDE=10


f() {
    if [ "$x" = "$ORIG" ]
    then
        echo "unshadowed"
    fi
    x=$OVERRIDE
}


x=$ORIG
x=$NEW f
if [ "$x" = "$ORIG" ]
then
    echo "reverts to global"
elif [ "$x" = "$OVERRIDE" ]
then
    echo "overrides"
elif [ "$x" = "$NEW" ]
then
    echo "reverts to temp binding"
else
    echo "unexpected value '$x'"
fi
