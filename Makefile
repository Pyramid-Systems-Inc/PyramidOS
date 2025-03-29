# Pyramid Bootloader Makefile for MSYS2

# Detect the MSYS2 environment
ifeq ($(shell uname -o),Msys)
    DETECTED_MSYS2 := 1
endif

# Directories
SRC_DIR = src
BUILD_DIR = build
EFI_DIR = gnu-efi
EFI_INC = $(EFI_DIR)/inc
EFI_LIB = $(EFI_DIR)/lib

# Tools - with proper detection for MSYS2
ASM = nasm
ifdef DETECTED_MSYS2
    # Use mingw64 compilers when in MSYS2
    CC = gcc
    LD = ld
    OBJCOPY = objcopy
else
    # Fall back to cross-compilers if not in MSYS2
    CC = x86_64-w64-mingw32-gcc
    LD = x86_64-w64-mingw32-ld
    OBJCOPY = x86_64-w64-mingw32-objcopy
endif

# Check for required tools
CHECK_NASM := $(shell which $(ASM) 2>/dev/null)
CHECK_CC := $(shell which $(CC) 2>/dev/null)
CHECK_MKISOFS := $(shell which mkisofs 2>/dev/null || which xorriso 2>/dev/null)

# Flags
CFLAGS = -I$(EFI_INC) -I$(EFI_INC)/x86_64 -fPIC -fshort-wchar \
    -ffreestanding -fno-stack-protector -fno-stack-check \
    -mno-red-zone -maccumulate-outgoing-args -DEFI_FUNCTION_WRAPPER
LDFLAGS = -T $(EFI_DIR)/gnuefi/elf_x86_64_efi.lds -Bsymbolic -shared -L$(EFI_LIB)

# Default target
.PHONY: all check_tools
all: check_tools legacy uefi

check_tools:
    @if [ -z "$(CHECK_NASM)" ]; then \
        echo "Error: nasm assembler not found"; \
        exit 1; \
    fi
    @if [ -z "$(CHECK_CC)" ]; then \
        echo "Error: C compiler not found"; \
        exit 1; \
    fi
    @if [ -z "$(CHECK_MKISOFS)" ]; then \
        echo "Warning: mkisofs/xorriso not found, ISO creation may fail"; \
    fi

# Create build directory
$(BUILD_DIR):
    mkdir -p $(BUILD_DIR)

# Legacy BIOS targets
.PHONY: legacy
legacy: $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/main.iso

$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)/main.bin
    cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
    truncate -s 1440K $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main.iso: $(BUILD_DIR)/main.bin | $(BUILD_DIR)
    @echo "Creating bootable ISO image..."
    @mkdir -p "$(BUILD_DIR)/iso/boot"
    cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/iso/boot/
    if [ -n "$(CHECK_MKISOFS)" ]; then \
        if which mkisofs >/dev/null 2>&1; then \
            mkisofs -R -b boot/main.bin -no-emul-boot -boot-load-size 4 \
                -o $(BUILD_DIR)/main.iso $(BUILD_DIR)/iso; \
        else \
            xorriso -as mkisofs -R -b boot/main.bin -no-emul-boot \
                -boot-load-size 4 -o $(BUILD_DIR)/main.iso $(BUILD_DIR)/iso; \
        fi; \
    else \
        echo "Error: No tool to create ISO found"; \
        exit 1; \
    fi
    rm -rf $(BUILD_DIR)/iso

$(BUILD_DIR)/main.bin: $(SRC_DIR)/legacy/main.asm | $(BUILD_DIR)
    $(ASM) $(SRC_DIR)/legacy/main.asm -f bin -o $(BUILD_DIR)/main.bin

# UEFI targets
.PHONY: uefi
uefi: $(BUILD_DIR)/bootx64.efi

$(BUILD_DIR)/bootx64.efi: $(BUILD_DIR)/uefi_main.so
    $(LD) -shared -Bsymbolic -L$(EFI_LIB) $(EFI_LIB)/crt0-efi-x86_64.o \
        $^ -o $@ -lefi -lgnuefi

$(BUILD_DIR)/uefi_main.so: $(BUILD_DIR)/uefi_main.o
    $(CC) $(LDFLAGS) $(BUILD_DIR)/uefi_main.o -o $@ -lefi -lgnuefi

$(BUILD_DIR)/uefi_main.o: $(SRC_DIR)/uefi/uefi_main.c | $(BUILD_DIR)
    $(CC) $(CFLAGS) -c -o $@ $^

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