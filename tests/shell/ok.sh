#!/bin/sh

set -e

: ${TEST_TIME=$(date "+%Y-%m-%d_%H:%M")}
TEST_SCRIPT=${0##*/}

msg() {
    printf "${TEST_SCRIPT}: $@\n"
}

debug() {
    if [ -n "${TEST_VERBOSE}" ]
    then
        msg "$@"
    fi
}

abort() {
    printf "${TEST_SCRIPT} aborting: $@\n" >&2
    exit 1
}

failed() {
    msg "$1 failed"
}

passed() {
    debug "$1 passed"
}

[ -n "${TEST_SHELL}" ] || abort "please set TEST_SHELL to the path to the shell under test"
[ -z "${TEST_SHELL_FLAGS}" ] || debug "using shell flags '${TEST_SHELL_FLAGS}'"

: ${TEST_LOGDIR=log/${TEST_TIME}}
mkdir -p ${TEST_LOGDIR}/ok

count=0
passed=0

for test_case in ok/*.test
do
    if ${TEST_SHELL} ${TEST_SHELL_FLAGS} ${test_case} >${TEST_LOGDIR}/${test_case}.out 2>${TEST_LOGDIR}/${test_case}.err
    then
        passed ${test_case}
        : $((passed += 1))
    else
        echo $? >${TEST_LOGDIR}/${test_case}.ec.$?
        failed ${test_case}
    fi
    : $((count += 1))
done

printf "${TEST_SCRIPT}: %d/%d tests passed\n" ${passed} ${count}
