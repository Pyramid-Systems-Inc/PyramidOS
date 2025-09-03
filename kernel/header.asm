; kernel/header.asm - 512-byte kernel image header
; This header precedes kernel.bin to form kernel.img
; Fields (little-endian):
;   [0..7]   magic: 8 bytes = "PyrImg01"
;   [8..11]  kernel_size_bytes: uint32 size of kernel.bin
;   [12..15] load_physical_address: recommended load address (0x00010000)
;   [16..19] entry_physical_address: recommended entry (0x00010000)
;   [20..23] checksum32_bytes: uint32 sum of all bytes of kernel.bin (mod 2^32)
;   [24..511] reserved = 0

%ifndef KERNEL_SIZE
%error "KERNEL_SIZE not defined for header.asm"
%endif

bits 16

magic:
    db 'P','y','r','I','m','g','0','1'

kernel_size_bytes:
    dd KERNEL_SIZE

load_physical_address:
    dd 0x00010000

entry_physical_address:
    dd 0x00010000

kernel_checksum32:
    dd KERNEL_CHECKSUM

; Reserved/padding to 512 bytes
times 512-($-$$) db 0


