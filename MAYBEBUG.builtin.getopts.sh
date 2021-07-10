#id:YBRTFXGM6pLwR5hg@teapot
#earnestly <zibeon@googlemail.com> (January 29) (list)
#Subject: getopts appears to not be shifting $@ when consuming options
#To: dash@vger.kernel.org
#Date: Fri, 29 Jan 2021 18:25:25 +0000

while getopts :a: arg -a foo -a bar; do
    case $arg in
        a) set -- "$@" attr="$OPTARG"
    esac
done
shift "$((OPTIND - 1))"
