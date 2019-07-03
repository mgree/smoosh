f() {
    x=$((x+1))
}

g() {
    x=$((x+1)) f
}

h() {
    orig=$x
    x=$((x+1)) g
    case $x in
        ( $((orig+3)) ) echo "$1 UNNESTED" ;;
        ( ${orig} ) echo "$1 NESTED" ;;
        ( * ) echo "unexpected value: '$x'";;
    esac
}

x=0
h GLOBAL

x=0 h LOCAL

