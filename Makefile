# C64U GameNet - GNU Make build (Linux / macOS / MSYS2).
#
# Mirrors build.ps1. Requires ca65 and ld65 (cc65 suite) on PATH, or
# CC65_HOME pointing at a cc65 installation.
#
#   make            build all programs into build/*.prg
#   make clean      remove build/
#
# Structural .prg verification is implemented in build.ps1
# (`pwsh ./build.ps1 verify` also works on Linux/macOS).

ifdef CC65_HOME
  CA65 ?= $(CC65_HOME)/bin/ca65
  LD65 ?= $(CC65_HOME)/bin/ld65
else
  CA65 ?= ca65
  LD65 ?= ld65
endif

BUILD   := build
OBJ     := $(BUILD)/obj
CONFIG  := cfg/c64-prg.cfg
ASFLAGS := --cpu 6502 -g -I src/include

INCLUDES   := $(wildcard src/include/*.inc)
COMMON_SRC := src/common/basic_stub.s

# Programs and their sources (keep in sync with build.ps1).
PROGRAMS := hello commtest
# Milestone 0: toolchain check (stock C64)
hello_SRC := src/hello/hello.s
# Milestone 1: two-machine C64U communication test (C64U only)
commtest_SRC := src/c64u/acia.s src/c64u/modem.s src/tests/commtest.s

all: $(foreach p,$(PROGRAMS),$(BUILD)/$(p).prg)

# Object file name: <program>-<source basename>.o
objname = $(OBJ)/$(1)-$(basename $(notdir $(2))).o

# One assemble rule per (program, source) pair.
define SOURCE_template
$(call objname,$(1),$(2)): $(2) $(INCLUDES) | $(OBJ)
	$$(CA65) $$(ASFLAGS) -l $$(@:.o=.lst) -o $$@ $$<
endef

define PROGRAM_template
$(1)_OBJ := $(foreach s,$(COMMON_SRC) $($(1)_SRC),$(call objname,$(1),$(s)))
$(foreach s,$(COMMON_SRC) $($(1)_SRC),$(eval $(call SOURCE_template,$(1),$(s))))

$$(BUILD)/$(1).prg: $$($(1)_OBJ) $$(CONFIG)
	$$(LD65) -C $$(CONFIG) -m $$(BUILD)/$(1).map -Ln $$(BUILD)/$(1).lbl -o $$@ $$($(1)_OBJ)
endef

$(foreach p,$(PROGRAMS),$(eval $(call PROGRAM_template,$(p))))

$(OBJ):
	mkdir -p $@

clean:
	rm -rf $(BUILD)

.PHONY: all clean
