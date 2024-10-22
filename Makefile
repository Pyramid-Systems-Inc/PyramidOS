ASM=nasm

SRC_DIR=src
BUILD_DIR=build

$(BUILD_DIR)/main_floppy.img: $(BUILD_DIR)/main.bin
	cp $(BUILD_DIR)/main.bin $(BUILD_DIR)/main_floppy.img
	truncate -s 1440K $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main.iso: $(BUILD_DIR)/main.bin
	dd if=/dev/zero of=$(BUILD_DIR)/floppy.img bs=1024 count=1440
	dd if=$(BUILD_DIR)/main.bin of=$(BUILD_DIR)/floppy.img conv=notrunc
	mkisofs -o $(BUILD_DIR)/main.iso -b floppy.img $(BUILD_DIR)/

$(BUILD_DIR)/main.bin: $(SRC_DIR)/main.asm
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/main.bin