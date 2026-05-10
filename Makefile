.PHONY: test demo-fixture

test:
	sh scripts/test.sh

demo-fixture:
	sh scripts/demo/fixture.sh "$(FIXTURE)"
