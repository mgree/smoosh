TEST_ENV ?= $(shell pwd)/default.env
TEST_SHELL ?= smoosh

export TEST_ENV TEST_LOGDIR TEST_UTIL TEST_SHELL TEST_SHELL_FLAGS

.PHONY : test shell count utils clean veryclean

test : utils shell

shell : $(TEST_ENV)
	@echo == Running shell tests ===============================================
	@./shell_tests.sh

$(shell pwd)/default.env :
	@echo == Generating test environment =======================================
	@echo TEST_UTIL=$$(cd util; pwd) >$@
	@echo TEST_SHELL=$(TEST_SHELL) >>$@
	@echo TEST_TIME=$$(date +%Y-%m-%d_%H:%M) >>$@
	@cat $@

count :
	@printf "Benchmarks %3d\n" $(shell ls shell/benchmark.*.test | wc -l)
	@printf "Builtins   %3d\n" $(shell ls shell/builtin.*.test | wc -l)
	@printf "Semantics  %3d\n" $(shell ls shell/semantics.*.test | wc -l)
	@printf "Sh         %3d\n" $(shell ls shell/sh.*.test | wc -l)
	@printf "==============\n"
	@printf "Total      %3d\n" $(shell ls shell/*.test | wc -l)

utils : util/fds util/argv util/getenv util/readdir

util/readdir : util/readdir.c
	gcc -o $@ $<

util/getenv : util/getenv.c
	gcc -o $@ $<

util/fds : util/fds.c
	gcc -o $@ $<

util/argv : util/argv.c
	gcc -o $@ $<

clean :
	-rm -f util/fds util/getenv util/argv util/readdir
	-rm -f default.env

veryclean : clean
	-rm -rf log
