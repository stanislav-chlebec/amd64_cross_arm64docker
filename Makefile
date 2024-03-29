# Copyright (c) 2016 Cisco and/or its affiliates.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at:
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

CCACHE_DIR?=$(BR)/.ccache
GDB?=gdb
SAMPLE_PLUGIN?=no
STARTUP_DIR?=$(PWD)
MACHINE=$(shell uname -m)
SUDO?=sudo
DPDK_CONFIG?=no-pci

export PLATFORM?=native
export WS_ROOT=$(CURDIR)
export BR=$(WS_ROOT)/build-root
include build-data/platforms/$(PLATFORM).mk

,:=,
define disable_plugins
$(if $(1), \
  "plugins {" \
  $(patsubst %,"plugin %_plugin.so { disable }",$(subst $(,), ,$(1))) \
  " }" \
  ,)
endef

MINIMAL_STARTUP_CONF="							\
unix { 									\
	interactive 							\
	cli-listen /run/vpp/cli.sock					\
	gid $(shell id -g)						\
	$(if $(wildcard startup.vpp),"exec startup.vpp",)		\
}									\
$(if $(DPDK_CONFIG), "dpdk { $(DPDK_CONFIG) }",)			\
$(call disable_plugins,$(DISABLED_PLUGINS))				\
"

GDB_ARGS= -ex "handle SIGUSR1 noprint nostop"

#
# OS Detection
#
# We allow Darwin (MacOS) for docs generation; VPP build will still fail.
ifneq ($(shell uname),Darwin)
OS_ID        = $(shell grep '^ID=' /etc/os-release | cut -f2- -d= | sed -e 's/\"//g')
OS_VERSION_ID= $(shell grep '^VERSION_ID=' /etc/os-release | cut -f2- -d= | sed -e 's/\"//g')
endif

ifeq ($(filter ubuntu debian,$(OS_ID)),$(OS_ID))
PKG=deb
else ifeq ($(filter rhel centos fedora opensuse opensuse-leap opensuse-tumbleweed,$(OS_ID)),$(OS_ID))
PKG=rpm
endif

# +libganglia1-dev if building the gmond plugin

DEB_DEPENDS  = curl build-essential autoconf automake ccache
DEB_DEPENDS += debhelper dkms git libtool libapr1-dev dh-systemd
DEB_DEPENDS += libconfuse-dev git-review exuberant-ctags cscope pkg-config
DEB_DEPENDS += lcov chrpath autoconf indent clang-format libnuma-dev
DEB_DEPENDS += python-all python3-all python3-setuptools python-dev
DEB_DEPENDS += python-virtualenv python-pip libffi6 check
DEB_DEPENDS += libboost-all-dev libffi-dev python3-ply libmbedtls-dev
DEB_DEPENDS += cmake ninja-build uuid-dev python3-jsonschema
ifeq ($(OS_VERSION_ID),14.04)
	DEB_DEPENDS += libssl-dev
else ifeq ($(OS_ID)-$(OS_VERSION_ID),debian-8)
	DEB_DEPENDS += libssl-dev
	APT_ARGS = -t jessie-backports
else ifeq ($(OS_ID)-$(OS_VERSION_ID),debian-9)
	DEB_DEPENDS += libssl1.0-dev
else
	DEB_DEPENDS += libssl-dev
endif

RPM_DEPENDS  = redhat-lsb glibc-static
RPM_DEPENDS += apr-devel
RPM_DEPENDS += numactl-devel
RPM_DEPENDS += check check-devel
RPM_DEPENDS += boost boost-devel
RPM_DEPENDS += selinux-policy selinux-policy-devel
RPM_DEPENDS += ninja-build
RPM_DEPENDS += libuuid-devel
RPM_DEPENDS += mbedtls-devel

ifeq ($(OS_ID),fedora)
	RPM_DEPENDS += dnf-utils
	RPM_DEPENDS += subunit subunit-devel
	RPM_DEPENDS += compat-openssl10-devel
	RPM_DEPENDS += python3-devel python3-ply
	RPM_DEPENDS += python3-virtualenv python3-jsonschema
	RPM_DEPENDS += cmake
	RPM_DEPENDS_GROUPS = 'C Development Tools and Libraries'
else
	RPM_DEPENDS += yum-utils
	RPM_DEPENDS += openssl-devel
	RPM_DEPENDS += python-devel python36-ply
	RPM_DEPENDS += python3-devel python3-pip
	RPM_DEPENDS += python-virtualenv python36-jsonschema
	RPM_DEPENDS += devtoolset-7
	RPM_DEPENDS += cmake3
	RPM_DEPENDS_GROUPS = 'Development Tools'
endif

# +ganglia-devel if building the ganglia plugin

RPM_DEPENDS += chrpath libffi-devel rpm-build
# lowercase- replace spaces with dashes.
SUSE_NAME= $(shell grep '^NAME=' /etc/os-release | cut -f2- -d= | sed -e 's/\"//g' | sed -e 's/ /-/' | awk '{print tolower($$0)}')
SUSE_ID= $(shell grep '^VERSION_ID=' /etc/os-release | cut -f2- -d= | sed -e 's/\"//g' | cut -d' ' -f2)
RPM_SUSE_BUILDTOOLS_DEPS = autoconf automake ccache check-devel chrpath
RPM_SUSE_BUILDTOOLS_DEPS += clang cmake indent libtool make ninja python3-ply

RPM_SUSE_DEVEL_DEPS = glibc-devel-static libnuma-devel
RPM_SUSE_DEVEL_DEPS += libopenssl-devel openssl-devel mbedtls-devel libuuid-devel

RPM_SUSE_PYTHON_DEPS = python-devel python3-devel python-pip python3-pip
RPM_SUSE_PYTHON_DEPS += python-rpm-macros python3-rpm-macros

RPM_SUSE_PLATFORM_DEPS = distribution-release shadow rpm-build

ifeq ($(OS_ID),opensuse)
ifeq ($(SUSE_NAME),tumbleweed)
	RPM_SUSE_DEVEL_DEPS = libboost_headers1_68_0-devel-1.68.0  libboost_thread1_68_0-devel-1.68.0 gcc
	RPM_SUSE_PYTHON_DEPS += python3-ply python2-virtualenv
endif
ifeq ($(SUSE_ID),15.0)
	RPM_SUSE_DEVEL_DEPS += libboost_headers-devel libboost_thread-devel gcc
	RPM_SUSE_PYTHON_DEPS += python3-ply python2-virtualenv
else
	RPM_SUSE_DEVEL_DEPS += libboost_headers1_68_0-devel-1.68.0 gcc6
	RPM_SUSE_PYTHON_DEPS += python-virtualenv
endif
endif

ifeq ($(OS_ID),opensuse-leap)
ifeq ($(SUSE_ID),15.0)
	RPM_SUSE_DEVEL_DEPS += libboost_headers-devel libboost_thread-devel gcc git curl
	RPM_SUSE_PYTHON_DEPS += python3-ply python2-virtualenv
endif
endif

RPM_SUSE_DEPENDS += $(RPM_SUSE_BUILDTOOLS_DEPS) $(RPM_SUSE_DEVEL_DEPS) $(RPM_SUSE_PYTHON_DEPS) $(RPM_SUSE_PLATFORM_DEPS)

ifneq ($(wildcard $(STARTUP_DIR)/startup.conf),)
        STARTUP_CONF ?= $(STARTUP_DIR)/startup.conf
endif

ifeq ($(findstring y,$(UNATTENDED)),y)
CONFIRM=-y
FORCE=--force-yes
endif

TARGETS = vpp

ifneq ($(SAMPLE_PLUGIN),no)
TARGETS += sample-plugin
endif

.PHONY: help wipe wipe-release build build-release rebuild rebuild-release
.PHONY: run run-release debug debug-release build-vat run-vat pkg-deb pkg-rpm
.PHONY: ctags cscope
.PHONY: test test-debug retest retest-debug test-doc test-wipe-doc test-help test-wipe
.PHONY: test-cov test-wipe-cov

define banner
	@echo "========================================================================"
	@echo " $(1)"
	@echo "========================================================================"
	@echo " "
endef

help:
	@echo "Make Targets:"
	@echo " install-dep         - install software dependencies"
	@echo " wipe                - wipe all products of debug build "
	@echo " wipe-release        - wipe all products of release build "
	@echo " build               - build debug binaries"
	@echo " build-release       - build release binaries"
	@echo " build-coverity      - build coverity artifacts"
	@echo " rebuild             - wipe and build debug binares"
	@echo " rebuild-release     - wipe and build release binares"
	@echo " run                 - run debug binary"
	@echo " run-release         - run release binary"
	@echo " debug               - run debug binary with debugger"
	@echo " debug-release       - run release binary with debugger"
	@echo " test                - build and run (basic) functional tests"
	@echo " test-debug          - build and run (basic) functional tests (debug build)"
	@echo " test-all            - build and run (all) functional tests"
	@echo " test-all-debug      - build and run (all) functional tests (debug build)"
	@echo " test-gcov           - build and run functional tests (gcov build)"
	@echo " test-shell          - enter shell with test environment"
	@echo " test-shell-debug    - enter shell with test environment (debug build)"
	@echo " test-wipe           - wipe files generated by unit tests"
	@echo " retest              - run functional tests"
	@echo " retest-debug        - run functional tests (debug build)"
	@echo " test-help           - show help on test framework"
	@echo " run-vat             - run vpp-api-test tool"
	@echo " pkg-deb             - build DEB packages"
	@echo " pkg-deb-debug       - build DEB debug packages"
	@echo " vom-pkg-deb         - build vom DEB packages"
	@echo " vom-pkg-deb-debug   - build vom DEB debug packages"
	@echo " pkg-rpm             - build RPM packages"
	@echo " install-ext-deps    - install external development dependencies"
	@echo " ctags               - (re)generate ctags database"
	@echo " gtags               - (re)generate gtags database"
	@echo " cscope              - (re)generate cscope database"
	@echo " checkstyle          - check coding style"
	@echo " fixstyle            - fix coding style"
	@echo " doxygen             - (re)generate documentation"
	@echo " bootstrap-doxygen   - setup Doxygen dependencies"
	@echo " wipe-doxygen        - wipe all generated documentation"
	@echo " checkfeaturelist    - check FEATURE.yaml according to schema"
	@echo " featurelist         - dump feature list in markdown"
	@echo " json-api-files      - (re)-generate json api files"
	@echo " json-api-files-debug - (re)-generate json api files for debug target"
	@echo " docs                 - Build the Sphinx documentation"
	@echo " docs-venv         - Build the virtual environment for the Sphinx docs"
	@echo " docs-clean        - Remove the generated files from the Sphinx docs"
	@echo " test-doc            - generate documentation for test framework"
	@echo " test-wipe-doc       - wipe documentation for test framework"
	@echo " test-cov            - generate code coverage report for test framework"
	@echo " test-wipe-cov       - wipe code coverage report for test framework"
	@echo " test-checkstyle     - check PEP8 compliance for test framework"
	@echo " test-refresh-deps   - refresh the Python dependencies for the tests"
	@echo ""
	@echo "Make Arguments:"
	@echo " V=[0|1]                  - set build verbosity level"
	@echo " STARTUP_CONF=<path>      - startup configuration file"
	@echo "                            (e.g. /etc/vpp/startup.conf)"
	@echo " STARTUP_DIR=<path>       - startup drectory (e.g. /etc/vpp)"
	@echo "                            It also sets STARTUP_CONF if"
	@echo "                            startup.conf file is present"
	@echo " GDB=<path>               - gdb binary to use for debugging"
	@echo " PLATFORM=<name>          - target platform. default is native"
	@echo "                            Supported platforms: native, aarch64-generic"
	@echo " TEST=<filter>            - apply filter to test set, see test-help"
	@echo " DPDK_CONFIG=<conf>       - add specified dpdk config commands to"
	@echo "                            autogenerated startup.conf"
	@echo "                            (e.g. \"no-pci\" )"
	@echo " SAMPLE_PLUGIN=yes        - in addition build/run/debug sample plugin"
	@echo " DISABLED_PLUGINS=<list>  - comma separated list of plugins which"
	@echo "                            should not be loaded"
	@echo ""
	@echo "Current Argument Values:"
	@echo " V                 = $(V)"
	@echo " STARTUP_CONF      = $(STARTUP_CONF)"
	@echo " STARTUP_DIR       = $(STARTUP_DIR)"
	@echo " GDB               = $(GDB)"
	@echo " PLATFORM          = $(PLATFORM)"
	@echo " DPDK_VERSION      = $(DPDK_VERSION)"
	@echo " DPDK_CONFIG       = $(DPDK_CONFIG)"
	@echo " SAMPLE_PLUGIN     = $(SAMPLE_PLUGIN)"
	@echo " DISABLED_PLUGINS  = $(DISABLED_PLUGINS)"

$(BR)/.deps.ok:
ifeq ($(findstring y,$(UNATTENDED)),y)
	make install-dep
endif
ifeq ($(filter ubuntu debian,$(OS_ID)),$(OS_ID))
	@MISSING=$$(apt-get install -y -qq -s $(DEB_DEPENDS) | grep "^Inst ") ; \
	if [ -n "$$MISSING" ] ; then \
	  echo "\nPlease install missing packages: \n$$MISSING\n" ; \
	  echo "by executing \"make install-dep\"\n" ; \
	  exit 1 ; \
	fi ; \
	exit 0
else ifneq ("$(wildcard /etc/redhat-release)","")
	@for i in $(RPM_DEPENDS) ; do \
	    RPM=$$(basename -s .rpm "$${i##*/}" | cut -d- -f1,2,3)  ;	\
	    MISSING+=$$(rpm -q $$RPM | grep "^package")	   ;    \
	done							   ;	\
	if [ -n "$$MISSING" ] ; then \
	  echo "Please install missing RPMs: \n$$MISSING\n" ; \
	  echo "by executing \"make install-dep\"\n" ; \
	  exit 1 ; \
	fi ; \
	exit 0
endif
	@touch $@

bootstrap:
	@echo "'make bootstrap' is not needed anymore"

install-dep:
ifeq ($(filter ubuntu debian,$(OS_ID)),$(OS_ID))
ifeq ($(OS_VERSION_ID),14.04)
	@sudo -E apt-get $(CONFIRM) $(FORCE) install software-properties-common
endif
ifeq ($(OS_ID)-$(OS_VERSION_ID),debian-8)
	@grep -q jessie-backports /etc/apt/sources.list /etc/apt/sources.list.d/* 2> /dev/null \
           || ( echo "Please install jessie-backports" ; exit 1 )
endif
ifeq ($(ARCH),native)
	@sudo -E apt-get update
	@sudo -E apt-get $(APT_ARGS) $(CONFIRM) $(FORCE) install $(DEB_DEPENDS)
	$(RESTORE_LINK_TO_NATIVE_OBJCOPY_AND_STRIP)
else ifneq ($(ARCH),$(MACHINE))
# cross compilation pkg install
ifeq ($(ARCH),aarch64)
	sed  -i 's/^deb /deb [arch=amd64] /g' /etc/apt/sources.list 
	sudo dpkg --add-architecture arm64
	sudo dpkg --print-foreign-architectures
	sudo apt-get update
	@sudo add-apt-repository -n "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ bionic main restricted universe multiverse"
	@sudo add-apt-repository -n "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ bionic-updates main restricted universe multiverse"
	@sudo add-apt-repository -n "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ bionic-backports main restricted universe multiverse"
	#echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports bionic multiverse universe main restricted" >> /etc/apt/sources.list
	#echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports bionic-updates multiverse restricted universe main" >> /etc/apt/sources.list
	#echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports bionic-backports main multiverse restricted universe" >> /etc/apt/sources.list
	cat /etc/apt/sources.list
	$(eval DEB_DEPENDS += libssl-dev:arm64 libmbedtls-dev:arm64 uuid-dev:arm64)
	$(eval DEB_DEPENDS += libnuma-dev:arm64 libnl-3-dev:arm64)
	$(eval DEB_DEPENDS += gcc-8-aarch64-linux-gnu g++-8-aarch64-linux-gnu)
	@sudo -E apt-get update || true
	@sudo -E apt-get $(APT_ARGS) $(CONFIRM) $(FORCE) install $(DEB_DEPENDS)
	@sudo update-alternatives \
	    --install /usr/bin/aarch64-linux-gnu-gcc aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-8 800 \
	    --slave /usr/bin/aarch64-linux-gnu-g++ aarch64-linux-gnu-g++ /usr/bin/aarch64-linux-gnu-g++-8
	$(SET_LINK_TO_ARCH_DEPENDANT_OBJCOPY_AND_STRIP)
else
    $(error "Deb package installation: arch $(ARCH) from platform $(PLATFORM) unsupported")
endif
endif
else ifneq ("$(wildcard /etc/redhat-release)","")
ifeq ($(OS_ID),rhel)
	@sudo -E yum-config-manager --enable rhel-server-rhscl-7-rpms
	@sudo -E yum groupinstall $(CONFIRM) $(RPM_DEPENDS_GROUPS)
	@sudo -E yum install $(CONFIRM) $(RPM_DEPENDS)
	@sudo -E debuginfo-install $(CONFIRM) glibc openssl-libs mbedtls-devel zlib
else ifeq ($(OS_ID),centos)
	@sudo -E yum install $(CONFIRM) centos-release-scl-rh epel-release
	@sudo -E yum groupinstall $(CONFIRM) $(RPM_DEPENDS_GROUPS)
	@sudo -E yum install $(CONFIRM) $(RPM_DEPENDS)
	@sudo -E debuginfo-install $(CONFIRM) glibc openssl-libs mbedtls-devel zlib
else ifeq ($(OS_ID),fedora)
	@sudo -E dnf groupinstall $(CONFIRM) $(RPM_DEPENDS_GROUPS)
	@sudo -E dnf install $(CONFIRM) $(RPM_DEPENDS)
	@sudo -E debuginfo-install $(CONFIRM) glibc openssl-libs mbedtls-devel zlib
endif
else ifeq ($(filter opensuse-tumbleweed,$(OS_ID)),$(OS_ID))
	@sudo -E zypper refresh
	@sudo -E zypper install -y $(RPM_SUSE_DEPENDS)
else ifeq ($(filter opensuse-leap,$(OS_ID)),$(OS_ID))
	@sudo -E zypper refresh
	@sudo -E zypper install  -y $(RPM_SUSE_DEPENDS)
else ifeq ($(filter opensuse,$(OS_ID)),$(OS_ID))
	@sudo -E zypper refresh
	@sudo -E zypper install -y $(RPM_SUSE_DEPENDS)
else
	$(error "This option currently works only on Ubuntu, Debian, RHEL, CentOS or openSUSE systems")
endif
	#git config commit.template .git_commit_template.txt

define make
	@make -C $(BR) TAG=$(1) $(2)
endef

$(BR)/scripts/.version:
ifneq ("$(wildcard /etc/redhat-release)","")
	$(shell $(BR)/scripts/version rpm-string > $(BR)/scripts/.version)
else
	$(shell $(BR)/scripts/version > $(BR)/scripts/.version)
endif

DIST_FILE = $(BR)/vpp-$(shell src/scripts/version).tar
DIST_SUBDIR = vpp-$(shell src/scripts/version|cut -f1 -d-)

dist:
	@if git rev-parse 2> /dev/null ; then \
	    git archive \
	      --prefix=$(DIST_SUBDIR)/ \
	      --format=tar \
	      -o $(DIST_FILE) \
	    HEAD ; \
	    git describe > $(BR)/.version ; \
	else \
	    (cd .. ; tar -cf $(DIST_FILE) $(DIST_SUBDIR) --exclude=*.tar) ; \
	    src/scripts/version > $(BR)/.version ; \
	fi
	@tar --append \
	  --file $(DIST_FILE) \
	  --transform='s,.*/.version,$(DIST_SUBDIR)/src/scripts/.version,' \
	  $(BR)/.version
	@$(RM) $(BR)/.version $(DIST_FILE).xz
	@xz -v --threads=0 $(DIST_FILE)
	@$(RM) $(BR)/vpp-latest.tar.xz
	@ln -rs $(DIST_FILE).xz $(BR)/vpp-latest.tar.xz

build: $(BR)/.deps.ok
	$(call make,vpp_debug,$(addsuffix -install,$(TARGETS)))

wipedist:
	@$(RM) $(BR)/*.tar.xz

wipe: wipedist test-wipe $(BR)/.deps.ok
	$(call make,vpp_debug,$(addsuffix -wipe,$(TARGETS)))
	@find . -type f -name "*.api.json" ! -path "./test/*" -exec rm {} \;

rebuild: wipe build

build-release: $(BR)/.deps.ok
	$(call make,vpp,$(addsuffix -install,$(TARGETS)))

wipe-release: test-wipe $(BR)/.deps.ok
	$(call make,vpp,$(addsuffix -wipe,$(TARGETS)))

rebuild-release: wipe-release build-release

libexpand = $(subst $(subst ,, ),:,$(foreach lib,$(1),$(BR)/install-$(2)-$(PLATFORM)/vpp/$(lib)/$(3)))

export TEST_DIR ?= $(WS_ROOT)/test

define test
	$(if $(filter-out $(2),retest),make -C $(BR) TAG=$(1) vpp-install,)
	$(eval libs:=lib lib64)
	make -C test \
	  VPP_BUILD_DIR=$(BR)/build-$(1)-$(PLATFORM) \
	  VPP_BIN=$(BR)/install-$(1)-$(PLATFORM)/vpp/bin/vpp \
	  VPP_PLUGIN_PATH=$(call libexpand,$(libs),$(1),vpp_plugins) \
	  VPP_TEST_PLUGIN_PATH=$(call libexpand,$(libs),$(1),vpp_api_test_plugins) \
	  VPP_INSTALL_PATH=$(BR)/install-$(1)-$(PLATFORM)/ \
	  LD_LIBRARY_PATH=$(call libexpand,$(libs),$(1),) \
	  EXTENDED_TESTS=$(EXTENDED_TESTS) \
	  PYTHON=$(PYTHON) \
	  OS_ID=$(OS_ID) \
	  CACHE_OUTPUT=$(CACHE_OUTPUT) \
	  $(2)
endef

test:
	$(call test,vpp,test)

test-debug:
	$(call test,vpp_debug,test)

test-gcov:
	$(call test,vpp_gcov,test)

test-all:
	$(if $(filter-out $(3),retest),make -C $(BR) TAG=vpp vom-install,)
	$(eval EXTENDED_TESTS=yes)
	$(call test,vpp,test)

test-all-debug:
	$(if $(filter-out $(3),retest),make -C $(BR) TAG=vpp_debug vom-install,)
	$(eval EXTENDED_TESTS=yes)
	$(call test,vpp_debug,test)

papi-wipe:
	@make -C test papi-wipe

test-help:
	@make -C test help

test-wipe:
	@make -C test wipe

test-shell:
	$(call test,vpp,shell)

test-shell-debug:
	$(call test,vpp_debug,shell)

test-shell-gcov:
	$(call test,vpp_gcov,shell)

test-dep:
	@make -C test test-dep

test-doc:
	@make -C test doc

test-wipe-doc:
	@make -C test wipe-doc

test-cov:
	@make -C $(BR) TAG=vpp_gcov vom-install
	$(eval EXTENDED_TESTS=yes)
	$(call test,vpp_gcov,cov)

test-wipe-cov:
	@make -C test wipe-cov

test-checkstyle:
	@make -C test checkstyle

test-refresh-deps:
	@make -C test refresh-deps

retest:
	$(call test,vpp,retest)

retest-debug:
	$(call test,vpp_debug,retest)

ifeq ("$(wildcard $(STARTUP_CONF))","")
define run
	@echo "WARNING: STARTUP_CONF not defined or file doesn't exist."
	@echo "         Running with minimal startup config: $(MINIMAL_STARTUP_CONF)\n"
	@cd $(STARTUP_DIR) && \
	  $(SUDO) $(2) $(1)/vpp/bin/vpp $(MINIMAL_STARTUP_CONF)
endef
else
define run
	@cd $(STARTUP_DIR) && \
	  $(SUDO) $(2) $(1)/vpp/bin/vpp $(shell cat $(STARTUP_CONF) | sed -e 's/#.*//')
endef
endif

%.files: .FORCE
	@find . \( -name '*\.[chyS]' -o -name '*\.java' -o -name '*\.lex' \) -and \
		\( -not -path './build-root*' -o -path \
		'./build-root/build-vpp_debug-$(PLATFORM)/dpdk*' \) > $@

.FORCE:

run:
	$(call run, $(BR)/install-vpp_debug-$(PLATFORM))

run-release:
	$(call run, $(BR)/install-vpp-$(PLATFORM))

debug:
	$(call run, $(BR)/install-vpp_debug-$(PLATFORM),$(GDB) $(GDB_ARGS) --args)

build-coverity:
	$(call make,vpp_coverity,install-packages)

debug-release:
	$(call run, $(BR)/install-vpp-$(PLATFORM),$(GDB) $(GDB_ARGS) --args)

build-vat:
	$(call make,vpp_debug,vpp-api-test-install)

run-vat:
	@$(SUDO) $(BR)/install-vpp_debug-$(PLATFORM)/vpp/bin/vpp_api_test

pkg-deb:
ifeq ($(PLATFORM),aarch64-generic)
	$(SET_LINK_TO_ARCH_DEPENDANT_OBJCOPY_AND_STRIP)
else
	$(RESTORE_LINK_TO_NATIVE_OBJCOPY_AND_STRIP)
endif
	$(call make,vpp,vpp-package-deb)
ifeq ($(PLATFORM),aarch64-generic)
	$(RESTORE_LINK_TO_NATIVE_OBJCOPY_AND_STRIP)
endif

vom-pkg-deb:
	$(call make,vpp,vpp-package-deb)
	$(call make,vpp,vom-package-deb)

pkg-deb-debug:
	$(call make,vpp_debug,vpp-package-deb)

vom-pkg-deb-debug:
	$(call make,vpp_debug,vpp-package-deb)
	$(call make,vpp_debug,vom-package-deb)

pkg-rpm: dist
	make -C extras/rpm

pkg-srpm: dist
	make -C extras/rpm srpm

dpdk-install-dev:
	$(call banner,"This command is deprecated. Please use 'make install-ext-deps'")
	make -C $(BR) PKG=$(PKG) external-install-$(PKG)

install-ext-deps:
ifeq ($(PLATFORM),aarch64-generic)
	$(SET_LINK_TO_ARCH_DEPENDANT_OBJCOPY_AND_STRIP)
else
	$(RESTORE_LINK_TO_NATIVE_OBJCOPY_AND_STRIP)
endif
	make -C $(BR) PKG=$(PKG) external-install-$(PKG)
ifeq ($(PLATFORM),aarch64-generic)
	$(RESTORE_LINK_TO_NATIVE_OBJCOPY_AND_STRIP)
endif

json-api-files:
	$(WS_ROOT)/src/tools/vppapigen/generate_json.py

json-api-files-debug:
	$(WS_ROOT)/src/tools/vppapigen/generate_json.py --debug-target

ctags: ctags.files
	@ctags --totals --tag-relative -L $<
	@rm $<

gtags: ctags
	@gtags --gtagslabel=ctags

cscope: cscope.files
	@cscope -b -q -v

checkstyle:
	@build-root/scripts/checkstyle.sh

fixstyle:
	@build-root/scripts/checkstyle.sh --fix

featurelist:
	@build-root/scripts/fts.py --all --markdown

checkfeaturelist:
	@build-root/scripts/fts.py --validate --git-status

#
# Build the documentation
#

# Doxygen configuration and our utility scripts
export DOXY_DIR ?= $(WS_ROOT)/doxygen

define make-doxy
	@OS_ID="$(OS_ID)" make -C $(DOXY_DIR) $@
endef

.PHONY: bootstrap-doxygen doxygen wipe-doxygen

bootstrap-doxygen:
	$(call make-doxy)

doxygen:
	$(call make-doxy)

wipe-doxygen:
	$(call make-doxy)

# Sphinx Documents
export DOCS_DIR = $(WS_ROOT)/docs
export VENV_DIR = $(WS_ROOT)/sphinx_venv
export SPHINX_SCRIPTS_DIR = $(WS_ROOT)/docs/scripts

.PHONY: docs-venv docs docs-clean

docs-venv:
	@($(SPHINX_SCRIPTS_DIR)/sphinx-make.sh venv)

docs: $(DOCS_DIR)
	@($(SPHINX_SCRIPTS_DIR)/sphinx-make.sh html)

docs-clean:
	@($(SPHINX_SCRIPTS_DIR)/sphinx-make.sh clean)

pkg-verify: install-dep $(BR)/.deps.ok install-ext-deps
	$(call banner,"Building for PLATFORM=$(PLATFORM) using gcc")
	@make -C build-root TAG=vpp wipe-all install-packages
	$(call banner,"Building sample-plugin")
	@make -C build-root TAG=vpp sample-plugin-install
	$(call banner,"Building libmemif")
	@make -C build-root TAG=vpp libmemif-install
	$(call banner,"Building VOM")
	@make -C build-root TAG=vpp vom-install
	$(call banner,"Building $(PKG) packages")
	@make pkg-$(PKG)
ifeq ($(OS_ID),ubuntu)
	$(call banner,"Building VOM $(PKG) package")
	@make vom-pkg-deb
endif

verify: pkg-verify
ifeq ($(OS_ID)-$(OS_VERSION_ID),ubuntu-18.04)
	$(call banner,"Testing vppapigen")
	@src/tools/vppapigen/test_vppapigen.py
	$(call banner,"Running tests")
	@make COMPRESS_FAILED_TEST_LOGS=yes RETRIES=3 test
endif

define RESTORE_LINK_TO_NATIVE_OBJCOPY_AND_STRIP =
@find /usr/bin -name objcopy -type l -exec ls -al {} \; | grep $(MACHINE); \
retVal=$$?; \
if [ $$retVal -ne 0 ]; then \
  sudo rm /usr/bin/objcopy; \
  sudo ln -s /usr/bin/$(MACHINE)-linux-gnu-objcopy /usr/bin/objcopy; \
fi
@find /usr/bin -name strip -type l -exec ls -al {} \; | grep $(MACHINE); \
retVal=$$?; \
if [ $$retVal -ne 0 ]; then \
  sudo rm /usr/bin/strip; \
  sudo ln -s /usr/bin/$(MACHINE)-linux-gnu-strip /usr/bin/strip; \
fi
endef

define SET_LINK_TO_ARCH_DEPENDANT_OBJCOPY_AND_STRIP =
@sudo rm /usr/bin/objcopy
@sudo ln -s /usr/bin/aarch64-linux-gnu-objcopy /usr/bin/objcopy
@sudo rm /usr/bin/strip
@sudo ln -s /usr/bin/aarch64-linux-gnu-strip /usr/bin/strip
endef
