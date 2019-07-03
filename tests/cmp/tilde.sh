echo
[ ~ = "$HOME" ] && echo "tilde" || { echo "no tilde" ; exit 1 ; }

[ ~/ = "$HOME"/ ] && echo "tilde slash"

slash='/'
case ~$slash in
     ( "$HOME"/ ) echo dynamic sep;;
     ( "~/" ) echo no dynamic sep;;
     ( * ) echo '~$slash' gave unexpected value: ~$slash ;;
esac

case ~: in
    ( "$HOME": ) echo colon sep;;
    ( "~:" ) echo no colon sep;;
    ( * ) echo '~:' gave unexpected value: ~: ;;
esac

y=~
[ $y = "$HOME" ] && echo "tilde assign" || { echo "no tilde assign" ; exit 2 ; }

y=~/foo
[ $y = "$HOME/foo" ] && echo "assign slash"

y=~:foo
[ $y = "$HOME:foo" ] && echo "assign colon ~:foo"

y=foo:~
[ $y = "foo:$HOME" ] && echo "assign colon foo:~"

y=foo:~:bar
[ $y = "foo:$HOME:bar" ] && echo "assign colon foo:~:bar"

colon=:

y=~${colon}bar
case $y in
    ( $HOME:bar ) echo dynamic colon;;
    ( "~:bar" ) echo no dynamic colon;;
    ( * ) echo 'y=~${colon}bar' gave unexpected value: "$y" ;;
esac

empty=
case ${empty}~ in
    ( $HOME ) echo dynamic initial word;;
    ( "~" ) echo no dynamic initial word;;
    ( * ) echo '${empty}~' gave unexpected value: ${empty}~ ;;
esac

case ~$(whoami) in
    ( $HOME ) echo dynamic username;;
    ( "~$(whoami)" ) echo no dynamic username;;
    ( * ) echo '~$(whoami)' gave unexpected value: ~$(whoami) ;;
esac
