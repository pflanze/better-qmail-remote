test:
	test/run
	bash -c '[[ "`git status --short | wc -l`" -eq 0 ]]'
	@echo "All tests OK."

.PHONY: test

