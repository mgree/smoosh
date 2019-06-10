f() {
    echo "f       [$x]"
    x=$((x+1))
    echo "f incr  [$x]"
}

g() {
    echo "g pre   [$x]"
    x=$((x+1)) f
    echo "g post  [$x]"
}

h() {
    echo "h pre   [$x]"
    x=$((x+1)) g
    echo "h post  [$x]"
}

echo 'x=0 globally'
x=0
h

echo 'x=5 locally'
x=5 h

