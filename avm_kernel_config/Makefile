#
# project
#
BASENAME := avm_kernel_config
#
# target binary
# 
BINARIES := gen_$(BASENAME) extract_$(BASENAME)
#
# source files
#
HELPER_SRCS = $(BASENAME)_helpers.c 
BIN_SRCS = gen_$(BASENAME).c extract_$(BASENAME).c
#
# header files
#
HELPER_HDRS = $(BASENAME)_helpers.h 
BIN_HDRS = $(BASENAME).h $(BASENAME)_macros.h
#
# object files
#
HELPER_OBJS = $(HELPER_SRCS:%.c=%.o)
BIN_OBJS = $(BIN_SRCS:%.c=%.o)
#
# tools
#
CC = gcc
RM = rm
AR = ar
RANLIB = ranlib
#
# libfdt (from kernel sources, subdir 'scripts/dtc/libfdt')
#
LIBFDT = libfdt
LIBFDT_LOC = ./$(LIBFDT)
LIBFDT_LIB = $(LIBFDT_LOC)/$(LIBFDT).a
LIBS += $(LIBFDT_LIB)
include $(LIBFDT_LOC)/Makefile.$(LIBFDT)
LIBFDT_INCS = $(addprefix $(LIBFDT_LOC)/, $(LIBFDT_INCLUDES))
LIBFDT_NAMES = $(basename $(LIBFDT_SRCS))
LIBFDT_SRC2 = $(addsuffix .c, $(addprefix $(LIBFDT_LOC)/, $(LIBFDT_NAMES)))
LIBFDT_OBJS = $(LIBFDT_SRC2:%.c=%.o)
#
# flags for calling the tools
#
CFLAGS += -static -std=c99 -m32 -ggdb
LDFLAGS += -static -m32
$(BIN_OBJS) $(HELPER_OBJS): CFLAGS += -O2 -W -Wall
#
# how to build objects from sources
#
%.o: %.c
	$(CC) $(CFLAGS) -I$(LIBFDT_LOC) -I. -c $< -o $@
#
# targets to make
#
.PHONY: all clean
#
all: $(BINARIES)
#
# the binaries
#
$(BINARIES): $(LIBFDT_LIB) $(HELPER_OBJS) $(BIN_OBJS)
	$(CC) $(LDFLAGS) -L. -o $@ $@.o $(HELPER_OBJS) $(LIBS)
#
# make static library
#
$(LIBFDT_LIB): $(LIBFDT_OBJS) 
	-$(RM) $@ 2>/dev/null || true
	$(AR) rcu $@ $?
	$(RANLIB) $@
#
# everything to make, if source files changed
#
$(LIBFDT_OBJS): $(LIBFDT_SRC2) $(LIBFDT_INCS)
$(HELPER_OBJS): $(HELPER_SRCS) $(HELPER_HDRS)
$(BIN_OBJS): $(BIN_SRCS) $(BIN_HDRS) $(HELPER_HDRS)
#
# cleanup 	
#
clean:
	-$(RM) *.o $(BINARIES) $(LIBFDT_LOC)/*.{o,a,so} 2>/dev/null || true
