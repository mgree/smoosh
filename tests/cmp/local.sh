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
echo 'PRESENT'
type local | grep special >/dev/null && echo 'SPECIAL'
type local | grep 'function' >/dev/null && echo 'FUNCTION' 
type local | grep 'reserved' >/dev/null && echo 'RESERVED'
type local | grep built >/dev/null && echo 'BUILTIN'

# SPECIAL BUILTIN?

is_special() {
    x=hi local >/dev/null 2>&1
    case "${x+set}" in
        ( set ) return 0;;
        ( *   ) return 1;;
    esac
}

is_special && echo 'TRULY SPECIAL' || echo 'NOT TRULY SPECIAL'

unset x

# PLAIN LOCAL

plain_local() {
    local x y z=hi
    local -p 2>&1
}

res=$(plain_local)
[ "$?" -eq "0" ] || echo '-p FAILS'
[ ! "$res" ] && echo '-p EMPTY'
has 'z=hi' && echo '-p DUMP'
has 'local x' && echo '-p KEYWORD'
has 'typeset z' && echo '-p ~DUMP typeset macro'

# READONLY INTERACTION?

overrides_readonly() {
    local or_x=0
    echo "out <$or_x>"
}

readonly or_x=hello
res=$(overrides_readonly 2>&1)
has 'out <0>' && echo 'READONLY OVERRIDES'
has 'out <hello>' && echo 'READONLY SILENT'
has 'out' || echo 'READONLY FAILURE'
[ "$or_x" = "hello" ] || echo 'readonly BUG'

# can't unset or_x!

override_inner() {
    local ro2=1
    readonly ro2
}

override_outer() {
    local ro2=0
    override_inner
    (ro2=1) || { echo 'readonly/nested failure' && return ; }
    ro2=1
    return $ro2
}

override_outer && echo 'readonly/nested stays readonly' \
               || echo 'readonly/nested updates'

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

initial_unset && echo 'INITIAL UNSET'
initial_null && echo 'INITIAL NULL'

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

# ALLEXPORT VISIBLE

set -o allexport 

local_exported() {
    local x=hi
}

local_exported 
res=$(export -p)
has 'x=' && echo 'local/set-a exported out of scope' \
         || echo 'local/set-a not exported out of scope'

set +o allexport
unset x

# DOUBLE DECLARATION

double_declaration() {
    local x=hi
    local x
    case "${x:-o},${x+o}" in
        ( o, ) echo "double overrides";;
        ( hi,o ) echo "double noop";;
        ( * ) fail "double_declaration: unexpected x='$x'" ;;
    esac
}

double_declaration

unset x

# LOCAL/READ

local_read() {
    local x=start
    read x
    echo $x
}

x=outer
res=$(local_read <<EOF
redir
EOF
)

case $res,$x in
    ( start,redir ) echo "read override unscoped";;
    ( redir,outer ) echo "read local";;
    ( start,outer ) echo "read noop";;
    ( * ) fail "local_read: unexpected res='$res' x='$x'";;
esac

unset x
