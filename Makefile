ASM=nasm
CC=x86_64-w64-mingw32-gcc
LD=x86_64-w64-mingw32-ld

SRC_DIR=src
BUILD_DIR=build
EFI_DIR=gnu-efi
EFI_INC=$(EFI_DIR)/inc
EFI_LIB=$(EFI_DIR)/lib

# Legacy BIOS build targets
$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)/main.bin
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
	truncate -s 1440K $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main.iso: $(BUILD_DIR)/main.bin
	dd if=/dev/zero of=$(BUILD_DIR)/floppy.img bs=1024 count=1440
	dd if=$(BUILD_DIR)/main.bin of=$(BUILD_DIR)/floppy.img conv=notrunc
	mkisofs -o $(BUILD_DIR)/main.iso -b floppy.img $(BUILD_DIR)/

$(BUILD_DIR)/main.bin: $(SRC_DIR)/legacy/main.asm
	$(ASM) $(SRC_DIR)/legacy/main.asm -f bin -o $(BUILD_DIR)/main.bin

# UEFI build targets
$(BUILD_DIR)/bootx64.efi: $(BUILD_DIR)/uefi_main.so
	$(LD) -shared -Bsymbolic -L$(EFI_LIB) $(EFI_LIB)/crt0-efi-x86_64.o \
		$^ -o $@ -lefi -lgnuefi

$(BUILD_DIR)/uefi_main.so: $(SRC_DIR)/uefi/uefi_main.c
	$(CC) -I$(EFI_INC) -I$(EFI_INC)/x86_64 -c -fPIC -fshort-wchar \
		-ffreestanding -fno-stack-protector -fno-stack-check \
		-mno-red-zone -maccumulate-outgoing-args \
		-DEFI_FUNCTION_WRAPPER -o $(BUILD_DIR)/uefi_main.o $^
	$(LD) -T $(EFI_DIR)/gnuefi/elf_x86_64_efi.lds \
		-Bsymbolic -shared -znocombreloc \
		-L$(EFI_LIB) $(BUILD_DIR)/uefi_main.o -o $@ -lefi -lgnuefi