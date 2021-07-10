# id:CAFLRLk8LqxWTwuAarJ5+-_T6XMoxRwYQ6UXS794-v1mwRTabUw@mail.gmail.com
# Koichi Murase <myoga.murase@gmail.com> (2020-04-19) (list)
# Subject: Re: XCU 2.14: Exit status by no-argument `return' in shell trap handlers
# To: austin-group-l@opengroup.org
# Cc: Robert Elz <kre@munnari.oz.au>, Oğuz <oguzismailuysal@gmail.com>
# Date: Sun, 19 Apr 2020 22:02:49 +0900

setexit() { return "$1"; }
invoke() { kill -USR1 $$; return 222; }

trap 'setexit 111; return' USR1
invoke
case $? in
    0)   echo 'In trap argument: last command preceding the trap action' ;;
    111) echo 'In trap argument: last command in the trap action' ;;
    222) echo 'In trap argument: (failed to exit the function)' ;;
    *)   echo 'In trap argument: (unexpected)' ;;
esac

stat=99
handler() { setexit 111; return; }
trap 'handler; stat=$?; return' USR1
invoke
case $stat in
    0)   echo 'In direct function call: last command preceding the trap action' ;;
    111) echo 'In direct function call: last command in the trap action' ;;
    *)   echo 'In direct function call: (unexpected)' ;;
esac

stat=99
utility2() { setexit 111; return; }
handler2() { utility2; stat=$?; }
trap 'handler2' USR1
invoke
case $stat in
    0)   echo 'In indirect function call: last command preceding the
trap      action' ;;
    111) echo 'In indirect function call: last command in the trap action' ;;
    *)   echo 'In indirect function call: (unexpected)' ;;
esac
