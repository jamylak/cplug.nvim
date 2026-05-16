.PHONY: test demo-fixture list-fixtures

test:
	sh scripts/test.sh

demo-fixture:
	sh scripts/demo/fixture.sh "$(FIXTURE)"

list-fixtures:
	sh scripts/demo/fixture.sh --list
