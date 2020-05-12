f() {
    x=$((x+1))
    unset x
}

g() {
    x=$((x+1)) f
    post_f=$x
}

h() {
    orig=$x
    x=$((x+1)) g
    post_g=$x
    case $x in
        ( $((orig+3)) ) echo "$1 UNNESTED VALUES (BUT NESTED UNSETS)" ;;
        ( ${orig} ) echo "$1 NESTED VALUES WITH NESTED UNSET" ;;
        ( "" ) echo "$1 HAS GLOBAL UNSET" ;;
        ( * ) echo "unexpected value: '$x'";;
    esac
}

x=0
h GLOBAL

x=0 h LOCAL

