# PyramidOS Top-Level Makefile

.PHONY: all boot kernel clean

# Default target
all: boot kernel
	@echo "PyramidOS Build Complete."

# Build the bootloader
# This delegates the build to the bootloader's own Makefile
boot:
	@echo "--- Building Bootloader ---"
	$(MAKE) -C boot

# Build the kernel
# For now, this is just a placeholder. It will eventually compile kernel/main.c and link it.
kernel:
	@echo "--- Building Kernel (Placeholder) ---"
	# Placeholder for kernel build commands
	@echo "Kernel build not yet implemented."

# Clean all build artifacts
clean:
	@echo "--- Cleaning All Artifacts ---"
	$(MAKE) -C boot clean
	# Placeholder for kernel clean commands
	@echo "Kernel artifacts cleaned (Placeholder)."