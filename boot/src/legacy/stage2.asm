; ==============================================================================
; PyramidOS Legacy Bootloader - Stage 2
; ==============================================================================
; Responsibility:
; 1. Enable A20 Line.
; 2. Gather Memory Map (E820).
; 3. Load Kernel Image (Parsing custom header).
; 4. Enter Protected Mode (32-bit).
; 5. Jump to Kernel Entry (0x10000).
; 6. Robust Disk I/O with LBA and CHS Fallback.
; ==============================================================================

bits 16
org 0x8000                  ; Loaded here by Stage 1

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
KERNEL_LOAD_SEG     equ 0x1000      ; Segment 0x1000 -> Phys 0x10000
KERNEL_LOAD_OFF     equ 0x0000
SCRATCH_SEG         equ 0x07C0      ; Reuse Stage 1 memory (0x7C00) for scratch
BOOT_INFO_ADDR      equ 0x5000      ; Phys address for BootInfo struct
E820_MAP_ADDR       equ 0x5020      ; Phys address for E820 map

; Magic string expected in Kernel Header "PyrImg01"
MAGIC_SIG_1         equ 0x49727950  ; "PyrI" (Little Endian)
MAGIC_SIG_2         equ 0x3130676D  ; "mg01" (Little Endian)

; Floppy Geometry (Standard 1.44MB)
SECTORS_PER_TRACK   equ 18
HEADS_PER_CYLINDER  equ 2

; ------------------------------------------------------------------------------
; Entry Point
; ------------------------------------------------------------------------------
stage2_main:
    ; 1. Initialization
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFF          ; Stack at top of segment 0
    sti

    mov [boot_drive], dl    ; Save drive number passed from Stage 1

    mov si, msg_banner
    call print_string

    ; 2. Enable A20 Line
    call enable_a20
    call check_a20
    cmp ax, 1
    je .a20_success
    mov si, msg_a20_fail
    call print_string
    jmp .halt_cpu

.a20_success:
    mov si, msg_a20_ok
    call print_string

    ; 3. Get Memory Map (E820)
    call do_e820
    mov si, msg_e820_ok
    call print_string

    ; 4. Load Kernel Header (First 1 sector)
    ; We read it to SCRATCH_SEG:0
    mov ax, SCRATCH_SEG
    mov es, ax
    xor bx, bx              ; Offset 0
    
    ; Prepare LBA Read for 1 sector
    ; We assume Kernel starts at sector 60 (Set in Makefile)
    ; Note: Ideally this is dynamic, but fixed LBA is standard for raw images
    %ifndef KERNEL_LBA
        KERNEL_LBA equ 60
    %endif

    mov eax, KERNEL_LBA
    mov cx, 1
    call read_sectors_universal  ; Universal Read
    
    ; 5. Validate Header
    ; Check Magic "PyrImg01"
    mov eax, [es:0]         ; Read first 4 bytes
    cmp eax, MAGIC_SIG_1
    jne .bad_magic
    mov eax, [es:4]         ; Read next 4 bytes
    cmp eax, MAGIC_SIG_2
    jne .bad_magic

    mov si, msg_hdr_ok
    call print_string

    ; 6. Calculate Kernel Size
    ; Offset 8 in header = Kernel Size (bytes)
    mov eax, [es:8]         ; Load 32-bit size
    mov [kernel_size], eax

    ; Calculate sector count: (Size + 511) / 512
    add eax, 511
    shr eax, 9              ; Divide by 512
    mov [kernel_sectors], ax

    ; 7. Load Kernel Body
    ; Destination: KERNEL_LOAD_SEG:0000
    ; Start LBA: KERNEL_LBA + 1 (Skip header sector)

    mov si, msg_loading
    call print_string

    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    xor bx, bx              ; Destination Offset
    
    mov eax, KERNEL_LBA + 1 ; Start LBA
    movzx ecx, word [kernel_sectors]

    ; Read loop handling 64KB boundaries is inside read_sectors_lba? 
    ; No, the simple reader below assumes small reads.
    ; We need a robust loop here.
    
    call read_kernel_robust

    mov si, msg_kernel_ok
    call print_string

    ; 8. Verify Checksum (Simplified for now: Skip to ensure boot first)
    ; TODO: Implement Checksum verification

    ; 9. Prepare BootInfo Structure
    call setup_boot_info

    ; 10. Enter Protected Mode
    cli                     ; Disable interrupts for good

    lgdt [gdt_descriptor]   ; Load GDT

    mov eax, cr0
    or eax, 1               ; Set PE bit
    mov cr0, eax

    ; Far jump to flush pipeline
    jmp 0x08:pmode_entry

.bad_magic:
    mov si, msg_bad_magic
    call print_string
    jmp .halt_cpu

.halt_cpu:
    cli
    hlt
    jmp .halt_cpu

; ------------------------------------------------------------------------------
; 32-bit Protected Mode Entry
; ------------------------------------------------------------------------------
bits 32
pmode_entry:
    ; Set up data segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000        ; Safe stack in free memory
    
    ; Jump to Kernel Entry (0x10000)
    ; The kernel header has the entry point at offset 16, but we loaded header to scratch.
    ; We know our default is 0x10000.
    mov eax, 0x10000
    jmp eax

bits 16

; ------------------------------------------------------------------------------
; Robust Disk Routines (LBA + CHS Fallback)
; ------------------------------------------------------------------------------

; Routine: read_kernel_robust
; Handles 64KB segments and calls universal read
read_kernel_robust:
.loop:
    cmp cx, 0
    je .done
    
    push eax            ; Save LBA
    push cx             ; Save Total Count
    push es             ; Save Segment
    push bx             ; Save Offset

    ; Limit to segment boundary
    mov dx, 0
    sub dx, bx          ; Bytes remaining in segment (0 means 64KB free if bx=0)
    jz .full_seg        ; If 0, we have full 64KB
    jmp .calc_sec
.full_seg:
    mov dx, 0xFFFF      ; Effectively 64KB
.calc_sec:
    shr dx, 9           ; Convert bytes to sectors
    
    ; Limit to reasonable batch (e.g. 18 sectors = 1 track for CHS safety)
    cmp dx, 18
    jbe .limit_check
    mov dx, 18
.limit_check:

    cmp cx, dx
    jbe .read_count
    mov cx, dx          ; Otherwise read max fit
.read_count:
    
    mov [tmp_lba], eax
    mov [tmp_count], cx
    
    ; Call Universal Read
    mov eax, [tmp_lba]
    call read_sectors_universal
    
    ; Advance
    mov cx, [tmp_count]
    pop bx
    pop es
    
    push cx
    shl cx, 9
    add bx, cx
    jnc .no_seg_wrap
    ; Overflow
    mov dx, es
    add dx, 0x1000      ; Next 64KB segment
    mov es, dx
    ; BX wraps naturally if we did math right (it would be 0)
.no_seg_wrap:
    pop cx
    
    pop dx  ; Old total
    pop eax ; Old LBA
    
    add eax, ecx
    sub dx, cx
    mov cx, dx
    jmp .loop

.done:
    ret

; Routine: read_sectors_universal
; Tries LBA, falls back to CHS
; Input: EAX = LBA, CX = Count (Max 64), ES:BX = Buffer
read_sectors_universal:
    pushad
    
    ; Save arguments for retry
    mov [retry_lba], eax
    mov [retry_cnt], cx
    mov [retry_seg], es
    mov [retry_off], bx

    ; Attempt 1: LBA (INT 13h AH=42h)
    ; Fill DAP
    mov [dap_lba_low], eax
    mov [dap_num], cx
    mov [dap_off], bx
    mov [dap_seg], es
    
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jnc .success    ; If CF=0, LBA worked

    ; Attempt 2: CHS Fallback (INT 13h AH=02h)
    ; Reset Disk First
    mov ah, 0
    mov dl, [boot_drive]
    int 0x13
    
    ; Restore args
    mov eax, [retry_lba]
    mov cx, [retry_cnt]
    mov es, [retry_seg]
    mov bx, [retry_off]
    
    ; Convert LBA to CHS
    ; LBA = (C * H + H) * S + (S - 1)
    ; Sector = (LBA % 18) + 1
    ; Cylinder = (LBA / 18) / 2
    ; Head = (LBA / 18) % 2
    
    push bx ; Save buffer offset
    
    ; 1. Calculate Sector
    xor edx, edx
    mov ebx, SECTORS_PER_TRACK
    div ebx     ; EAX = LBA / 18, EDX = LBA % 18
    
    inc dx      ; Sector is 1-based
    mov [chs_sector], dl
    
    ; 2. Calculate Head & Cylinder
    ; EAX currently holds (LBA / 18)
    xor edx, edx
    mov ebx, HEADS_PER_CYLINDER
    div ebx     ; EAX = Cyl, EDX = Head
    
    mov [chs_head], dl
    mov [chs_cyl], ax
    
    pop bx      ; Restore buffer offset
    
    ; Perform Read
    mov ah, 0x02
    mov al, [retry_cnt] ; Sector Count
    mov ch, [chs_cyl]   ; Cylinder Low
    mov cl, [chs_sector]; Sector
    mov dh, [chs_head]  ; Head
    mov dl, [boot_drive]; Drive
    
    ; Handle High Cylinder bits (rare for floppy, but good practice)
    ; (Assuming Cyl < 255 for 1.44MB floppy)
    
    int 0x13
    jnc .success

    ; Error
    jmp .io_error

.success:
    popad
    ret

.io_error:
    mov si, msg_disk_err
    call print_string
    ; Print error code in AH
    mov al, ah
    call print_hex
    cli
    hlt

; ------------------------------------------------------------------------------
; Helpers
; ------------------------------------------------------------------------------
setup_boot_info:
    push es
    xor ax, ax
    mov es, ax
    mov di, BOOT_INFO_ADDR
    
    mov dword [es:di], 0x54424F4F   ; Magic "BOOT"
    mov word  [es:di+4], 1          ; Version
    mov al, [boot_drive]
    mov [es:di+6], al
    
    ; Kernel Load Address
    mov word [es:di+8], KERNEL_LOAD_SEG
    mov word [es:di+10], KERNEL_LOAD_OFF
    
    ; Kernel Size
    mov eax, [kernel_size]
    mov [es:di+12], eax
    
    ; E820 Map
    ; (Already populated at E820_MAP_ADDR by do_e820)
    ; We just set the pointer and count
    mov ax, [e820_entry_count]
    mov [es:di+16], ax              ; Count
    mov dword [es:di+20], E820_MAP_ADDR ; Pointer
    
    pop es
    ret

; Routine: do_e820
; Scans memory map to E820_MAP_ADDR
do_e820:
    push es
    xor ax, ax
    mov es, ax
    mov di, E820_MAP_ADDR
    xor ebx, ebx        ; Continuation value (must be 0 start)
    xor bp, bp          ; Counter
.loop:
    mov eax, 0xE820
    mov ecx, 24         ; Buffer size
    mov edx, 0x534D4150 ; 'SMAP'
    int 0x15
    jc .done            ; Carry set = end or error
    
    cmp eax, 0x534D4150 ; Check signature
    jne .done

    add di, 24          ; Next entry
    inc bp

    test ebx, ebx       ; If EBX=0, list done
    jnz .loop
    
.done:
    mov [e820_entry_count], bp
    pop es
    ret

; Routine: enable_a20
; Tries BIOS -> Keyboard Controller -> Fast A20
enable_a20:
    ; 1. BIOS Method
    mov ax, 0x2401
    int 0x15
    jnc .done
    
    ; 2. Fast A20
    in al, 0x92
    or al, 2
    out 0x92, al
.done:
    ret

; Routine: check_a20
; Returns AX=1 if enabled, 0 if disabled
check_a20:
    push ds
    push es
    xor ax, ax
    mov ds, ax
    not ax              ; AX = 0xFFFF
    mov es, ax          ; ES = 0xFFFF
    
    mov di, 0x0510      ; 0xFFFF:0x0510 = 0x100500
    mov si, 0x0500      ; 0x0000:0x0500 = 0x000500
    
    mov al, [ds:si]     ; Save byte
    mov byte [ds:si], 0x00
    
    ; Check for wraparound
    mov byte [es:di], 0xFF
    cmp byte [ds:si], 0xFF
    
    je .wrapped         ; If changed, it wrapped -> A20 OFF
    
    mov ax, 1           ; A20 ON
    jmp .restore
.wrapped:
    mov ax, 0           ; A20 OFF
.restore:
    mov [ds:si], al     ; Restore byte
    pop es
    pop ds
    ret

; Routine: print_string
print_string:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

print_hex:
    push ax
    push cx
    mov cl, al
    shr al, 4
    call .nibble
    mov al, cl
    and al, 0x0F
    call .nibble
    pop cx
    pop ax
    ret
.nibble:
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7
.print:
    mov ah, 0x0E
    int 0x10
    ret

; ------------------------------------------------------------------------------
; Data
; ------------------------------------------------------------------------------
boot_drive:      db 0
kernel_size:     dd 0
kernel_sectors:  dw 0
e820_entry_count: dw 0
tmp_lba:         dd 0
tmp_count:       dw 0

retry_lba:       dd 0
retry_cnt:       dw 0
retry_seg:       dw 0
retry_off:       dw 0

chs_cyl:         dw 0
chs_head:        db 0
chs_sector:      db 0

msg_banner:      db 'Stage2...', 13, 10, 0
msg_a20_ok:      db 'A20 ON', 13, 10, 0
msg_a20_fail:    db 'A20 Fail', 13, 10, 0
msg_e820_ok:     db 'MemMap OK', 13, 10, 0
msg_loading:     db 'Loading Kernel...', 13, 10, 0
msg_hdr_ok:      db 'Header OK', 13, 10, 0
msg_bad_magic:   db 'Bad Magic', 0
msg_kernel_ok:   db 'Kernel Loaded', 13, 10, 0
msg_disk_err:    db 'Disk Err:', 0

; Disk Address Packet
align 4
dap:
    db 0x10
    db 0
dap_num: dw 0
dap_off: dw 0
dap_seg: dw 0
dap_lba_low: dd 0
dap_lba_high: dd 0

; Global Descriptor Table (GDT)
align 8
gdt_start:
    dq 0
    ; Code
    dw 0xFFFF, 0x0000, 0x9A00, 0x00CF
    ; Data
    dw 0xFFFF, 0x0000, 0x9200, 0x00CF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 4096-($-$$) db 0     ; Pad Stage 2 to 4KB (8 sectors) for alignment