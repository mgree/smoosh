#!/bin/sh

set -e

: ${TEST_TIME:=$(date "+%Y-%m-%d_%H:%M")}
TEST_SCRIPT=${0##*/}

msg() {
    printf "${TEST_SCRIPT}: $@\n"
}

rmlog() {
    if [ "${TEST_DEBUG+set}" != "set" ]
    then
        rm "$@"
    fi
}

debug() {
    if [ "${TEST_DEBUG+set}" != "set" ]
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

if [ -n "${TEST_ENV}" ]
then
    if [ -s "${TEST_ENV}" ] 
    then 
        . ${TEST_ENV}
    else 
        abort "couldn't find TEST_ENV=${TEST_ENV}"
    fi
fi 

[ -n "${TEST_SHELL}" ] || abort "please set TEST_SHELL to the path to the shell under test"
[ -n "${TEST_SHELL_FLAGS}" ] && debug "using flags '${TEST_SHELL_FLAGS}'"

: ${TEST_LOGDIR:=log/${TEST_TIME}}
mkdir -p ${TEST_LOGDIR}/shell

count=0
passed=0

for test_case in shell/*.test
do
    # load up expected values
    case_name=${test_case%.test}
    case_ec=${case_name}.ec 

    expected_ec=0
    if [ -s "${case_ec}" ]
    then
        expected_ec="$(cat ${case_ec})"
        echo expecting error code ${expected_ec}
    fi

    expected_out=${case_name}.out
    expected_err=${case_name}.err

    got_out=${TEST_LOGDIR}/${case_name}.out
    got_err=${TEST_LOGDIR}/${case_name}.err

    # actually run the test
    set +e
    ${TEST_SHELL} ${TEST_SHELL_FLAGS} ${test_case} >${got_out} 2>${got_err}
    got_ec="$?"
    set -e

    saved_ec=${TEST_LOGDIR}/${case_name}.ec.${got_ec}
    echo ${got_ec} >${saved_ec}

    failures=0

    # check exit code
    echo checking code
    if [ "${expected_ec}" -ne "${got_ec}" ]
    then
        debug "${case_name}: expected ${expected_ec} and got ${got_ec}"
        : $((failures += 1))
    else
        echo deleting ${saved_ec}
        rmlog ${saved_ec}
    fi
    
    # check stdout
    if [ -f "${expected_out}" ] && diff -q ${expected_out} ${got_out}
    then
        debug "${case_name}: expected STDOUT ${expected_out} differs from logged STDOUT ${got_out}"
        : $((failures += 1))
    else
        # delete the logged output if we knew what it would be
        if [ -f "${expected_out}" ]
        then
            rmlog ${got_out}
        fi
    fi

    # check stderr
    if [ -f "${expected_err}" ] && diff -q ${expected_err} ${got_err}
    then
        debug "${case_name}: expected STDERR ${expected_err} differs from logged STDERR ${got_err}"
        : $((failures += 1))
    else
        if [ -f "${expected_err}" ]
        then
            rmlog ${got_err}
        fi
    fi

    if [ "${failures}" -eq 0 ]
    then
        passed ${case_name}
        : $((passed += 1))
    else
        failed ${case_name}
    fi
    : $((count += 1))
done

printf "${TEST_SCRIPT}: %d/%d tests passed\n" ${passed} ${count}
