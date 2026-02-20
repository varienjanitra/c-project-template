## ============================================================================
## Standard C Makefile Template
## 
## Usage:
##   make               (Builds highly optimized, hardened release binary)
##   make DEBUG=1       (Builds unoptimized binary with debug symbols)
##   make SAN=1         (Builds with Address & Undefined Behavior Sanitizers)
##   make analyze       (Runs static analysis via cppcheck)
## ============================================================================

## --- Configuration ---
CC       ?= gcc
STD      := -std=c23
DEBUG    ?= 0
SAN      ?= 0

## Directories
SRC_DIR  := src
OBJ_DIR  := build/obj
BIN_DIR  := build/bin
TARGET   := $(BIN_DIR)/app_exec

## External Dependencies
EXT_DIR  := extern
SYS_INCLUDES := -isystem $(EXT_DIR)

## File Discovery
## $(sort) guarantees deterministic linking order across all operating systems.
SRCS     := $(sort $(shell find $(SRC_DIR) -name "*.c"))
OBJS     := $(SRCS:$(SRC_DIR)/%.c=$(OBJ_DIR)/%.o)
DEPS     := $(OBJS:.o=.d)

## Git Versioning (Traceability)
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

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
    $(info Profile: DEBUG)
    CFLAGS   += -Og -g3
    CPPFLAGS += -D_FORTIFY_SOURCE=2
else
    $(info Profile: RELEASE (Optimized & Hardened))
    ## -O3 + -flto (Link Time Optimization) for maximum premium performance
    CFLAGS   += -O3 -flto
    LDFLAGS  += -flto
    
    ## Modern Hardening (The "Fortress" Suite)
    ## _FORTIFY_SOURCE=3 is the modern standard for premium software (requires GCC 12+)
    CPPFLAGS += -D_FORTIFY_SOURCE=3
    CFLAGS   += -fPIE -fstack-clash-protection -fcf-protection
    LDFLAGS  += -pie -Wl,-z,relro,-z,now -Wl,-z,noexecstack
endif

ifeq ($(SAN), 1)
    $(info Profile: SANITIZER (Memory & UB Checks))
    ## Sanitizers are incompatible with some hardening flags, so they get their own logic
    CFLAGS   += -fsanitize=address -fsanitize=undefined -fno-omit-frame-pointer
    LDFLAGS  += -fsanitize=address -fsanitize=undefined
endif

## ============================================================================
## Rules
## ============================================================================

.PHONY: all clean run analyze

all: $(TARGET)

## Linking Phase
$(TARGET): $(OBJS)
	@mkdir -p $(BIN_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@ $(LDLIBS)
	@echo " Build complete: $@"

## Compilation Phase
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

-include $(DEPS)

clean:
	@echo " Cleaning build directory..."
	@$(RM) -r build

run: all
	@echo " Running $(TARGET)..."
	@./$(TARGET)

## Dedicated Static Analysis Target
analyze:
	@echo " Running cppcheck static analysis..."
	@cppcheck --enable=all --suppress=missingIncludeSystem --inconclusive --error-exitcode=1 $(SRC_DIR)