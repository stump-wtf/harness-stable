.PHONY: test lint check

# test checks every package against Harness's manifest rules and its
# high-severity content scan (stable_test.go).
test:
	go test ./...

lint:
	@out=$$(gofmt -l $$(find . -name '*.go')); \
	if [ -n "$$out" ]; then echo "gofmt needed on:"; echo "$$out"; exit 1; fi
	go vet ./...

check: lint test
