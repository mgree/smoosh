TEST_ENV ?= $(shell pwd)/default.env

export TEST_ENV TEST_LOGDIR TEST_SHELL TEST_SHELL_FLAGS

.PHONY : all shell expand clean veryclean

all : shell expand

shell : $(TEST_ENV)
	@echo == Running shell tests ===============================================
	@./run.sh

expand :
	@echo == Running expansion tests ===========================================
	@$(MAKE) -C $@

$(shell pwd)/default.env :
	@echo == Generating test environment =======================================
	@echo TEST_SHELL=$$(cd ../src; pwd)/shell >$@
	@echo TEST_TIME=$$(date +%Y-%m-%d_%H:%M) >>$@

clean :
	-rm -f default.env
	$(MAKE) -C expand clean

veryclean : clean
	-rm -rf log
