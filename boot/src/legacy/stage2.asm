; boot/src/legacy/stage2.asm
bits 16
org 0x8000

; Constants
KERNEL_LOAD_SEG     equ 0x1000
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_LBA          equ 60              ; May be overridden by -D at build
SCRATCH_SEG         equ 0x0600          ; Buffer for header reads

; Entry point
stage2_start:
    ; Save boot drive
    mov [boot_drive], dl
    
    ; Setup segments
    xor ax, ax          
    mov ds, ax
    mov es, ax
    
    ; Setup stack
    mov ax, 0x0700
    mov ss, ax
    mov sp, 0xFFFF
    
    ; Print "S2 "
    mov si, msg_s2
    call print_string
    
    ; Probe for INT 13h extensions
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc .lba_not_supported
    cmp bx, 0xAA55
    jne .lba_not_supported

    ; === LBA path ===
    mov si, msg_lba
    call print_string

    ; 1) Read header sector at KERNEL_LBA to SCRATCH_SEG:0000
    call disk_reset
    mov ax, SCRATCH_SEG
    mov es, ax
    xor bx, bx
    mov word [dap_num_blocks], 1
    mov word [dap_buf_off], bx
    mov word [dap_buf_seg], es
    mov word [dap_lba_low], KERNEL_LBA
    mov word [dap_lba_low+2], 0
    mov dword [dap_lba_high], 0
    mov si, dap
    mov dl, [boot_drive]
    mov ah, 0x42
    int 0x13
    jc .lba_fail

    ; Validate magic 'PyrImg01'
    push ds
    push cs
    pop ds                      ; DS = CS for code data
    xor di, di                  ; ES:DI -> header
    mov ax, SCRATCH_SEG
    mov es, ax
    mov si, magic_ref
    mov cx, 8
.cmp_magic:
    lodsb
    cmp al, byte es:[di]
    jne .hdr_bad
    inc di
    loop .cmp_magic
    pop ds

    ; Read kernel_size (32-bit) from header offset 8, compute sectors = (size+511)>>9
    mov ax, SCRATCH_SEG
    mov es, ax
    mov bx, 8
    mov ax, word es:[bx]
    mov dx, word es:[bx+2]
    add ax, 511
    adc dx, 0
    ; shift right by 9 (>>9) on DX:AX into AX
    mov cx, 9
.shr_loop:
    shr dx, 1
    rcr ax, 1
    loop .shr_loop
    mov [dyn_kernel_sectors], ax

    ; 2) Read kernel.bin starting from LBA+1 into KERNEL_LOAD_SEG:0000
    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    mov bx, KERNEL_LOAD_OFF
    mov ax, KERNEL_LBA+1
    mov [cur_lba], ax
    mov cx, [dyn_kernel_sectors]
.lba_read_loop:
    cmp cx, 0
    je .kernel_loaded

    ; sectors allowed by 64KiB boundary: ((0x10000 - BX) >> 9)
    mov ax, 0xFFFF
    sub ax, bx
    inc ax
    shr ax, 9
    cmp ax, 0
    jne .have_boundary
    ; Advance segment if no room in this segment
    mov ax, es
    add ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ax, 0xFFFF
    sub ax, bx
    inc ax
    shr ax, 9
.have_boundary:
    ; limit per call to 127 sectors
    cmp ax, 127
    jbe .limit_rem
    mov ax, 127
.limit_rem:
    ; sectors to read = min(ax, cx)
    cmp ax, cx
    jbe .set_count
    mov ax, cx
.set_count:
    mov [tmp_count], ax

    ; Fill DAP and read
    mov word [dap_num_blocks], ax
    mov word [dap_buf_off], bx
    mov word [dap_buf_seg], es
    mov ax, [cur_lba]
    mov word [dap_lba_low], ax
    mov word [dap_lba_low+2], 0
    mov dword [dap_lba_high], 0

    mov si, dap
    mov dl, [boot_drive]
    mov ah, 0x42
    call int13_with_retries
    jc .lba_to_chs_fallback

    ; advance pointers
    mov ax, [tmp_count]
    shl ax, 9
    add bx, ax
    mov ax, [tmp_count]
    add [cur_lba], ax
    sub cx, ax
    jmp .lba_read_loop

.lba_to_chs_fallback:
    ; LBA chunk failed; fall back to CHS
    jmp .use_chs

.lba_fail:
    mov si, msg_lba_err
    call print_string
    mov al, ah
    call print_hex_byte
    jmp .use_chs

.hdr_bad:
    pop ds
    mov si, msg_hdr_err
    call print_string
    jmp .final_error

.lba_not_supported:
    ; No extensions; use CHS
    mov si, msg_no_lba
    call print_string
    ; fallthrough

.use_chs:
    ; === CHS path ===
    mov si, msg_chs
    call print_string

    ; Reset disk and get geometry
    call disk_reset
    mov dl, [boot_drive]
    mov ah, 0x08
    int 0x13
    jc .final_error
    mov al, cl
    and al, 0x3F
    mov [spt], al               ; sectors per track
    mov al, dh
    inc al
    mov [heads], al             ; number of heads

    ; 1) Read header via CHS into SCRATCH_SEG:0000
    mov ax, KERNEL_LBA
    mov [cur_lba], ax
    mov ax, SCRATCH_SEG
    mov es, ax
    xor bx, bx
    mov ax, 1
    call chs_read_lba_count     ; reads 1 sector
    jc .final_error

    ; Validate magic
    push ds
    xor ax, ax
    mov ds, ax
    xor di, di
    mov ax, SCRATCH_SEG
    mov es, ax
    mov si, magic_ref
    mov cx, 8
.cmp_magic_chs:
    lodsb
    cmp al, byte es:[di]
    jne .hdr_bad_chs
    inc di
    loop .cmp_magic_chs
    pop ds

    ; Compute kernel sectors
    mov ax, SCRATCH_SEG
    mov es, ax
    mov bx, 8
    mov ax, word es:[bx]
    mov dx, word es:[bx+2]
    add ax, 511
    adc dx, 0
    mov cx, 9
.shr_loop2:
    shr dx, 1
    rcr ax, 1
    loop .shr_loop2
    mov [dyn_kernel_sectors], ax

    ; 2) Read kernel.bin via CHS from LBA+1
    mov ax, KERNEL_LBA+1
    mov [cur_lba], ax
    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    mov bx, KERNEL_LOAD_OFF
    mov cx, [dyn_kernel_sectors]
.chs_loop_kernel:
    cmp cx, 0
    je .kernel_loaded

    ; ensure not crossing 64KiB boundary
    mov ax, 0xFFFF
    sub ax, bx
    inc ax
    shr ax, 9
    cmp ax, 0
    jne .have_room_chs
    mov ax, es
    add ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ax, 0xFFFF
    sub ax, bx
    inc ax
    shr ax, 9
.have_room_chs:
    ; sectors remaining in this track
    push ax                     ; save boundary allowance
    mov ax, [cur_lba]
    xor dx, dx
    mov bl, [spt]
    div bl                      ; AX/BL => AL=quot, AH=rem
    mov si, 0                   ; clear SI
    mov si, ax                  ; SI=AX for later? not needed
    mov al, [spt]
    sub al, ah                  ; spt - (sector_index)
    inc al                      ; to end of track
    mov ah, 0                   ; AL=sectors to end of track
    mov dx, ax                  ; DX=sectors to end
    pop ax                      ; AX=boundary allowance
    cmp dx, ax
    jbe .use_dx
    mov dx, ax
.use_dx:
    ; DX now max sectors for this read based on boundary and track
    cmp dx, cx
    jbe .set_dx
    mov dx, cx
.set_dx:
    mov [tmp_count], dx
    ; Compute CHS from LBA
    mov ax, [cur_lba]
    xor dx, dx
    mov bl, [spt]
    div bl                      ; AX/BL => AL=quot, AH=sector_index
    mov bh, ah                  ; BH=sector index (0-based)
    xor ah, ah                  ; AL=quot
    mov bl, [heads]
    div bl                      ; AL= cylinder, AH=head
    mov ch, al                  ; CH=cylinder (low 8)
    mov cl, bh                  ; sector index
    inc cl                      ; sector number (1-based)
    mov dh, ah                  ; DH=head
    mov dl, [boot_drive]
    mov ah, 0x02
    mov al, byte [tmp_count]
    int 0x13
    jc .final_error

    ; advance pointers
    mov ax, [tmp_count]
    shl ax, 9
    add bx, ax
    mov ax, [tmp_count]
    add [cur_lba], ax
    sub cx, ax
    jmp .chs_loop_kernel

.hdr_bad_chs:
    pop ds
    mov si, msg_hdr_err
    call print_string
    jmp .final_error
    
.kernel_loaded:
    ; Restore ES
    xor ax, ax
    mov es, ax
    
    ; Success
    mov si, msg_kernel_ok
    call print_string
    
    ; Enable A20 (Fast A20 then KBC fallback)
    call enable_a20
    
    mov si, msg_a20
    call print_string
    
    ; Enter protected mode
    mov si, msg_pmode
    call print_string
    
    ; Small delay
    mov cx, 0x8000
.delay:
    loop .delay
    
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:protected_mode_start

bits 32
protected_mode_start:
    ; FIRST: Write debug directly to VGA to confirm we reach 32-bit mode
    mov dword [0xB8000], 0x2F322F33  ; "32" in white on green
    mov dword [0xB8004], 0x2F542F42  ; "BT" (32-bit)
    
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ; Write debug after segments setup
    mov dword [0xB8008], 0x2F472F53  ; "SG" (segments)
    
    ; Setup stack
    mov esp, 0x90000
    
    ; Write debug after stack setup
    mov dword [0xB800C], 0x2F502F53  ; "SP" (stack pointer)
    
    ; IMPORTANT: Disable interrupts before jumping to kernel
    cli
    
    ; Write debug before kernel jump
    mov dword [0xB8010], 0x2F4D2F4A  ; "JM" (jump)
    
    ; Jump to kernel with proper segment (code segment 0x08)
    jmp 0x08:0x10000

bits 16

; Print string
print_string:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    call print_char
    jmp .loop
.done:
    pop si
    pop ax
    ret

; Print character
print_char:
    push ax
    push bx
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    pop bx
    pop ax
    ret

; Print AL as hex byte
print_hex_byte:
    push ax
    push cx
    mov cl, al
    shr al, 4
    call print_nibble
    mov al, cl
    and al, 0x0F
    call print_nibble
    pop cx
    pop ax
    ret

print_nibble:
    and al, 0x0F
    add al, '0'
    cmp al, '9'
    jle .print
    add al, 7
.print:
    call print_char
    ret

; Data
boot_drive: db 0

; Disk Address Packet for LBA reads (filled dynamically)
dap:
    db 0x10                 ; Size
    db 0                    ; Reserved
dap_num_blocks:
    dw 0                    ; Number of sectors
dap_buf_off:
    dw 0                    ; Buffer offset
dap_buf_seg:
    dw 0                    ; Buffer segment
dap_lba_low:
    dd 0                    ; LBA low dword
dap_lba_high:
    dd 0                    ; LBA high dword

; Messages
msg_s2:         db 'S2 ', 0
msg_lba:        db 'LBA ', 0
msg_no_lba:     db 'NO-LBA ', 0
msg_chs:        db 'CHS ', 0
msg_kernel_ok:  db 'K-OK ', 0
msg_lba_err:    db 'LBA-ERR:', 0
msg_hdr_err:    db 'HDR-ERR', 0
msg_final_err:  db 'FINAL-ERR:', 0
msg_a20:        db 'A20 ', 0
msg_pmode:      db 'PM', 0

; Data variables
dyn_kernel_sectors: dw 0
cur_lba:            dw 0
spt:                db 18
heads:              db 2
tmp_count:          dw 0

magic_ref: db 'P','y','r','I','m','g','0','1'

; GDT
align 8
gdt_start:
    dq 0  ; Null descriptor
    ; Code segment
    dw 0xFFFF, 0x0000
    db 0x00, 10011010b, 11001111b, 0x00
    ; Data segment
    dw 0xFFFF, 0x0000
    db 0x00, 10010010b, 11001111b, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd 0x8000 + gdt_start

; --- Helpers ---

; Reset disk controller
disk_reset:
    push ax
    push dx
    mov dl, [boot_drive]
    mov ah, 0x00
    int 0x13
    pop dx
    pop ax
    ret

; Call int13h with retries for AH=42h (LBA read), SI=dap, DL=drive
int13_with_retries:
    push ax
    push cx
    push dx
    push si
    mov cx, 3
.retry:
    mov ah, 0x42
    int 0x13
    jnc .ok
    call disk_reset
    loop .retry
    stc
    jmp .done
.ok:
    clc
.done:
    pop si
    pop dx
    pop cx
    pop ax
    ret

; Wait for KBC input buffer to clear
kbc_wait_input_clear:
    push ax
.ib_wait:
    in al, 0x64
    test al, 2
    jnz .ib_wait
    pop ax
    ret

; Wait for KBC output buffer to have data
kbc_wait_output_full:
    push ax
.ob_wait:
    in al, 0x64
    test al, 1
    jz .ob_wait
    pop ax
    ret

; Enable A20 using Fast A20 then keyboard controller fallback
enable_a20:
    push ax
    ; Fast A20
    in al, 0x92
    or al, 2
    out 0x92, al

    ; KBC fallback sequence
    call kbc_wait_input_clear
    mov al, 0xAD                ; Disable keyboard
    out 0x64, al
    call kbc_wait_input_clear
    mov al, 0xD0                ; Read output port
    out 0x64, al
    call kbc_wait_output_full
    in al, 0x60                 ; Read current output port value
    or al, 00000010b            ; Set A20 enable bit
    call kbc_wait_input_clear
    mov ah, al                  ; Save new value in AH
    mov al, 0xD1                ; Write output port command
    out 0x64, al
    call kbc_wait_input_clear
    mov al, ah
    out 0x60, al                ; Write new output port value
    call kbc_wait_input_clear
    mov al, 0xAE                ; Re-enable keyboard
    out 0x64, al
    pop ax
    ret

; Read count sectors at [cur_lba] via CHS into ES:BX, updates [cur_lba]
; IN: AX=count (ignored, uses 1 in header read), ES:BX set, [cur_lba], [spt], [heads]
chs_read_lba_count:
    ; Compute CHS from [cur_lba]
    push ax
    push bx
    push cx
    push dx
    mov ax, [cur_lba]
    xor dx, dx
    mov bl, [spt]
    div bl
    mov bh, ah                  ; sector index 0-based
    xor ah, ah
    mov bl, [heads]
    div bl
    mov ch, al
    mov cl, bh
    inc cl
    mov dh, ah
    mov dl, [boot_drive]
    mov ah, 0x02
    mov al, 1
    int 0x13
    jc .chs_err_hdr
    inc word [cur_lba]
    clc
    jmp .chs_done
.chs_err_hdr:
    stc
.chs_done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

times 4096-($-$$) db 0