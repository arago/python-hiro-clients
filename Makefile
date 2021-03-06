#
# Python executables
#
PIP := pip3
PYTHON := python3

#
# Setting path for installations as user, i.e. pip install --user ....
# For user installations, set 'export PIPARGS=--user' or execute 'make <argument> PIPARGS=--user'
#
PIPARGS ?=
export PATH := $(HOME)/.local/bin:$(PATH)

#
# GIT values
#
GIT_VERSION ?= ${shell git describe --tags --long --always}
RPM_VERSION ?= ${shell echo $(GIT_VERSION) | cut -b2- | cut -d"-" -f1}
RPM_RELEASE ?= ${shell echo $(GIT_VERSION) | cut -d"-" -f2}
IMAGE_TAG := $(if $(GIT_BRANCH),$(GIT_BRANCH),$(RPM_VERSION)_$(RPM_RELEASE))

#
# Name of the package, version and several paths of the source code
#
PACKAGENAME := hiro_graph_client

SRCPATH := src
PYTHONPATH := $(SRCPATH)/$(PACKAGENAME)
PYTHONDOCPATH := docs/python
VERSION := $(shell cat $(PYTHONPATH)/VERSION)

TIMESTAMP := $(shell $(PYTHON) $(SRCPATH)/timestamp.py)

#
# Paths and names used for distributable packages
#
DISTPATH := dist/$(VERSION)
DISTBASENAME := $(PACKAGENAME)-dist-$(VERSION)

#
# Test settings
#
TESTFILE := tests/test-results.xml


#######################################################################################################################
# Install as a local tool on the current system. Remember to use PIPARGS=--user for a local installation.
#######################################################################################################################
install:
	$(PIP) install $(PIPARGS) --requirement $(PYTHONPATH)/requirements.txt
	$(PIP) install $(PIPARGS) $(SRCPATH)/
	touch install


#######################################################################################################################
# Execute test using pytest
#######################################################################################################################
test:
	$(PIP) install $(PIPARGS) pytest
	export PYTHONPATH=$(PYTHONPATH) && $(PYTHON) -m pytest -s --junitxml=$(TESTFILE)


#######################################################################################################################
# Create source code documentation using python sphinx
#######################################################################################################################

install-sphinx:
	$(PIP) install $(PIPARGS) sphinx sphinx-rtd-theme
	touch install-sphinx

# Create a python code documentation using sphinx
pythondoc: install install-sphinx
	sphinx-apidoc -f -P -o $(PYTHONDOCPATH)/$(PACKAGENAME) $(PYTHONPATH)
	sphinx-build -M html $(PYTHONDOCPATH)/$(PACKAGENAME) $(PYTHONDOCPATH)/$(PACKAGENAME)


#######################################################################################################################
# Upload to PyPI
#######################################################################################################################

# Make wheel and source package
dist: install
	$(PIP) install $(PIPARGS) --upgrade setuptools wheel twine
	(cd src && $(PYTHON) ./setup.py sdist bdist_wheel && mv dist build ..)

# give each package a timestamp as buildnumber to be able to upload packages multiple times
# also only publish whl file
publish-test: clean-dist dist
	mkdir -p dist-test
	(cd dist-test && rm -f *.whl)
	cp -a dist/*.whl dist-test/
	(cd dist-test && mv *.whl $$(ls -1 *.whl | sed -e "s/${VERSION}-py/${VERSION}-${TIMESTAMP}-py/g"))
	$(PYTHON) -m twine upload --repository testpypi --username "$${TESTPYPI_CREDENTIALS_USR}" --password "$${TESTPYPI_CREDENTIALS_PSW}" dist-test/*

# publishing to PyPI only works once for each version. To update your package, you have to create a new version
# in src/hiro_graph_client/__init__.py
publish: dist
	$(PYTHON) -m twine upload --repository pypi --username "$${PYPI_CREDENTIALS_USR}" --password "$${PYPI_CREDENTIALS_PSW}" dist/*

#######################################################################################################################
# Cleanup
#######################################################################################################################

# Uninstall hiro-client
uninstall:
	$(PIP) uninstall -y $(PACKAGENAME) || true

# Cleanup pythondoc
clean-pythondoc:
	rm -rf $(PYTHONDOCPATH)/$(PACKAGENAME)/html $(PYTHONDOCPATH)/$(PACKAGENAME)/doctrees
	rm -f `find $(PYTHONDOCPATH) -type f \( -name "*.rst" -and -not -name "index.rst" \)`

# Cleanup, but keep installed packages and dist tar
clean:
	$(PIP) install $(PIPARGS) --upgrade pyclean
	rm -f depends install install-sphinx
	rm -f $(TESTFILE)
	$(PYTHON) -m pyclean .

clean-dist:
	rm -rf $(SRCPATH)/dist/ $(SRCPATH)/build/ dist dist-test build hiro_graph_client.egg-info

# Like 'clean', but also remove installed packages.
distclean: uninstall clean-pythondoc clean-dist clean
