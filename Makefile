PREFIX := /usr
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
RUNARGS :=
.SUFFIXES:
BLACKARGS := -t py36 anki tests
ISORTARGS := anki tests

$(shell mkdir -p .build ../build)

PHONY: all
all: check

.build/run-deps: setup.py
	pip install -e .
	@touch $@

.build/dev-deps: requirements.dev
	pip install -r requirements.dev
	@touch $@

PROTODEPS := $(wildcard ../anki-proto/*.proto)

.build/py-proto: .build/dev-deps $(PROTODEPS)
	protoc --proto_path=../anki-proto --python_out=anki --mypy_out=anki $(PROTODEPS)
	@touch $@

BUILD_STEPS := .build/run-deps .build/dev-deps .build/py-proto

# Checking
######################

.PHONY: check
check: $(BUILD_STEPS) .build/mypy .build/test .build/fmt .build/imports .build/lint

.PHONY: fix
fix: $(BUILD_STEPS)
	isort $(ISORTARGS)
	black $(BLACKARGS)

.PHONY: clean
clean:
	rm -rf .build anki.egg-info build dist

# Checking python
######################

CHECKDEPS := $(shell find anki tests -name '*.py' | grep -v buildhash.py)

.build/mypy: $(CHECKDEPS)
	mypy anki
	@touch $@

.build/test: $(CHECKDEPS)
	python -m nose2 --plugin=nose2.plugins.mp -N 16
	@touch $@

.build/lint: $(CHECKDEPS)
	pylint -j 0 --rcfile=.pylintrc -f colorized --extension-pkg-whitelist=ankirspy anki
	@touch $@

.build/imports: $(CHECKDEPS)
	isort $(ISORTARGS) --check
	@touch $@

.build/fmt: $(CHECKDEPS)
	black --check $(BLACKARGS)
	@touch $@

# Building
######################

# we only want the wheel when building, but passing -f wheel to poetry
# breaks the inclusion of files listed in pyproject.toml
.PHONY: build
build: $(BUILD_STEPS) $(CHECKDEPS)
	rm -rf dist
	echo "build='$$(git rev-parse --short HEAD)'" > anki/buildhash.py
	python setup.py bdist_wheel
	rsync -a dist/*.whl ../build/

# prepare code for running in place
.PHONY: develop
develop: $(BUILD_STEPS)
