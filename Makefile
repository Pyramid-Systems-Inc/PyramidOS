# Pyramid Bootloader Makefile for MSYS2

# Directories
SRC_DIR = src
BUILD_DIR = build
EFI_DIR = gnu-efi
EFI_INC = $(EFI_DIR)/inc
EFI_LIB = $(EFI_DIR)/lib

# Tools - UEFI (Clang)
UEFI_CC = clang
UEFI_LD = clang # Use clang as the linker driver
UEFI_OBJCOPY = llvm-objcopy

# Tools - Legacy BIOS (NASM + Open Watcom)
LEGACY_ASM = nasm
LEGACY_CC = wcc
LEGACY_LINK = wlink

# Check for required tools
CHECK_NASM := $(shell which $(LEGACY_ASM) 2>/dev/null)
CHECK_CLANG := $(shell which $(UEFI_CC) 2>/dev/null)
CHECK_LLVM_OBJCOPY := $(shell which $(UEFI_OBJCOPY) 2>/dev/null)
CHECK_WCC := $(shell which $(LEGACY_CC) 2>/dev/null)
CHECK_WLINK := $(shell which $(LEGACY_LINK) 2>/dev/null) # Added check for wlink
CHECK_MKISOFS := $(shell which mkisofs 2>/dev/null || which xorriso 2>/dev/null)

# Flags - UEFI (Clang)
CFLAGS_UEFI = -I$(EFI_INC) -I$(EFI_INC)/x86_64 -fPIC -fshort-wchar \
    -ffreestanding -fno-stack-protector -fno-stack-check \
    -DEFI_FUNCTION_WRAPPER \
    --target=x86_64-w64-windows-gnu # Specify target for UEFI
LDFLAGS_UEFI = -T $(EFI_DIR)/gnuefi/elf_x86_64_efi.lds -shared -L$(EFI_LIB) \
               -fuse-ld=lld # Recommended to use lld with clang for UEFI

# Flags - Legacy BIOS (Open Watcom)
# -bt=dos: Target DOS (real mode)
# -mc: Compact memory model (CS=one segment, DS=ES=SS=another segment)
# -0: 8086 instructions
# -wx: Max warnings
# -s: Disable stack checks
# -nd=_TEXT: Name the code segment explicitly (matches assembly)
# -nt=_DATA: Name the data segment explicitly (matches assembly)
# -i=: Include path (Watcom uses -i=, not -I)
WFLAGS = -bt=dos -mc -0 -wx -s -nd=_TEXT -nt=_DATA -i=$(SRC_DIR)/legacy/stage2_c
# system dos: Target DOS executable format (raw binary)
# op quiet: Suppress verbose output
# op map: Generate map file (optional)
# op maxe=50: Max errors before stopping
# op caseexact: Case sensitive symbols
# format raw: Output raw binary
# op quiet: Suppress verbose output
# op map: Generate map file (optional)
# op maxe=50: Max errors before stopping
# op caseexact: Case sensitive symbols
# op stack=4k: Define stack size (adjust if needed)
# Linker script contains most options
# NAME directive overrides name in script
LFLAGS_WCOM = name $@ @$(SRC_DIR)/legacy/stage2.lnk

# Default target
.PHONY: all check_tools
all: check_tools legacy uefi

check_tools:
	@echo "Checking required tools..."
	@if [ -z "$(CHECK_NASM)" ]; then \
		echo "Error: nasm assembler not found (for legacy build)"; \
		exit 1; \
	fi
	@if [ -z "$(CHECK_CLANG)" ]; then \
		echo "Error: clang C compiler not found (for UEFI build)"; \
		exit 1; \
	fi
	@if [ -z "$(CHECK_LLVM_OBJCOPY)" ]; then \
		echo "Error: llvm-objcopy not found (for UEFI build)"; \
		exit 1; \
	fi
	@if [ -z "$(CHECK_WCC)" ]; then \
		echo "Error: wcc (Open Watcom C compiler) not found (for legacy build)"; \
		echo "       Ensure Open Watcom is installed and owsetenv script was run."; \
		exit 1; \
	fi
	@if [ -z "$(CHECK_WLINK)" ]; then \
		echo "Error: wlink (Open Watcom Linker) not found (for legacy build)"; \
		echo "       Ensure Open Watcom is installed and owsetenv script was run."; \
		exit 1; \
	fi
	@if [ -z "$(CHECK_MKISOFS)" ]; then \
		echo "Warning: mkisofs/xorriso not found, ISO creation may fail"; \
	fi
	@echo "Tool check complete."

# Create build directory (cmd.exe compatible - alternative)
# Use md and ignore errors if directories exist
$(BUILD_DIR):
	@md "$(BUILD_DIR)\legacy" 2>nul || exit 0
	@md "$(BUILD_DIR)\uefi" 2>nul || exit 0

# Source Files - Legacy Stage 2 C
LEGACY_C_SRC_DIR = $(SRC_DIR)/legacy/stage2_c
LEGACY_C_SRCS = $(wildcard $(LEGACY_C_SRC_DIR)/*.c)
LEGACY_C_OBJS = $(patsubst $(LEGACY_C_SRC_DIR)/%.c,$(BUILD_DIR)/legacy/%.obj,$(LEGACY_C_SRCS))
LEGACY_ENTRY_ASM = $(SRC_DIR)/legacy/stage2_entry.asm
LEGACY_ENTRY_OBJ = $(BUILD_DIR)/legacy/stage2_entry.obj
LEGACY_STAGE1_ASM = $(SRC_DIR)/legacy/stage1.asm
LEGACY_STAGE1_BIN = $(BUILD_DIR)/legacy/stage1.bin
LEGACY_STAGE2_BIN = $(BUILD_DIR)/legacy/stage2_linked.bin
LEGACY_FINAL_BIN = $(BUILD_DIR)/legacy.bin

# Legacy BIOS targets
.PHONY: legacy
legacy: $(BUILD_DIR)/legacy_floppy.img $(BUILD_DIR)/legacy.iso

$(BUILD_DIR)/legacy_floppy.img: $(LEGACY_FINAL_BIN)
	cp $(LEGACY_FINAL_BIN) $@
	truncate -s 1440K $@

$(BUILD_DIR)/legacy.iso: $(LEGACY_FINAL_BIN) | $(BUILD_DIR)
	@echo "Creating legacy bootable ISO image..."
	@mkdir -p "$(BUILD_DIR)/iso/boot"
	cp $(LEGACY_FINAL_BIN) $(BUILD_DIR)/iso/boot/pyramid.bin # Use a generic name inside ISO
	if [ -n "$(CHECK_MKISOFS)" ]; then \
		if which mkisofs >/dev/null 2>&1; then \
			mkisofs -R -b boot/pyramid.bin -no-emul-boot -boot-load-size 4 \
				-o $@ $(BUILD_DIR)/iso; \
		else \
			xorriso -as mkisofs -R -b boot/pyramid.bin -no-emul-boot \
				-boot-load-size 4 -o $@ $(BUILD_DIR)/iso; \
		fi; \
	else \
		echo "Error: No tool to create ISO found"; \
		exit 1; \
	fi
	rm -rf $(BUILD_DIR)/iso

# Concatenate Stage 1 and Stage 2
$(LEGACY_FINAL_BIN): $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN)
	@echo "Concatenating Stage 1 and Stage 2..."
	cat $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) > $@

# Assemble Stage 1
$(LEGACY_STAGE1_BIN): $(LEGACY_STAGE1_ASM)
	@if not exist "$(BUILD_DIR)\legacy" md "$(BUILD_DIR)\legacy" 2>nul || exit 0
	$(LEGACY_ASM) $(LEGACY_STAGE1_ASM) -f bin -o $@

# Link Stage 2 (C objects + Assembly entry)
# Depends on the C objects, the assembly entry object, and the linker script
$(LEGACY_STAGE2_BIN): $(LEGACY_C_OBJS) $(LEGACY_ENTRY_OBJ) $(SRC_DIR)/legacy/stage2.lnk
	@if not exist "$(BUILD_DIR)\legacy" md "$(BUILD_DIR)\legacy" 2>nul || exit 0
	@echo "Linking Legacy Stage 2..."
	$(LEGACY_LINK) $(LFLAGS_WCOM)

# Compile Legacy Stage 2 C files
# Depends on the source C file, the header
$(BUILD_DIR)/legacy/%.obj: $(LEGACY_C_SRC_DIR)/%.c $(LEGACY_C_SRC_DIR)/stage2.h
	@if not exist "$(BUILD_DIR)\legacy" md "$(BUILD_DIR)\legacy" 2>nul || exit 0
	@echo "Compiling $< (Legacy C)..."
	$(LEGACY_CC) $(WFLAGS) -fo=$@ $<

# Assemble Legacy Stage 2 Entry file (using NASM for OMF output)
# Depends on the source ASM file
$(LEGACY_ENTRY_OBJ): $(LEGACY_ENTRY_ASM)
	@if not exist "$(BUILD_DIR)\legacy" md "$(BUILD_DIR)\legacy" 2>nul || exit 0
	@echo "Assembling $< (Legacy Entry)..."
	$(LEGACY_ASM) -f obj -o $@ $<

# UEFI targets
.PHONY: uefi
uefi: $(BUILD_DIR)/uefi/bootx64.efi

# Link the final EFI application using clang driver
# Depends on the object file, EFI CRT0
$(BUILD_DIR)/uefi/bootx64.efi: $(BUILD_DIR)/uefi/uefi_main.o $(EFI_LIB)/crt0-efi-x86_64.o
	@if not exist "$(BUILD_DIR)\uefi" md "$(BUILD_DIR)\uefi" 2>nul || exit 0
	$(UEFI_CC) $(LDFLAGS_UEFI) $^ -o $@ -lefi -lgnuefi

# Compile the UEFI source file
# Depends on the source C file
$(BUILD_DIR)/uefi/uefi_main.o: $(SRC_DIR)/uefi/uefi_main.c
	@if not exist "$(BUILD_DIR)\uefi" md "$(BUILD_DIR)\uefi" 2>nul || exit 0
	$(UEFI_CC) $(CFLAGS_UEFI) -c -o $@ $<

# Utility targets
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: help
help:
	@echo "Pyramid Bootloader Build System"
	@echo "==============================="
	@echo "Available targets:"
	@echo "  all         - Build both legacy and UEFI bootloaders (default)"
	@echo "  legacy      - Build legacy BIOS bootloader (floppy and ISO)"
	@echo "  uefi        - Build UEFI bootloader (EFI executable)"
	@echo "  clean       - Remove all build artifacts"
	@echo "  help        - Display this help message"
