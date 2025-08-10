; boot/src/legacy/stage2.asm
bits 16
org 0x8000

; Constants
KERNEL_LOAD_SEG     equ 0x1000
KERNEL_LOAD_OFF     equ 0x0000
KERNEL_LBA          equ 60      
KERNEL_SECTOR_COUNT equ 16      ; Load 16 sectors (8KB)

; For standard floppy: 18 sectors/track, 2 heads, 80 cylinders
; LBA 60 = C:1, H:1, S:7
KERNEL_CYLINDER     equ 1
KERNEL_HEAD         equ 1  
KERNEL_SECTOR       equ 7       

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
    
    ; Try Method 1: LBA read using INT 13h extensions
    mov ah, 0x41        
    mov bx, 0x55AA
    mov dl, [boot_drive]
    int 0x13
    jc .use_chs         
    cmp bx, 0xAA55
    jne .use_chs
    
    ; Use LBA read
    mov si, msg_lba
    call print_string
    
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, kernel_dap
    int 0x13
    jnc .kernel_loaded
    
    ; LBA failed, show error and try CHS
    mov si, msg_lba_err
    call print_string
    mov al, ah
    call print_hex_byte
    
.use_chs:
    ; Use CHS read - READ IN SMALLER CHUNKS
    mov si, msg_chs
    call print_string
    
    ; Reset floppy controller first
    mov ah, 0x00
    mov dl, [boot_drive]
    int 0x13
    
    ; Read kernel in multiple chunks to avoid track boundary issues
    mov cx, 0                   ; Sectors read counter
    mov bx, KERNEL_LOAD_OFF     ; Current offset
    
.read_loop:
    ; Setup ES:BX for current read
    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    
    ; Calculate how many sectors to read this time (max 8 to stay safe)
    mov ax, KERNEL_SECTOR_COUNT
    sub ax, cx                  ; Remaining sectors
    cmp ax, 8                   ; Read max 8 sectors at a time
    jle .read_chunk
    mov ax, 8
    
.read_chunk:
    ; Save registers
    push ax
    push bx  
    push cx
    
    ; Read sectors
    mov ah, 0x02                ; Read sectors function
    ; AL already has sector count
    mov ch, KERNEL_CYLINDER     ; Cylinder 1
    mov cl, KERNEL_SECTOR       ; Start sector 7
    add cl, cl                  ; Add sectors already read
    mov dh, KERNEL_HEAD         ; Head 1
    mov dl, [boot_drive]        ; Drive
    
    int 0x13
    jc .chs_error
    
    ; Restore registers and update counters
    pop cx
    pop bx
    pop ax
    
    add cx, ax                  ; Update sectors read
    shl ax, 9                   ; Convert sectors to bytes (×512)
    add bx, ax                  ; Update buffer offset
    
    ; Check if we've read all sectors
    cmp cx, KERNEL_SECTOR_COUNT
    jl .read_loop
    
    ; Success!
    jmp .kernel_loaded
    
.chs_error:
    pop cx
    pop bx
    pop ax
    mov si, msg_chs_err
    call print_string
    mov al, ah
    call print_hex_byte
    
    ; Try a simple single-sector read as test
    mov si, msg_test
    call print_string
    
    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    mov bx, KERNEL_LOAD_OFF
    
    mov ah, 0x02                ; Read sectors
    mov al, 1                   ; Just 1 sector
    mov ch, KERNEL_CYLINDER     ; Cylinder 1
    mov cl, KERNEL_SECTOR       ; Sector 7
    mov dh, KERNEL_HEAD         ; Head 1
    mov dl, [boot_drive]        ; Drive
    int 0x13
    jc .final_error
    
    ; Single sector worked, continue with simplified kernel
    mov si, msg_partial
    call print_string
    jmp .kernel_loaded
    
.final_error:
    mov si, msg_final_err
    call print_string
    mov al, ah
    call print_hex_byte
    cli
    hlt
    
.kernel_loaded:
    ; Restore ES
    xor ax, ax
    mov es, ax
    
    ; Success
    mov si, msg_kernel_ok
    call print_string
    
    ; Enable A20
    in al, 0x92
    or al, 2
    out 0x92, al
    
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
    ; Setup segments
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000
    
    ; Jump directly to kernel
    jmp 0x10000

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

; Disk Address Packet for LBA read
kernel_dap:
    db 0x10                 ; Size
    db 0                    ; Reserved
    dw KERNEL_SECTOR_COUNT  ; Sectors to read
    dw KERNEL_LOAD_OFF      ; Buffer offset
    dw KERNEL_LOAD_SEG      ; Buffer segment
    dq KERNEL_LBA           ; LBA

; Messages
msg_s2:         db 'S2 ', 0
msg_lba:        db 'LBA ', 0
msg_chs:        db 'CHS ', 0
msg_kernel_ok:  db 'K-OK ', 0
msg_lba_err:    db 'LBA-ERR:', 0
msg_chs_err:    db 'CHS-ERR:', 0
msg_test:       db 'TEST ', 0
msg_partial:    db 'PART ', 0
msg_final_err:  db 'FINAL-ERR:', 0
msg_a20:        db 'A20 ', 0
msg_pmode:      db 'PM', 0

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
    dd gdt_start + 0x8000

times 2048-($-$$) db 0