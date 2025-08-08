# Pyramid Bootloader Makefile (Revised for New Structure)

# Directories
SRC_DIR = src
BUILD_DIR = build
EFI_DIR = gnu-efi
EFI_INC = $(EFI_DIR)/inc
EFI_LIB = $(EFI_DIR)/x86_64/lib # Corrected path for x86_64 target

# Tools - UEFI (Clang)
UEFI_CC = clang
UEFI_LD = clang # Use clang as the linker driver
UEFI_OBJCOPY = llvm-objcopy

# Tools - Legacy BIOS (NASM + i686-elf-gcc)
LEGACY_ASM = nasm
LEGACY_CC = i686-elf-gcc
LEGACY_LD = i686-elf-ld
LEGACY_OBJCOPY = i686-elf-objcopy

# Check for required tools (using shell which for variable assignment)
# Removed CHECK_... variables using $(shell which...) as they caused DLL errors before target execution.
# Tool checks are performed within the check_tools target below.

# Flags - UEFI (Clang) - Target x86_64 UEFI on Windows
CFLAGS_UEFI = -I$(EFI_INC) -I$(EFI_INC)/x86_64 -fPIC -fshort-wchar \
    -ffreestanding -fno-stack-protector -fno-stack-check \
    -mno-red-zone \
    -Wall -Wextra \
    -DEFI_FUNCTION_WRAPPER \
    --target=x86_64-w64-windows-gnu
# Use lld linker, specify subsystem and entry point
LDFLAGS_UEFI = -fuse-ld=lld -nostdlib -Wl,-dll \
               -Wl,-subsystem:efi_application \
               -Wl,-entry:efi_main \
               -L$(EFI_LIB) # Add path to pre-built gnu-efi libs if needed

# Flags - Legacy BIOS (i386-elf-gcc) - Target 16-bit real mode
# -m16: Generate 16-bit code
# -march=i386: Assume base 386 instruction set (should be compatible)
# -ffreestanding/-nostdlib: No standard library/startup files
# -O2: Optimization level
# -Wall/-Wextra: Warnings
CFLAGS_LEGACY = -m16 -march=i386 -ffreestanding -nostdlib -O2 -Wall -Wextra \
                -I$(SRC_DIR)/legacy # Include dir for potential header
LDFLAGS_LEGACY = # No specific flags needed here; linker script and objcopy handle output
LEGACY_LINKER_SCRIPT = $(SRC_DIR)/legacy/linker.ld

# Default target
.PHONY: all check_tools build_edk2_app
all: check_tools legacy uefi

# EDK2 specific paths
EDK2_WORKSPACE = C:/edk2
EDK2_BUILD_DIR = $(EDK2_WORKSPACE)/Build/PyramidBLPkg/DEBUG_VS2022/X64
EDK2_APP_EFI = $(EDK2_BUILD_DIR)/PyramidUefiApp.efi
LOCAL_EDK2_EFI_DIR = $(BUILD_DIR)/uefi_edk2
LOCAL_EDK2_APP_EFI = $(LOCAL_EDK2_EFI_DIR)/PyramidUefiApp.efi

TEMP_EDK2_BUILD_SCRIPT = $(EDK2_WORKSPACE)/temp_build.bat

check_tools:
	@echo "--- Checking required tools ---"
	@echo "[1/7] Checking $(LEGACY_ASM)..."
	@$(LEGACY_ASM) -v || (echo "Error: $(LEGACY_ASM) check failed." && exit 1)
	@echo "[2/7] Checking $(LEGACY_CC)..."
	@$(LEGACY_CC) --version || (echo "Error: $(LEGACY_CC) (i386-elf-gcc) check failed." && exit 1)
	@echo "[3/7] Checking $(LEGACY_LD)..."
	@$(LEGACY_LD) --version || (echo "Error: $(LEGACY_LD) (i386-elf-ld) check failed." && exit 1)
	@echo "[4/7] Checking $(LEGACY_OBJCOPY)..."
	@$(LEGACY_OBJCOPY) --version || (echo "Error: $(LEGACY_OBJCOPY) (i386-elf-objcopy) check failed." && exit 1)
	@echo "[5/7] Checking $(UEFI_CC)..."
	@$(UEFI_CC) --version || (echo "Error: $(UEFI_CC) check failed." && exit 1)
	@echo "[6/7] Checking $(UEFI_OBJCOPY)..."
	@$(UEFI_OBJCOPY) --version || (echo "Error: $(UEFI_OBJCOPY) check failed." && exit 1)
	@echo "[7/7] Checking mkisofs/xorriso..."
	@which mkisofs > /dev/null 2>&1 || which xorriso > /dev/null 2>&1 || (echo "Warning: mkisofs/xorriso not found, ISO creation may fail.")
	@echo "--- Tool check complete ---"

# Create build directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)/legacy $(BUILD_DIR)/uefi $(LOCAL_EDK2_EFI_DIR)

# Source Files - Legacy
LEGACY_STAGE1_ASM = $(SRC_DIR)/legacy/stage1.asm
LEGACY_ENTRY_ASM = $(SRC_DIR)/legacy/entry.asm
LEGACY_STAGE2_C = $(SRC_DIR)/legacy/stage2.c

LEGACY_STAGE1_BIN = $(BUILD_DIR)/legacy/stage1.bin
LEGACY_ENTRY_OBJ = $(BUILD_DIR)/legacy/entry.o
LEGACY_STAGE2_OBJ = $(BUILD_DIR)/legacy/stage2.o
LEGACY_STAGE2_BIN = $(BUILD_DIR)/legacy/stage2.bin # Linked Stage 2 binary
LEGACY_FINAL_IMG = $(BUILD_DIR)/legacy_floppy.img # Final floppy image

# Legacy BIOS targets
# Removed dependency on legacy.iso to avoid mkisofs/xorriso issues for now.
# User can build it manually via "make build/legacy.iso" if mkisofs/xorriso is fixed.
.PHONY: legacy
legacy: $(LEGACY_FINAL_IMG)

# Create floppy image (pad with zeros)
$(LEGACY_FINAL_IMG): $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) | $(BUILD_DIR)
	@echo "Creating legacy floppy image..."
	cat $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) > $@
	truncate -s 1440K $@ # Pad to 1.44MB

# Create ISO image
$(BUILD_DIR)/legacy.iso: $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) | $(BUILD_DIR)
	@echo "Creating legacy bootable ISO image..."
	@mkdir -p "$(BUILD_DIR)/iso/boot"
	cat $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) > $(BUILD_DIR)/iso/boot/pyramid_legacy.bin
	# Check for mkisofs or xorriso directly within the rule
	if which mkisofs >/dev/null 2>&1 || which xorriso >/dev/null 2>&1; then \
		if which mkisofs >/dev/null 2>&1; then \
			mkisofs -R -b boot/pyramid_legacy.bin -no-emul-boot -boot-load-size 4 \
				-o $@ $(BUILD_DIR)/iso; \
		else \
			xorriso -as mkisofs -R -b boot/pyramid_legacy.bin -no-emul-boot \
				-boot-load-size 4 -o $@ $(BUILD_DIR)/iso; \
		fi; \
	else \
		echo "Error: No tool to create ISO found"; \
		exit 1; \
	fi
	rm -rf $(BUILD_DIR)/iso

# Assemble Stage 1 (Output: raw binary)
$(LEGACY_STAGE1_BIN): $(LEGACY_STAGE1_ASM) | $(BUILD_DIR)
	$(LEGACY_ASM) $(LEGACY_STAGE1_ASM) -f bin -o $@

# Link Stage 2 (C object + Assembly entry object -> raw binary)
# NOTE: Requires a linker script: $(LEGACY_LINKER_SCRIPT)
# Linker script is specified with -T, not needed as a direct prerequisite input ($^)
$(LEGACY_STAGE2_BIN): $(LEGACY_ENTRY_OBJ) $(LEGACY_STAGE2_OBJ) | $(BUILD_DIR)
	@echo "Linking Legacy Stage 2..."
	@echo "NOTE: Ensure '$(LEGACY_LINKER_SCRIPT)' exists and is correctly configured."
	$(LEGACY_LD) -T $(LEGACY_LINKER_SCRIPT) $(LEGACY_ENTRY_OBJ) $(LEGACY_STAGE2_OBJ) -o $(BUILD_DIR)/legacy/stage2.elf $(LDFLAGS_LEGACY)
	$(LEGACY_OBJCOPY) -O binary $(BUILD_DIR)/legacy/stage2.elf $@ # Convert ELF to binary

# Compile Legacy Stage 2 C file (Output: ELF object)
$(LEGACY_STAGE2_OBJ): $(LEGACY_STAGE2_C) | $(BUILD_DIR)
	@echo "Compiling $< (Legacy C)..."
	$(LEGACY_CC) $(CFLAGS_LEGACY) -c $< -o $@

# Assemble Legacy Stage 2 Entry file (Output: ELF object)
$(LEGACY_ENTRY_OBJ): $(LEGACY_ENTRY_ASM) | $(BUILD_DIR)
	@echo "Assembling $< (Legacy Entry)..."
	$(LEGACY_ASM) -f elf $< -o $@ # Output ELF format for i686-elf-ld

# UEFI targets (EDK2 based)
.PHONY: uefi build_edk2_app
uefi: $(LOCAL_EDK2_APP_EFI)
	@echo "UEFI Application (EDK2) is ready at $(LOCAL_EDK2_APP_EFI)"

# Target to trigger the EDK2 build using the temporary batch script
# This should be run manually if EDK2 sources change.
build_edk2_app: | $(BUILD_DIR)
	@echo "Copying project's src/uefi/main.c to EDK2 workspace..."
	@cp $(SRC_DIR)/uefi/main.c $(EDK2_WORKSPACE)/PyramidBLPkg/UefiApp/PyramidUefiApp.c || (echo "Error: Failed to copy src/uefi/main.c to EDK2 workspace." && exit 1)
	@echo "Building EDK2 UEFI application..."
	@echo "Ensure '$(TEMP_EDK2_BUILD_SCRIPT)' exists and is configured."
	@cmd /c "$(TEMP_EDK2_BUILD_SCRIPT)"
	@echo "EDK2 build attempt finished. Check output for success."

# Copy the EDK2-built EFI file to our local build directory
$(LOCAL_EDK2_APP_EFI): build_edk2_app | $(LOCAL_EDK2_EFI_DIR)
	@echo "Copying EDK2 UEFI application from $(EDK2_APP_EFI)..."
	@cp $(EDK2_APP_EFI) $@ || (echo "Error: Failed to copy $(EDK2_APP_EFI). Did the EDK2 build succeed?" && exit 1)

# --- Old gnu-efi based UEFI build rules (commented out) ---
# UEFI_TARGET_EFI_OLD = $(BUILD_DIR)/uefi/bootx64_gnu-efi.efi
# UEFI_TARGET_OBJ_OLD = $(BUILD_DIR)/uefi/main_gnu-efi.o
# UEFI_SOURCE_C_OLD = $(SRC_DIR)/uefi/main.c # This was the gnu-efi main.c
#
# uefi_old: $(UEFI_TARGET_EFI_OLD)
#
# $(UEFI_TARGET_EFI_OLD): $(UEFI_TARGET_OBJ_OLD) | $(BUILD_DIR)
#	@echo "Linking UEFI Application (gnu-efi)..."
#	$(UEFI_LD) $(LDFLAGS_UEFI) $^ -o $@ -lefi -lgnuefi
#
# $(UEFI_TARGET_OBJ_OLD): $(UEFI_SOURCE_C_OLD) | $(BUILD_DIR)
#	@echo "Compiling $< (UEFI C for gnu-efi)..."
#	$(UEFI_CC) $(CFLAGS_UEFI) -c $< -o $@
# --- End of old gnu-efi rules ---

# Utility targets
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: help
help:
	@echo "Pyramid Bootloader Build System (Revised)"
	@echo "========================================="
	@echo "Available targets:"
	@echo "  all         - Build both legacy and UEFI bootloaders (default)"
	@echo "  legacy      - Build legacy BIOS bootloader (floppy and ISO)"
	@echo "  uefi        - Build UEFI bootloader (EFI executable)"
	@echo "  clean       - Remove all build artifacts"
	@echo "  help        - Display this help message"
	@echo ""
	@echo "Notes:"
	@echo " - Legacy build requires i386-elf GCC toolchain and NASM."
	@echo " - Legacy build requires a linker script at '$(LEGACY_LINKER_SCRIPT)'."
	@echo " - UEFI build requires Clang/LLVM toolchain."
	@echo " - Ensure required tools are in your PATH."
