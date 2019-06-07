fail() {
    echo "$@"
    exit 3
}

has() {
    if [ $# -ne 1 ]
    then
        echo "Bad use of has: has $@" >2
        exit 2
    fi
    
    printf '%s\n' "$res" | grep "$1" >/dev/null
}

# FIND THE UTILITY

type local >/dev/null 2>&1 || { echo 'absent' && exit 1 ; }
echo 'present'
type local | grep special >/dev/null && echo 'special'
type local | grep 'function' >/dev/null && echo 'function' 
type local | grep 'reserved' >/dev/null && echo 'reserved'
type local | grep built >/dev/null && echo 'builtin' 

# SPECIAL BUILTIN?

is_special() {
    x=hi local >/dev/null 2>&1
    case "${x+set}" in
        ( set ) return 0;;
        ( *   ) return 1;;
    esac
    unset x
}

is_special && echo 'truly special' || echo 'not truly special'

# PLAIN LOCAL

plain_local() {
    local x y z=hi
    local 2>&1
}

res=$(plain_local)
[ ! "$res" ] && echo 'plain empty'
has 'z=hi' && echo 'plain assign'
has 'local' && echo 'plain keyword'

# READONLY INTERACTION?

overrides_readonly() {
    echo "in <$or_x>"
    local or_x=0
    echo "out <$or_x>"
}

readonly or_x=hello
res=$(overrides_readonly 2>&1)
has 'out <0>' && echo 'readonly overrides'
has 'out <hello>' && echo 'readonly silent'
has 'out' || echo 'readonly failure'

# can't unset or_x!

# LOCAL W/O ASSIGNMENT

initial_unset() {
    local x
    case "${x-unset}" in
        ( unset ) return 0;;
        ( * ) return 1;;
    esac
}

initial_null() {
    local x
    case "${x-unset},${x:-null}" in
        ( ,null ) return 0;;
        ( * ) return 1;;
    esac
}

initial_unset && echo 'initial unset'
initial_null && echo 'initial null'

unset x

# SCOPED OVERRIDE
scope_inner() {
    x=hi
}

inner_overrides() {
    local x
    scope_inner
    case "${x:-nothing}" in
        ( nothing ) return 1;;
        ( hi ) return 0;;
        ( * ) fail "inner_overrides: unexpected x='$x'";;
    esac
}

inner_overrides && echo 'inner overrides' \
                || echo 'inner nested'

unset x

# SCOPED OVERRIDE LOCAL
scope_inner2() {
    local x
    x=hi
}

inner_overrides2() {
    local x
    scope_inner2
    case "${x:-nothing}" in
        ( nothing ) echo 'inner/local nested';;
        ( hi ) echo 'inner/local overrides';;
        ( * ) fail "inner_overrides2: unexpected x='$x'";;
    esac
}

inner_overrides2

unset x

# SCOPED OVERRIDE DEFINED LOCAL

scope_inner3() {
    local x=inner
}

scope_outer3() {
    local x=outer
    scope_inner3
    case "$x" in
        ( outer ) echo 'inner/local/defined nested';;
        ( inner ) echo 'inner/local/defined overrides';;
        ( * ) fail "inner_overrides3: unexpected x='$x'";;
    esac
}

scope_outer3
unset x

# SCOPED UNSET

scoped_unset_inner() {
    unset x
}

scoped_unset_outer() {
    local x=hi
    scoped_unset_inner
    case "${x-unset},${x:-null}" in
        ( unset,null ) echo 'scoped unset unset';;
        ( ,null ) echo 'scoped unset null';;
        ( hi,hi ) echo 'scoped unset ignored';;
        ( * ) fail "scoped_unset_outer: unexpected x='$x'";;
    esac
}

scoped_unset_outer

unset x

# SCOPED UNSET 2

scoped_unset_inner2() {
    local x
    unset x
}

scoped_unset_outer2() {
    local x=hi
    scoped_unset_inner2
    case "${x-unset},${x:-null}" in
        ( unset,null ) echo 'scoped local/unset unset';;
        ( ,null ) echo 'scoped local/unset null';;
        ( hi,hi ) echo 'scoped local/unset ignored';;
        ( * ) fail "scoped_unset_outer: unexpected x='$x'";;
    esac
}

scoped_unset_outer2

unset x

# EXPORT

local_exported() {
    local x
    export x
    echo "f <${x-unset}>"
    x=hi
    echo "f <${x-still unset}>"
    export
}


res=$(local_exported)
has 'x=' && echo 'local exportable'

x=defaulted
has 'x=' && echo 'local/defaulted exportable'

unset x

# ALLEXPORT

set -o allexport 

local_exported() {
    local x=hi
    export -p | grep x= >/dev/null
}

local_exported && echo 'local/set-a exported' \
               || echo 'local/set-a not exported'

set +o allexport
unset x
