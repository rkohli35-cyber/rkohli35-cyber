# Makefile for Avionics CAN Kernel Module
# Author: Avionics Embedded Expert

MODULE_NAME := avionics_can
obj-m := $(MODULE_NAME).o

# Kernel build directory
KERNEL_DIR ?= /lib/modules/$(shell uname -r)/build

# Module source files
$(MODULE_NAME)-objs := avionics_can.o

# Cross-compilation support
ARCH ?= x86_64
CROSS_COMPILE ?=

# Additional compiler flags for avionics
EXTRA_CFLAGS := -Wall -Wextra -Werror
EXTRA_CFLAGS += -DAVIONICS_CAN_VERSION=1
EXTRA_CFLAGS += -DSAFETY_CRITICAL_MODE

# Default target
all:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules

# Clean target
clean:
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) clean

# Install target
install: all
	$(MAKE) -C $(KERNEL_DIR) M=$(PWD) modules_install
	/sbin/depmod -a

# Load module
load:
	/sbin/insmod $(MODULE_NAME).ko

# Unload module
unload:
	/sbin/rmmod $(MODULE_NAME)

# Device tree overlay installation
install-dt:
	cp avionics-can-overlay.dts /boot/overlays/
	dtc -I dts -O dtb -o /boot/overlays/avionics-can.dtbo /boot/overlays/avionics-can-overlay.dts

# Help target
help:
	@echo "Available targets:"
	@echo "  all      - Build the kernel module"
	@echo "  clean    - Clean build artifacts"
	@echo "  install  - Install the module"
	@echo "  load     - Load the module"
	@echo "  unload   - Unload the module"
	@echo "  help     - Show this help"

.PHONY: all clean install load unload install-dt help