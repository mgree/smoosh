#!/bin/sh

: ${LINE_LENGTH:=70}

: ${TEST_TIME:=$(date "+%Y-%m-%d_%H:%M")}
TEST_SCRIPT=${0##*/}

cleanup () {
    if [ "$TMP" ]
    then
        echo
        echo Cleaning up temporary directory $TMP...
        rm -r $TMP
    fi
}

trap 'cleanup' EXIT

msg() {
    printf "${TEST_SCRIPT}: $@\n"
}

debugging() {
    [ "${TEST_DEBUG-set}" != "set" ]
}

same_files() {
    if debugging
    then
	diff -u $1 $2
    else
	diff -q $1 $2 >/dev/null
    fi
}

rmlog() {
    if ! debugging
    then
        rm "$@"
    fi
}

debug() {
    if debugging
    then
        msg "$@"
    fi
}

abort() {
    printf "${TEST_SCRIPT} aborting: $@\n" >&2
    exit 1
}

tick() {
    if [ $((count % 70)) -eq 0 ] && [ ${count} -ne 0 ]
    then
	printf '\n'
    fi
}

failed() {
    failed_tests="$failed_tests${failed_tests+ }$1"

    if debugging
    then
        msg "$1 failed"
    else
        tick
        printf 'x'
    fi
}


passed() {
    if debugging
    then
	msg "$1 passed"
    else
	tick
        printf '.'
    fi
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

# make sure the child shell knows about it
export TEST_SHELL

BASE=$(pwd)
: ${TEST_LOGDIR:=$BASE/log/${TEST_TIME}}
mkdir -p ${TEST_LOGDIR}/shell

count=0
passed=0
failed_tests=""

# clear out other application FDs
exec 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-

for test_case in shell/*.test
do
    # load up expected values
    case_name=${test_case%.test}
    case_ec=${case_name}.ec 

    expected_ec=0
    if [ -s "${case_ec}" ]
    then
        expected_ec="$(cat ${case_ec})"
    fi

    expected_out=${case_name}.out
    expected_err=${case_name}.err

    prefix=${TEST_LOGDIR}/${case_name}
    got_timeout=${prefix}.timeout
    got_out=${prefix}.out
    got_err=${prefix}.err

    # actually run the test
    TMP=$(mktemp -d)
    cd $TMP
    ${TEST_UTIL}/timeout -l ${got_timeout} \
      ${TEST_SHELL} ${TEST_SHELL_FLAGS} $BASE/${test_case} >${got_out} 2>${got_err}
    got_ec="$?"
    cd $BASE
    rm -r $TMP
    TMP=
    
    saved_ec=${TEST_LOGDIR}/${case_name}.ec.${got_ec}
    echo ${got_ec} >${saved_ec}

    failures=0

    # check for timeout
    if [ -f "${got_timeout}" ]
    then
        debug "${case_name}: timed out"
        : $((failures += 1))
    fi
    
    # check exit code
    if [ "${expected_ec}" -ne "${got_ec}" ]
    then
        debug "${case_name}: expected exit code ${expected_ec} and got ${got_ec}"
        : $((failures += 1))
    else
        rmlog ${saved_ec}
    fi
    
    # check stdout
    if [ -f "${expected_out}" ] && ! same_files ${expected_out} ${got_out}
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
    if [ -f "${expected_err}" ] && ! same_files ${expected_err} ${got_err}
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

if ! debugging
then
    printf '\n' # clear the progress dots line
fi

printf "${TEST_SCRIPT}: %d/%d tests passed\n" ${passed} ${count}
if [ "${failed_tests}" ]
then
    printf "${TEST_SCRIPT} failing tests: ${failed_tests}\n"
fi

# set exit code
[ "${passed}" -eq "${count}" ]
