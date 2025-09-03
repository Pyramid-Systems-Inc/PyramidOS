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

    ; Verify checksum32 of kernel.bin (header[20..23]) before loading
    ; Compute sum over kernel.bin as we read: initialize accumulator to 0
    xor bx, bx
    mov [cksum_lo], bx
    mov [cksum_hi], bx

    ; Parse load and entry addresses from header
    ; Load address at offset 12 (dd)
    mov bx, 12
    mov ax, word es:[bx]        ; low
    mov dx, word es:[bx+2]      ; high
    mov si, ax                  ; save low
    mov cx, dx
    shl cx, 12                  ; high -> segment bits
    shr ax, 4
    or  ax, cx                  ; AX = segment
    mov [dest_seg], ax
    mov ax, si
    and ax, 0x000F              ; AX = offset
    mov [dest_off], ax

    ; Entry address at offset 16 (dd)
    mov bx, 16
    mov ax, word es:[bx]
    mov dx, word es:[bx+2]
    mov [kernel_entry32], ax
    mov [kernel_entry32+2], dx

    ; 2) Read kernel.bin starting from LBA+1 into destination
    mov ax, [dest_seg]
    test ax, ax
    jnz .use_hdr_dest
    mov ax, KERNEL_LOAD_SEG
    mov [dest_seg], ax
    mov ax, KERNEL_LOAD_OFF
    mov [dest_off], ax
.use_hdr_dest:
    mov ax, [dest_seg]
    mov es, ax
    mov bx, [dest_off]
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

    ; accumulate checksum over bytes just read: ES:BX - count*512
    push cx
    push dx
    push si
    push di
    mov si, bx
    mov di, [tmp_count]
    shl di, 9
    mov cx, di
    jcxz .skip_sum
.sum_loop:
    mov al, [es:si]
    xor ah, ah
    add [cksum_lo], ax
    adc [cksum_hi], word 0
    inc si
    loop .sum_loop
.skip_sum:
    pop di
    pop si
    pop dx
    pop cx

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
    mov ax, [dest_seg]
    mov es, ax
    mov bx, [dest_off]
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
    ; sectors remaining in this track (use 16-bit division)
    push ax                     ; save boundary allowance
    mov ax, [cur_lba]
    xor dx, dx
    mov bx, 0
    mov bl, [spt]
    div bx                      ; AX=quot, DX=remainder (sector index 0-based)
    mov ax, 0
    mov al, [spt]
    sub ax, dx                  ; AX = sectors to end of track
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
    ; Compute CHS from LBA and pack cylinder high bits into CL
    mov ax, [cur_lba]
    xor dx, dx
    mov bx, 0
    mov bl, [spt]
    div bx                      ; AX=quot, DX=sector_index (0-based)
    mov si, dx                  ; SI = sector_index
    xor dx, dx
    mov bx, 0
    mov bl, [heads]
    div bx                      ; AX=cylinder, DX=head
    mov ch, al                  ; CH = cylinder low 8 bits
    mov cl, sil                 ; sector_index low 8
    inc cl                      ; sector number (1-based)
    and cl, 0x3F                ; keep sector low 6 bits
    mov al, ch
    shr al, 2
    and al, 0xC0                ; cylinder high 2 bits
    or cl, al                   ; CL = (sector & 0x3F) | ((cyl>>2)&0xC0)
    mov dh, dl                  ; DH = head
    mov dl, [boot_drive]
    mov ah, 0x02
    mov al, byte [tmp_count]
    mov si, 3
.chs_try:
    int 0x13
    jnc .chs_ok
    call disk_reset
    dec si
    jnz .chs_try
    jc .final_error
.chs_ok:

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

    ; Read expected checksum from header and compare to accumulated
    mov ax, SCRATCH_SEG
    mov es, ax
    mov bx, 20
    mov ax, word es:[bx]
    mov dx, word es:[bx+2]
    ; Compare DX:AX to cksum_hi:cksum_lo
    cmp ax, [cksum_lo]
    jne .cksum_fail
    cmp dx, [cksum_hi]
    jne .cksum_fail
    jmp .cksum_ok
.cksum_fail:
    mov si, msg_cksum
    call print_string
    cli
    hlt
.cksum_ok:
    
    ; Enable A20 (Fast A20 then KBC fallback) and verify
    call enable_a20
    call verify_a20
    jnc .a20_ok
    ; retry once
    call enable_a20
    call verify_a20
    jc .a20_fail
.a20_ok:
    mov si, msg_a20
    call print_string
    jmp .after_a20
.a20_fail:
    mov si, msg_a20_fail
    call print_string
    cli
    hlt
.after_a20:
    
    ; Build BootInfo at 0x00005000
    mov ax, 0x0000
    mov es, ax
    mov di, 0x5000
    ; magic 'BOOT'
    mov word [es:di], 0x4F4F
    mov word [es:di+2], 0x5442
    ; version
    mov word [es:di+4], 0x0001
    ; boot drive
    mov al, [boot_drive]
    mov [es:di+6], al
    ; kernel load seg:off
    mov ax, [dest_seg]
    mov [es:di+8], ax
    mov ax, [dest_off]
    mov [es:di+10], ax
    ; kernel size bytes from header
    mov ax, SCRATCH_SEG
    mov ds, ax
    mov bx, 8
    mov ax, word [ds:bx]
    mov dx, word [ds:bx+2]
    mov word [es:0x5010], ax
    mov word [es:0x5012], dx
    ; initialize e820 fields
    mov dword [es:0x5014], 0          ; entry count
    mov dword [es:0x5018], 0x00005020 ; table pointer
    ; collect E820 memory map into 0x00005020
    xor ebx, ebx
    mov di, 0x5020
    xor bp, bp                         ; entry counter
.e820_next:
    mov eax, 0xE820
    mov edx, 0x534D4150               ; 'SMAP'
    mov ecx, 24
    push es
    mov ax, 0x0000
    mov es, ax
    int 0x15
    pop es
    jc .e820_done
    cmp eax, 0x534D4150
    jne .e820_done
    add di, 24
    inc bp
    test ebx, ebx
    jnz .e820_next
.e820_done:
    mov ax, bp
    mov word [es:0x5014], ax
    mov word [es:0x5016], 0
    ; pass EBX = 0x00005000 to kernel in protected mode later (optional)
    mov bx, 0x5000

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
    ; If header provided entry, use it; else default 0x00010000
    mov eax, [kernel_entry32]
    test eax, eax
    jz .default_entry
    jmp eax
.default_entry:
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
msg_cksum:      db 'CKSUM-ERR', 0
msg_final_err:  db 'FINAL-ERR:', 0
msg_a20:        db 'A20 ', 0
msg_a20_fail:   db 'A20-FAIL', 0
msg_pmode:      db 'PM', 0

; Data variables
dyn_kernel_sectors: dw 0
cur_lba:            dw 0
spt:                db 18
heads:              db 2
tmp_count:          dw 0

magic_ref: db 'P','y','r','I','m','g','0','1'

; Destination and entry parsed from header
dest_seg:           dw 0
dest_off:           dw 0
kernel_entry32:     dd 0

; Running checksum accumulator (32-bit in two words)
cksum_lo:           dw 0
cksum_hi:           dw 0

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

; Verify A20 by checking wraparound between 0x000000 and 0x00100000
verify_a20:
    push ds
    push es
    push ax
    push bx
    mov ax, 0x0000
    mov ds, ax
    mov ax, 0x1000
    mov es, ax
    mov bx, 0
    mov al, [ds:bx]
    mov ah, [es:bx]
    mov [ds:bx], 0x5A
    mov [es:bx], 0xA5
    cmp [ds:bx], 0x5A
    jne .set_carry
    cmp [es:bx], 0xA5
    jne .set_carry
    clc
    jmp .done
.set_carry:
    stc
.done:
    pop bx
    pop ax
    pop es
    pop ds
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