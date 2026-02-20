## ============================================================================
## Standard C Makefile Template
## 
## Usage:
##   make               (Builds highly optimized, hardened release binary)
##   make DEBUG=1       (Builds unoptimized binary with debug symbols)
##   make SAN=1         (Builds with Address & Undefined Behavior Sanitizers)
##   make analyze       (Runs static analysis via cppcheck)
## ============================================================================

## ============================================================================
## 1. REGISTRY OF TARGETS (Edit this section when adding new modules)
## ============================================================================

## List all your target names here
TARGET_NAMES := main 

## Define properties for each target:
## <target>_TYPE : EXE (Executable) | SO (Shared Lib) | A (Static Lib)
## <target>_SRC  : Directory containing .c files (will be recursively searched)
## <target>_OUT  : Output binary path
## <target>_DEPS : Other target names this target depends on

# -- App: Main --
main_TYPE := EXE
# NOTE: Keep source directories strictly isolated to prevent 'find' overlaps
main_SRC  := src
main_OUT  := main
main_DEPS := 

## ============================================================================
## 2. CONFIGURATION & FLAGS
## ============================================================================

CC       ?= gcc
## Use gcc-ar to ensure Link-Time Optimization (LTO) works with static libraries
AR       ?= gcc-ar
STD      := -std=c23
DEBUG    ?= 0
SAN      ?= 0

## OS Detection for Linker compatibility
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    OS_RPATH   := -Wl,-rpath,@executable_path/../lib
    OS_HARDEN  := # macOS handles PIE and relro natively/differently
    FORTIFY_LVL := 2 # Apple Clang does not yet support Fortify 3
else
    OS_RPATH   := -Wl,-rpath='$$$$ORIGIN/../lib'
    OS_HARDEN  := -pie -Wl,-z,relro,-z,now -Wl,-z,noexecstack
    FORTIFY_LVL := 3
endif

## Architecture Detection for Hardware Control-Flow Integrity
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
    ARCH_HARDEN := -fcf-protection
else ifeq ($(filter aarch64 arm64,$(UNAME_M)),$(UNAME_M))
    ARCH_HARDEN := -mbranch-protection=standard
else
    ARCH_HARDEN := # Fallback for other architectures (RISC-V, etc.)
endif

## Git Versioning (Traceability)
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

## External Dependencies
EXT_DIR  := extern
SYS_INCLUDES := -isystem $(EXT_DIR)

## --- Base Flags (Applied to everything) ---
## -Werror ensures no rough edges make it into the codebase.
WFLAGS   := -Wall -Wextra -Wpedantic -Wshadow -Wformat=2 -Wformat-security \
            -Wconversion -Wsign-conversion -Wdouble-promotion \
            -Wnull-dereference -Wstrict-overflow=2 -Wunused-result \
            -Wstrict-prototypes -Wmissing-prototypes -Wundef \
            -Wimplicit-fallthrough -Wvla -Wcast-qual -Wcast-align \
            -Wwrite-strings -Wfloat-equal -Werror

## Preprocessor flags (Dependency tracking & Macros)
CPPFLAGS := -MMD -MP -Iinclude $(SYS_INCLUDES) -D_DEFAULT_SOURCE -DGIT_HASH=\"$(GIT_HASH)\"

## Base Compiler & Linker flags (Threading & Stack Protection)
CFLAGS   := $(STD) $(WFLAGS) -pthread -fstack-protector-strong
LDFLAGS  := -pthread
LDLIBS   := -lm

## ============================================================================
## Build Profiles (Release vs. Debug vs. Sanitized)
## ============================================================================

ifeq ($(DEBUG), 1)
    PROFILE  := debug
    CFLAGS   += -Og -g3
    CPPFLAGS += -D_FORTIFY_SOURCE=2
    $(info Profile: DEBUG (Unoptimized, Symbols ON))

else ifeq ($(SAN), 1)
    PROFILE  := sanitized
    ## Sanitizers are incompatible with some hardening flags, so they get their own logic
    CFLAGS   += -O1 -g -fsanitize=address -fsanitize=undefined -fno-omit-frame-pointer
    LDFLAGS  += -fsanitize=address -fsanitize=undefined
    CPPFLAGS += -D_FORTIFY_SOURCE=2
    $(info Profile: SANITIZER (Memory & UB Checks ON))

else
    PROFILE  := release
    ## -O3 + -flto (Link Time Optimization) for maximum premium performance + Dynamic Arch Hardening
    CFLAGS   += -O3 -flto -fstack-clash-protection $(ARCH_HARDEN)
    LDFLAGS  += -flto $(OS_HARDEN)
    ## Modern Hardening (The "Fortress" Suite)
    ## _FORTIFY_SOURCE=3 is the modern standard for premium software (requires GCC 12+)
    CPPFLAGS += -D_FORTIFY_SOURCE=$(FORTIFY_LVL)
    $(info Profile: RELEASE (Optimized, LTO, Hardened))
endif

## Dynamic Directories based on Profile
OBJ_DIR := build/$(PROFILE)/obj
BIN_DIR := dists/$(PROFILE)/bin
LIB_DIR := dists/$(PROFILE)/lib

## ============================================================================
## 3. DYNAMIC RULE GENERATOR (The "Set-and-Forget" Engine)
## ============================================================================

ALL_TARGETS    :=
ALL_DEPS_FILES :=

define GENERATE_TARGET
# 1. Resolve Output Paths
ifeq ($$($1_TYPE),EXE)
    $1_ACTUAL_OUT := $$(BIN_DIR)/$$($1_OUT)
else ifeq ($$($1_TYPE),SO)
    $1_ACTUAL_OUT := $$(LIB_DIR)/lib$$($1_OUT).so
else ifeq ($$($1_TYPE),A)
    $1_ACTUAL_OUT := $$(LIB_DIR)/lib$$($1_OUT).a
endif

# 2. Resolve Sources & Objects
$1_SRCS := $$(sort $$(shell find $$($1_SRC) -name "*.c" 2>/dev/null))
$1_OBJS := $$($1_SRCS:%.c=$$(OBJ_DIR)/$1/%.o)
ALL_DEPS_FILES += $$($1_OBJS:.o=.d)

# 3. Resolve Dependencies
$1_LINK_DEPS := $$(foreach dep,$$($1_DEPS),$$($$(dep)_ACTUAL_OUT))

# 4. Target-Specific Flags
$1_CFLAGS  := $$(CFLAGS)
$1_LDFLAGS := $$(LDFLAGS)

ifeq ($$($1_TYPE),SO)
    $1_CFLAGS  += -fPIC
    $1_LDFLAGS += -shared
    # Inject SONAME for proper dynamic linking resolution
    ifeq ($(UNAME_S),Darwin)
        $1_LDFLAGS += -Wl,-install_name,@rpath/lib$$($1_OUT).dylib
    else
        $1_LDFLAGS += -Wl,-soname,lib$$($1_OUT).so
    endif
else ifeq ($$($1_TYPE),EXE)
    $1_CFLAGS  += -fPIE
    $1_LDFLAGS += $$(OS_RPATH)
endif

# 5. Build Rules
$$(OBJ_DIR)/$1/%.o: %.c
	@mkdir -p $$(dir $$@)
	$$(CC) $$(CPPFLAGS) $$($1_CFLAGS) -c $$< -o $$@

$$($1_ACTUAL_OUT): $$($1_OBJS) $$($1_LINK_DEPS)
	@mkdir -p $$(dir $$@)
ifeq ($$($1_TYPE),A)
	@echo "  Archiving $$@"
	@$$(AR) rcs $$@ $$($1_OBJS)
else
	@echo "  Linking $$@"
	@$$(CC) $$($1_CFLAGS) $$($1_LDFLAGS) $$($1_OBJS) $$($1_LINK_DEPS) -o $$@ $$(LDLIBS)
endif

ALL_TARGETS += $$($1_ACTUAL_OUT)
endef

$(foreach target,$(TARGET_NAMES),$(eval $(call GENERATE_TARGET,$(target))))

## ============================================================================
## 4. STANDARD MAKE TARGETS
## ============================================================================

.PHONY: all clean run analyze bear

all: $(ALL_TARGETS)
	@echo " Build complete for profile: $(PROFILE)"

## Generate compile_commands.json for clangd/LSP support
bear: clean
	@echo " Generating compilation database via bear..."
	@bear -- $(MAKE) all
	@echo " Done. compile_commands.json is ready."

-include $(ALL_DEPS_FILES)

clean:
	@echo " Cleaning build, dists, and tooling caches..."
	@$(RM) -r build dists compile_commands.json .cache

# Allow passing arguments like: make run ARGS="-v --help"
ARGS ?=

run: all
	@echo " Running $(BIN_DIR)/$(main_OUT)..."
	@./$(BIN_DIR)/$(main_OUT) $(ARGS)

## Dedicated Static Analysis Target
## Gather unique source directories for static analysis
ALL_SRC_DIRS := $(sort $(foreach target,$(TARGET_NAMES),$($(target)_SRC)))
analyze:
	@echo " Running cppcheck static analysis..."
	@cppcheck --enable=all --suppress=missingIncludeSystem --inconclusive --error-exitcode=1 $(ALL_SRC_DIRS)