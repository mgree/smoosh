TEST_ENV ?= $(shell pwd)/default.env

export TEST_ENV TEST_LOGDIR TEST_UTIL TEST_SHELL TEST_SHELL_FLAGS

.PHONY : test shell expand utils clean veryclean

test : utils shell expand

shell : $(TEST_ENV)
	@echo == Running shell tests ===============================================
	@./shell_tests.sh

expand :
	@echo == Running expansion tests ===========================================
	@$(MAKE) -C $@

$(shell pwd)/default.env :
	@echo == Generating test environment =======================================
	@echo TEST_UTIL=$$(cd util; pwd) >$@
	@echo TEST_SHELL=$$(cd ../src; pwd)/smoosh >>$@
	@echo TEST_TIME=$$(date +%Y-%m-%d_%H:%M) >>$@

utils : util/fds util/argv util/getenv

util/getenv : util/getenv.c
	gcc -o $@ $<

util/fds : util/fds.c
	gcc -o $@ $<

util/argv : util/argv.c
	gcc -o $@ $<


clean :
	-rm -f util/fds
	-rm -f default.env
	$(MAKE) -C expand clean

veryclean : clean
	-rm -rf log
