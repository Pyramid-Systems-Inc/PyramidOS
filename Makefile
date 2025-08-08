# PyramidOS Top-Level Makefile

# Create the build directory if it doesn't exist
BUILD_DIR = build
$(shell mkdir -p $(BUILD_DIR))

.PHONY: all boot kernel clean

# Default target
all: boot
	@echo "--- PyramidOS Build Complete ---"

# Build the bootloader
# This now depends on the kernel being built first.
boot: kernel
	@echo "--- Building Bootloader ---"
	$(MAKE) -C boot

# Build the kernel
# This delegates the build to the kernel's own Makefile.
kernel:
	@echo "--- Building Kernel ---"
	$(MAKE) -C kernel

# Clean all build artifacts
clean:
	@echo "--- Cleaning All Artifacts ---"
	$(MAKE) -C boot clean
	$(MAKE) -C kernel clean
	rm -rf $(BUILD_DIR)