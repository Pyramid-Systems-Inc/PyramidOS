; ==============================================================================
; PyramidOS Kernel Image Header
; ==============================================================================
; This 512-byte sector is attached to the FRONT of kernel.bin.
; It provides Stage 2 with the necessary metadata to load the kernel.
; ==============================================================================

bits 16

; 1. Magic Signature "PyrImg01"
; Stage 2 checks this to ensure it's reading a valid PyramidOS kernel.
magic:
    db 'P','y','r','I','m','g','0','1'

; 2. Kernel Size (in Bytes)
; Value is passed by Makefile via -D KERNEL_SIZE=...
; If not defined, we default to a safe fallback (e.g., 16KB) for testing.
kernel_size_bytes:
%ifdef KERNEL_SIZE
    dd KERNEL_SIZE
%else
    dd 16384        ; Default 16KB if Makefile doesn't set it
%endif

; 3. Load Physical Address
; We want the kernel at 1MB (0x00010000)
load_physical_address:
    dd 0x00010000

; 4. Entry Physical Address
; We start execution at the same place (0x00010000)
entry_physical_address:
    dd 0x00010000

; 5. Checksum (CRC32 or Simple Sum)
; Passed by Makefile via -D KERNEL_CHECKSUM=...
; Currently Stage 2 ignores this (Phase 1), so 0 is safe.
kernel_checksum:
%ifdef KERNEL_CHECKSUM
    dd KERNEL_CHECKSUM
%else
    dd 0
%endif

; 6. Padding
; Fill the rest of the sector with zeros to reach exactly 512 bytes.
times 512-($-$$) db 0