test:
	test/run
	git status --short
	@echo "All tests OK."

.PHONY: test

