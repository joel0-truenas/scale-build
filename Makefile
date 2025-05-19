#############################################################################
# Makefile for building: TrueNAS SCALE
#############################################################################
ifeq ($(shell uname -m),aarch64)
	ARCH?=arm64
else
	ARCH?=amd64
endif
PYTHON?=/usr/bin/python3
COMMIT_HASH=$(shell git rev-parse --short HEAD)
PYTHON_CMD:=. ./venv-${COMMIT_HASH}/bin/activate && ARCH=${ARCH}
PACKAGES?=""
REPO_CHANGED=$(shell if [ -d "./venv-$(COMMIT_HASH)" ]; then git status --porcelain | grep -c "scale_build/"; else echo "1"; fi)
# Check if --break-system-packages flag is supported by pip
BREAK_SYS_PKGS_FLAG=$(shell ${PYTHON} -m pip help install | grep -q -- '--break-system-packages' && echo "--break-system-packages" || echo "")

.DEFAULT_GOAL := all

check:
ifneq ($(REPO_CHANGED),0)
	@echo "Setting up new virtual environment"
	@rm -rf venv-*
	@${PYTHON} -m pip install $(BREAK_SYS_PKGS_FLAG) -U virtualenv >/dev/null || { echo "Failed to install/upgrade virtualenv package"; exit 1; }
	@${PYTHON} -m venv venv-${COMMIT_HASH} || { echo "Failed to create virutal environment"; exit 1; }
	@{ . ./venv-${COMMIT_HASH}/bin/activate && \
		python3 -m pip install -r requirements.txt >/dev/null 2>&1 && \
		python3 setup.py install >/dev/null 2>&1; } || { echo "Failed to install scale-build"; exit 1; }
endif

all: checkout packages update iso

clean: check
	${PYTHON_CMD} scale_build clean
checkout: check
	${PYTHON_CMD} scale_build checkout
check_upstream_package_updates: check
	${PYTHON_CMD} scale_build check_upstream_package_updates
iso: check
	${PYTHON_CMD} scale_build iso
packages: check
ifeq ($(PACKAGES),"")
	${PYTHON_CMD} scale_build packages
else
	${PYTHON_CMD} scale_build packages --packages ${PACKAGES}
endif
update: check
	${PYTHON_CMD} scale_build update
validate_manifest: check
	${PYTHON_CMD} scale_build validate --no-validate-system_state
validate: check
	${PYTHON_CMD} scale_build validate

branchout: checkout
	${PYTHON_CMD} scale_build branchout $(args)
