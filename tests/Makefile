TEST_ENV ?= $(shell pwd)/default.env

export TEST_ENV TEST_LOGDIR TEST_SHELL TEST_SHELL_FLAGS

.PHONY : test shell expand clean veryclean

test : shell expand

shell : $(TEST_ENV)
	@echo == Running shell tests ===============================================
	@./shell_tests.sh

expand :
	@echo == Running expansion tests ===========================================
	@$(MAKE) -C $@

$(shell pwd)/default.env :
	@echo == Generating test environment =======================================
	@echo TEST_SHELL=$$(cd ../src; pwd)/smoosh >$@
	@echo TEST_TIME=$$(date +%Y-%m-%d_%H:%M) >>$@

clean :
	-rm -f default.env
	$(MAKE) -C expand clean

veryclean : clean
	-rm -rf log
