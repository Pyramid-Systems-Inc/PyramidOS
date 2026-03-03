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

%ifndef STAGE2_SECTOR_COUNT
    STAGE2_SECTOR_COUNT equ 32
%endif

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

    ; --------------------------------------------------------------------------
    ; Tier 1 Bootloader UX (Stage 2): branded screen + status panel + progress bar
    ; --------------------------------------------------------------------------
    call ui_init
    call ui_poll_boot_menu
    call ui_draw_boot_screen
    call ui_status_init_all
    call ui_anim_intro

    ; 2. Enable A20 Line
    call enable_a20
    call check_a20
    cmp ax, 1
    je .a20_success
    call ui_status_a20_fail
    mov si, msg_ar_err_a20
    call ui_fatal_print_u16
    jmp .halt_cpu

.a20_success:
    call ui_status_a20_ok
    mov si, msg_a20_ok
    call ui_maybe_print_string

    ; 3. Get Memory Map (E820)
    call do_e820
    call ui_status_e820_ok
    mov si, msg_e820_ok
    call ui_maybe_print_string

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

    call ui_status_hdr_ok
    mov si, msg_hdr_ok
    call ui_maybe_print_string

    ; 6. Calculate Kernel Size
    ; Offset 8 in header = Kernel Size (bytes)
    mov eax, [es:8]         ; Load 32-bit size
    mov [kernel_size], eax

    ; Offset 20 in header = checksum (sum32 of kernel.bin bytes)
    mov edx, [es:20]
    mov [kernel_checksum_expected], edx

    ; Calculate sector count: (Size + 511) / 512
    add eax, 511
    shr eax, 9              ; Divide by 512
    mov [kernel_sectors], ax
    mov [kernel_sectors_total], ax

    ; 7. Load Kernel Body
    ; Destination: KERNEL_LOAD_SEG:0000
    ; Start LBA: KERNEL_LBA + 1 (Skip header sector)

    call ui_status_kernel_loading
    call ui_progress_init
    mov si, msg_loading
    call ui_maybe_print_string

    mov ax, KERNEL_LOAD_SEG
    mov es, ax
    xor bx, bx              ; Destination Offset
    
    mov eax, KERNEL_LBA + 1 ; Start LBA
    movzx ecx, word [kernel_sectors]

    ; Read loop handling 64KB boundaries is inside read_sectors_lba? 
    ; No, the simple reader below assumes small reads.
    ; We need a robust loop here.
    
    call read_kernel_robust

    call ui_status_kernel_ok
    mov si, msg_kernel_ok
    call ui_maybe_print_string

    ; 8. Verify kernel checksum (halts on mismatch).
    call ui_checksum_verify

    ; 9. Prepare BootInfo Structure
    call setup_boot_info

    ; 10. Enter Protected Mode
    call ui_status_pmode_ok

    ; Give the user a brief moment to see the final state in Quiet mode.
    call ui_anim_outro

    ; Tier 2: Keep the splash visible (ENTER skips).
    call ui_wait_enter_or_timeout

    ; Ensure the kernel starts in VGA text mode (even if we showed a graphics splash).
    call ui_prepare_for_kernel

    cli                     ; Disable interrupts for good

    lgdt [gdt_descriptor]   ; Load GDT

    mov eax, cr0
    or eax, 1               ; Set PE bit
    mov cr0, eax

    ; Far jump to flush pipeline
    jmp 0x08:pmode_entry

.bad_magic:
    call ui_status_hdr_fail
    mov si, msg_ar_err_hdr
    call ui_fatal_print_u16
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

    ; Update progress bar (CX = remaining sectors).
    call ui_update_progress

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
    call ui_status_kernel_fail
    ; Force a visible fatal message even in Quiet/Splash mode.
    mov al, ah
    push ax                 ; save error code

    call ui_fatal_prepare

    mov si, msg_ar_err_disk
    mov ax, UI_GFX_RIGHT_X
    mov dx, 80
    mov bl, 0x0C            ; red
    call gfx_write_u16_rtl

    mov si, msg_ar_err_code
    mov ax, UI_GFX_RIGHT_X
    mov dx, 96
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov si, msg_ascii_0x
    mov ax, 8
    mov dx, 112
    mov bl, GFX_TEXT_COLOR
    call gfx_write_ascii_ltr

    pop ax                  ; AL=error
    mov ah, al
    mov ax, 24              ; x after "0x"
    mov al, ah
    mov dx, 112
    mov bl, GFX_TEXT_COLOR
    call gfx_write_hex8_ltr

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
; Tier 1 Bootloader UX Helpers (Text Mode, VGA 80x25)
; ------------------------------------------------------------------------------
VGA_SEG            equ 0xB800
VGA_COLS           equ 80
VGA_ROWS           equ 25

UI_ATTR_BASE       equ 0x1F        ; White on Blue
UI_ATTR_TITLE      equ 0x1E        ; Yellow on Blue
UI_ATTR_LABEL      equ 0x1F        ; White on Blue
UI_ATTR_OK         equ 0x1A        ; Light Green on Blue
UI_ATTR_FAIL       equ 0x1C        ; Light Red on Blue
UI_ATTR_DIM        equ 0x17        ; Light Grey on Blue

UI_COL_LABEL       equ 2
UI_COL_STATUS      equ 62

UI_ROW_TITLE       equ 1
UI_ROW_RULE        equ 2
UI_ROW_STATUS_A20  equ 6
UI_ROW_STATUS_E820 equ 7
UI_ROW_STATUS_HDR  equ 8
UI_ROW_STATUS_KERN equ 9
UI_ROW_STATUS_PM   equ 10
UI_ROW_STATUS_CSUM equ 11

UI_ROW_PROGRESS    equ 22
UI_ROW_PROGRESS_INFO equ 23
UI_ROW_HINT        equ 24

UI_PROG_COL_BAR    equ 16
UI_PROG_WIDTH      equ 50

UI_ROW_SPINNER     equ UI_ROW_HINT
UI_COL_SPINNER     equ 79

; Animation pacing (Quiet mode only).
UI_INTRO_STEPS       equ 20
UI_INTRO_DELAY_CX    equ 0x0000
UI_INTRO_DELAY_DX    equ 0xC350    ; 50,000us = 50ms (1s total)

UI_PROGRESS_DELAY_CX equ 0x0000
UI_PROGRESS_DELAY_DX equ 0x3A98    ; 15,000us = 15ms

UI_OUTRO_STEPS       equ 10
UI_OUTRO_DELAY_CX    equ 0x0000
UI_OUTRO_DELAY_DX    equ 0x7530    ; 30,000us = 30ms (300ms total)

; Tier 2 autoboot pause (Splash mode only)
UI_WAIT_SECS            equ 30
UI_WAIT_TICKS_PER_SEC   equ 20
UI_WAIT_TICK_DELAY_CX   equ 0x0000
UI_WAIT_TICK_DELAY_DX   equ 0xC350    ; 50,000us = 50ms

; Tier 2 (Mode 13h splash) constants
GFX_SEG              equ 0xA000
GFX_WIDTH            equ 320
GFX_HEIGHT           equ 200
GFX_FONT_W           equ 8
GFX_FONT_H           equ 16

GFX_BG_COLOR         equ 0x01      ; blue
GFX_LOGO_COLOR       equ 0x0E      ; yellow
GFX_TEXT_COLOR       equ 0x0F      ; white
GFX_DIM_COLOR        equ 0x08      ; dark gray
GFX_BAR_BORDER_COLOR equ 0x0F      ; white
GFX_BAR_BG_COLOR     equ 0x08      ; dark gray
GFX_BAR_FILL_COLOR   equ 0x0A      ; light green
GFX_SPINNER_COLOR    equ 0x0F      ; white

GFX_LOGO_Y_START     equ 52
GFX_LOGO_X_CENTER    equ 160
GFX_LOGO_HEIGHT      equ 28

GFX_BAR_X            equ 60
GFX_BAR_Y            equ 148
GFX_BAR_W            equ 200
GFX_BAR_H            equ 8

GFX_SPIN_X           equ 316
GFX_SPIN_Y           equ 132

UI_GFX_RIGHT_X       equ 312
UI_GFX_Y_TITLE       equ 8
UI_GFX_Y_SUBTITLE    equ 24
UI_GFX_Y_CHECKSUM    equ 112
UI_GFX_Y_COUNTDOWN   equ 160
UI_GFX_Y_HINT        equ 176

; Frame around the status panel
UI_FRAME_TOP       equ 5
UI_FRAME_BOTTOM    equ 12
UI_FRAME_LEFT      equ 1
UI_FRAME_RIGHT     equ 78

; Function: ui_maybe_print_string
; Input: SI = pointer to null-terminated string
ui_maybe_print_string:
    cmp byte [ui_verbose], 0
    je .skip
    call print_string
.skip:
    ret

; Function: ui_init
; Sets defaults and enters splash mode immediately (Arabic-first UX).
ui_init:
    push ax
    mov byte [ui_verbose], 0
    mov byte [ui_spin_idx], 0
    mov byte [ui_gfx], 1
    call gfx_set_mode_13
    mov bl, GFX_BG_COLOR
    call gfx_clear

    pop ax
    ret

; Function: ui_hide_cursor
; Uses BIOS INT 10h to hide the text cursor by setting start scanline to 0x20.
ui_hide_cursor:
    push ax
    push cx
    mov ah, 0x01
    mov ch, 0x20
    mov cl, 0x00
    int 0x10
    pop cx
    pop ax
    ret

; Function: ui_show_cursor
; Restore a normal cursor shape (safe before leaving real mode).
ui_show_cursor:
    push ax
    push cx
    mov ah, 0x01
    mov ch, 0x06
    mov cl, 0x07
    int 0x10
    pop cx
    pop ax
    ret

; Function: ui_prepare_for_kernel
; Ensure kernel-visible text mode is active, then restore a normal cursor.
ui_prepare_for_kernel:
    push ax
    cmp byte [ui_gfx], 0
    je .cursor

    mov ax, 0x0003
    int 0x10

.cursor:
    call ui_show_cursor
    pop ax
    ret

; Function: ui_fatal_prepare
; Force graphics mode so fatal errors can show Arabic text reliably.
ui_fatal_prepare:
    push ax
    call gfx_set_mode_13
    mov bl, GFX_BG_COLOR
    call gfx_clear
    mov byte [ui_gfx], 1
    pop ax
    ret

; Function: ui_fatal_print_u16
; Input: SI = pointer to 0-terminated u16 string (printed unconditionally).
ui_fatal_print_u16:
    call ui_fatal_prepare
    mov ax, UI_GFX_RIGHT_X
    mov dx, 80
    mov bl, 0x0C            ; red
    call gfx_write_u16_rtl
    ret

; Function: ui_sleep_us
; Sleep for a given duration using BIOS INT 15h, AH=86h.
; Input: CX:DX = microseconds.
; Preserves all general registers.
ui_sleep_us:
    pusha
    mov si, cx
    mov di, dx

    mov ah, 0x86
    int 0x15
    jnc .done

    ; Fallback: crude busy-wait if BIOS wait isn't supported.
    mov bx, si              ; high
    test bx, bx
    jz .only_low
.outer:
    mov cx, di              ; low
.inner:
    loop .inner
    dec bx
    jnz .outer
    jmp .done

.only_low:
    mov cx, di
.inner2:
    loop .inner2

.done:
    popa
    ret

; Function: ui_spinner_step
; Update a small spinner in the bottom-right to show that Stage 2 is alive.
ui_spinner_step:
    pusha

    cmp byte [ui_gfx], 0
    je .text

    ; Mode 13h spinner: rotate a single pixel around a small 4-point cross.
    mov al, [ui_spin_idx]
    and al, 3

    ; Clear all spinner points to background color.
    mov bl, GFX_BG_COLOR
    mov ax, GFX_SPIN_X
    mov dx, GFX_SPIN_Y - 2
    call gfx_putpixel
    mov ax, GFX_SPIN_X + 2
    mov dx, GFX_SPIN_Y
    call gfx_putpixel
    mov ax, GFX_SPIN_X
    mov dx, GFX_SPIN_Y + 2
    call gfx_putpixel
    mov ax, GFX_SPIN_X - 2
    mov dx, GFX_SPIN_Y
    call gfx_putpixel

    ; Draw active point.
    mov bl, GFX_SPINNER_COLOR
    cmp al, 0
    je .spin_up
    cmp al, 1
    je .spin_right
    cmp al, 2
    je .spin_down
    ; else left
    mov ax, GFX_SPIN_X - 2
    mov dx, GFX_SPIN_Y
    jmp .spin_draw
.spin_up:
    mov ax, GFX_SPIN_X
    mov dx, GFX_SPIN_Y - 2
    jmp .spin_draw
.spin_right:
    mov ax, GFX_SPIN_X + 2
    mov dx, GFX_SPIN_Y
    jmp .spin_draw
.spin_down:
    mov ax, GFX_SPIN_X
    mov dx, GFX_SPIN_Y + 2
.spin_draw:
    call gfx_putpixel
    jmp .inc

.text:
    mov al, [ui_spin_idx]
    and al, 3
    xor ah, ah
    mov si, spinner_chars
    add si, ax
    mov al, [si]

    mov dh, UI_ROW_SPINNER
    mov dl, UI_COL_SPINNER
    mov bl, UI_ATTR_DIM
    call vga_putc_at

    ; fallthrough

.inc:
    inc byte [ui_spin_idx]

    popa
    ret

; Function: ui_anim_intro
; Brief animation so the boot UI is visible even on fast boots.
ui_anim_intro:
    cmp byte [ui_verbose], 0
    jne .done

    pusha
    mov cx, UI_INTRO_STEPS
.loop:
    call ui_spinner_step

    push cx
    mov cx, UI_INTRO_DELAY_CX
    mov dx, UI_INTRO_DELAY_DX
    call ui_sleep_us
    pop cx

    loop .loop
    popa

.done:
    ret

; Function: ui_anim_progress_tick
; Small delay + spinner update per progress update (Quiet mode only).
ui_anim_progress_tick:
    cmp byte [ui_verbose], 0
    jne .done

    pusha
    call ui_spinner_step
    mov cx, UI_PROGRESS_DELAY_CX
    mov dx, UI_PROGRESS_DELAY_DX
    call ui_sleep_us
    popa

.done:
    ret

; Function: ui_anim_outro
; Brief pause so the final OK/FAIL state is readable before jumping to the kernel.
ui_anim_outro:
    cmp byte [ui_verbose], 0
    jne .done

    pusha
    mov cx, UI_OUTRO_STEPS
.loop:
    call ui_spinner_step

    push cx
    mov cx, UI_OUTRO_DELAY_CX
    mov dx, UI_OUTRO_DELAY_DX
    call ui_sleep_us
    pop cx

    loop .loop
    popa

.done:
    ret

; Function: ui_kbd_flush
; Drain any pending BIOS keystrokes.
ui_kbd_flush:
    push ax
.loop:
    mov ah, 0x01
    int 0x16
    jz .done
    mov ah, 0x00
    int 0x16
    jmp .loop
.done:
    pop ax
    ret

; Function: ui_wait_enter_or_timeout
; Splash-only: wait up to UI_WAIT_SECS seconds; ENTER skips the wait.
ui_wait_enter_or_timeout:
    cmp byte [ui_gfx], 0
    je .done

    pusha

    mov bp, UI_WAIT_SECS
.sec_loop:
    ; Update countdown digits in-place (ui_countdown_digit_* are u16 code units).
    mov ax, bp
    aam                     ; AH=tens, AL=ones (base 10)
    mov dl, al              ; ones
    mov dh, ah              ; tens

    cmp dh, 0
    jne .tens_nonzero
    mov word [ui_countdown_digit_tens], 0x0020
    jmp .tens_done
.tens_nonzero:
    mov al, dh
    xor ah, ah
    add ax, 0x0030
    mov [ui_countdown_digit_tens], ax
.tens_done:

    mov al, dl
    xor ah, ah
    add ax, 0x0030
    mov [ui_countdown_digit_ones], ax

    ; Clear + redraw countdown line and the ENTER hint.
    mov ax, 0
    mov dx, UI_GFX_Y_COUNTDOWN
    mov cx, GFX_WIDTH
    mov si, GFX_FONT_H
    mov bl, GFX_BG_COLOR
    call gfx_fill_rect

    mov si, ui_countdown_buf
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_COUNTDOWN
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov ax, 0
    mov dx, UI_GFX_Y_HINT
    mov cx, GFX_WIDTH
    mov si, GFX_FONT_H
    mov bl, GFX_BG_COLOR
    call gfx_fill_rect

    mov si, msg_ar_enter_hint
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_HINT
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov di, UI_WAIT_TICKS_PER_SEC
.tick_loop:
    ; ENTER skips.
    mov ah, 0x01
    int 0x16
    jz .no_key
    mov ah, 0x00
    int 0x16
    cmp al, 13
    je .skip

.no_key:
    call ui_spinner_step
    mov cx, UI_WAIT_TICK_DELAY_CX
    mov dx, UI_WAIT_TICK_DELAY_DX
    call ui_sleep_us
    dec di
    jnz .tick_loop

    dec bp
    jnz .sec_loop
    jmp .out

.skip:
    call ui_kbd_flush

.out:
    popa

.done:
    ret

; Function: ui_poll_boot_menu
; Offer a simple F8 menu (Arabic) before boot.
ui_poll_boot_menu:
    push ax
    push cx
    push dx

    ; Poll for a bounded loop (no timer dependency).
    mov cx, 0x4000
.poll:
    mov ah, 0x01
    int 0x16
    jz .no_key

    mov ah, 0x00
    int 0x16          ; AL=ASCII, AH=scan
    cmp ah, 0x42      ; F8 scancode
    jne .no_key

    call ui_show_boot_menu
    jmp .done

.no_key:
    loop .poll

.done:
    pop dx
    pop cx
    pop ax
    ret

; Function: ui_show_boot_menu
; Lets the user choose Normal (animated) or Fast (no animations).
ui_show_boot_menu:
    push ax
    push bx
    push cx
    push dx
    push si

    call ui_fatal_prepare

    ; Title
    mov si, msg_ar_menu_title
    mov ax, UI_GFX_RIGHT_X
    mov dx, 40
    mov bl, GFX_TEXT_COLOR
    call gfx_write_u16_rtl

    ; Options
    mov si, msg_ar_menu_1
    mov ax, UI_GFX_RIGHT_X
    mov dx, 72
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov si, msg_ar_menu_2
    mov ax, UI_GFX_RIGHT_X
    mov dx, 88
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov si, msg_ar_menu_prompt
    mov ax, UI_GFX_RIGHT_X
    mov dx, 120
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

.wait_key:
    mov ah, 0x00
    int 0x16
    cmp al, '1'
    je .quiet
    cmp al, '2'
    je .verbose
    jmp .wait_key

.quiet:
    mov byte [ui_verbose], 0
    mov byte [ui_gfx], 1
    jmp .out
.verbose:
    mov byte [ui_verbose], 1
    mov byte [ui_gfx], 1
.out:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Function: ui_draw_boot_screen
ui_draw_boot_screen:
    cmp byte [ui_gfx], 0
    je .text

    call ui_gfx_draw_boot_screen
    ret

.text:
    push ax
    push bx
    push dx
    push si

    mov bl, UI_ATTR_BASE
    call vga_clear

    ; Title
    mov si, msg_ui_title
    mov dh, UI_ROW_TITLE
    mov dl, 2
    mov bl, UI_ATTR_TITLE
    call vga_write_string_at

    ; Rule
    mov si, msg_ui_rule
    mov dh, UI_ROW_RULE
    mov dl, 0
    mov bl, UI_ATTR_DIM
    call vga_write_string_at

    ; ASCII logo (simple + fast)
    mov si, msg_logo_1
    mov dh, 3
    mov dl, 2
    mov bl, UI_ATTR_TITLE
    call vga_write_string_at

    mov si, msg_logo_2
    mov dh, 4
    mov dl, 2
    mov bl, UI_ATTR_DIM
    call vga_write_string_at

    ; Status frame (box around the status panel)
    call ui_draw_frame

    ; Hint
    mov si, msg_hint_f8
    mov dh, UI_ROW_HINT
    mov dl, 0
    mov bl, UI_ATTR_DIM
    call vga_write_string_at

    pop si
    pop dx
    pop bx
    pop ax
    ret

; Function: ui_draw_frame
; Draw a simple box around the status panel area.
ui_draw_frame:
    push ax
    push bx
    push cx
    push dx

    mov bl, UI_ATTR_DIM

    ; Top border
    mov dh, UI_FRAME_TOP
    mov dl, UI_FRAME_LEFT
    mov al, 0xC9            ; '┌'
    call vga_putc_at

    mov cx, UI_FRAME_RIGHT - UI_FRAME_LEFT - 1
    inc dl
.top_h:
    mov al, 0xCD            ; '─'
    call vga_putc_at
    inc dl
    loop .top_h

    mov al, 0xBB            ; '┐'
    call vga_putc_at

    ; Side borders
    mov cx, UI_FRAME_BOTTOM - UI_FRAME_TOP - 1
    mov dh, UI_FRAME_TOP
.sides:
    inc dh
    mov dl, UI_FRAME_LEFT
    mov al, 0xBA            ; '│'
    call vga_putc_at

    mov dl, UI_FRAME_RIGHT
    mov al, 0xBA            ; '│'
    call vga_putc_at

    loop .sides

    ; Bottom border
    mov dh, UI_FRAME_BOTTOM
    mov dl, UI_FRAME_LEFT
    mov al, 0xC8            ; '└'
    call vga_putc_at

    mov cx, UI_FRAME_RIGHT - UI_FRAME_LEFT - 1
    inc dl
.bot_h:
    mov al, 0xCD            ; '─'
    call vga_putc_at
    inc dl
    loop .bot_h

    mov al, 0xBC            ; '┘'
    call vga_putc_at

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Function: ui_status_init_all
ui_status_init_all:
    cmp byte [ui_gfx], 0
    jne .done

    push bx
    push dx
    push si

    ; Labels
    mov si, msg_lbl_a20
    mov dh, UI_ROW_STATUS_A20
    mov dl, UI_COL_LABEL
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at
    call ui_status_a20_pending

    mov si, msg_lbl_e820
    mov dh, UI_ROW_STATUS_E820
    mov dl, UI_COL_LABEL
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at
    call ui_status_e820_pending

    mov si, msg_lbl_hdr
    mov dh, UI_ROW_STATUS_HDR
    mov dl, UI_COL_LABEL
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at
    call ui_status_hdr_pending

    mov si, msg_lbl_kernel
    mov dh, UI_ROW_STATUS_KERN
    mov dl, UI_COL_LABEL
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at
    call ui_status_kernel_pending

    mov si, msg_lbl_pm
    mov dh, UI_ROW_STATUS_PM
    mov dl, UI_COL_LABEL
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at
    call ui_status_pmode_pending

    mov si, msg_lbl_checksum
    mov dh, UI_ROW_STATUS_CSUM
    mov dl, UI_COL_LABEL
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at
    call ui_status_csum_pending

    pop si
    pop dx
    pop bx
.done:
    ret

; Status helpers (write at fixed column).
ui_status_a20_pending:
    mov si, msg_stat_pending
    mov dh, UI_ROW_STATUS_A20
    jmp ui_status_write_dim
ui_status_a20_ok:
    mov si, msg_stat_ok
    mov dh, UI_ROW_STATUS_A20
    jmp ui_status_write_ok
ui_status_a20_fail:
    mov si, msg_stat_fail
    mov dh, UI_ROW_STATUS_A20
    jmp ui_status_write_fail

ui_status_e820_pending:
    mov si, msg_stat_pending
    mov dh, UI_ROW_STATUS_E820
    jmp ui_status_write_dim
ui_status_e820_ok:
    mov si, msg_stat_ok
    mov dh, UI_ROW_STATUS_E820
    jmp ui_status_write_ok

ui_status_hdr_pending:
    mov si, msg_stat_pending
    mov dh, UI_ROW_STATUS_HDR
    jmp ui_status_write_dim
ui_status_hdr_ok:
    mov si, msg_stat_ok
    mov dh, UI_ROW_STATUS_HDR
    jmp ui_status_write_ok
ui_status_hdr_fail:
    mov si, msg_stat_fail
    mov dh, UI_ROW_STATUS_HDR
    jmp ui_status_write_fail

ui_status_kernel_pending:
    mov si, msg_stat_pending
    mov dh, UI_ROW_STATUS_KERN
    jmp ui_status_write_dim
ui_status_kernel_loading:
    mov si, msg_stat_loading
    mov dh, UI_ROW_STATUS_KERN
    jmp ui_status_write_dim
ui_status_kernel_ok:
    mov si, msg_stat_ok
    mov dh, UI_ROW_STATUS_KERN
    jmp ui_status_write_ok
ui_status_kernel_fail:
    mov si, msg_stat_fail
    mov dh, UI_ROW_STATUS_KERN
    jmp ui_status_write_fail

ui_status_pmode_pending:
    mov si, msg_stat_pending
    mov dh, UI_ROW_STATUS_PM
    jmp ui_status_write_dim
ui_status_pmode_ok:
    mov si, msg_stat_ok
    mov dh, UI_ROW_STATUS_PM
    jmp ui_status_write_ok

ui_status_csum_pending:
    mov si, msg_stat_pending
    mov dh, UI_ROW_STATUS_CSUM
    jmp ui_status_write_dim
ui_status_csum_loading:
    mov si, msg_stat_chk
    mov dh, UI_ROW_STATUS_CSUM
    jmp ui_status_write_dim
ui_status_csum_ok:
    mov si, msg_stat_ok
    mov dh, UI_ROW_STATUS_CSUM
    jmp ui_status_write_ok
ui_status_csum_fail:
    mov si, msg_stat_fail
    mov dh, UI_ROW_STATUS_CSUM
    jmp ui_status_write_fail
ui_status_csum_skip:
    mov si, msg_stat_skip
    mov dh, UI_ROW_STATUS_CSUM
    jmp ui_status_write_skip

ui_status_write_dim:
    mov dl, UI_COL_STATUS
    mov bl, UI_ATTR_DIM
    call vga_write_string_at
    ret
ui_status_write_ok:
    mov dl, UI_COL_STATUS
    mov bl, UI_ATTR_OK
    call vga_write_string_at
    ret
ui_status_write_fail:
    mov dl, UI_COL_STATUS
    mov bl, UI_ATTR_FAIL
    call vga_write_string_at
    ret
ui_status_write_skip:
    mov dl, UI_COL_STATUS
    mov bl, UI_ATTR_DIM
    call vga_write_string_at
    ret

; Progress bar init
ui_progress_init:
    cmp byte [ui_gfx], 0
    je .text

    call ui_gfx_progress_init
    ret

.text:
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, msg_lbl_progress
    mov dh, UI_ROW_PROGRESS
    mov dl, 2
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at

    ; Reset cached progress (for delta updates).
    mov word [ui_prog_prev_filled], 0

    ; Draw empty bar
    mov cx, UI_PROG_WIDTH
    mov dh, UI_ROW_PROGRESS
    mov dl, UI_PROG_COL_BAR
    mov bl, UI_ATTR_DIM
.draw_empty:
    mov al, 0xB0            ; light shade block
    call vga_putc_at
    inc dl
    loop .draw_empty

    ; Print initial 0%
    mov ax, 0
    mov dh, UI_ROW_PROGRESS
    mov dl, UI_PROG_COL_BAR + UI_PROG_WIDTH + 2
    mov bl, UI_ATTR_LABEL
    call vga_print_percent_at

    ; Print sector counters on a dedicated line to avoid 80-col overflow
    mov si, msg_lbl_sectors
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 2
    mov bl, UI_ATTR_LABEL
    call vga_write_string_at

    ; done (0)
    mov ax, 0
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 16
    mov bl, UI_ATTR_LABEL
    call vga_print_u16_5_at

    mov al, '/'
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 21
    mov bl, UI_ATTR_LABEL
    call vga_putc_at

    ; total
    mov ax, [kernel_sectors_total]
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 22
    mov bl, UI_ATTR_LABEL
    call vga_print_u16_5_at

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Progress update
; Input: CX = remaining sectors
ui_update_progress:
    cmp byte [ui_gfx], 0
    je .text

    call ui_gfx_update_progress
    call ui_anim_progress_tick
    ret

.text:
    pushad
    push ds
    push es

    mov ax, [kernel_sectors_total]
    cmp ax, 0
    je .done

    ; done = total - remaining
    mov bx, ax
    sub bx, cx

    ; filled = (done * UI_PROG_WIDTH) / total
    mov ax, bx
    mov cx, UI_PROG_WIDTH
    mul cx                  ; DX:AX = done*width
    mov cx, [kernel_sectors_total]
    div cx                  ; AX = filled
    mov si, ax              ; filled count

    ; percent = (done * 100) / total
    mov ax, bx
    mov cx, 100
    mul cx
    mov cx, [kernel_sectors_total]
    div cx                  ; AX = percent (0..100)
    mov di, ax              ; percent

    ; Delta update to reduce flicker:
    mov ax, [ui_prog_prev_filled]   ; prev filled
    cmp si, ax
    je .percent

    ja .fill_delta

    ; new < prev: clear from new .. prev-1 (should be rare)
    mov cx, ax
    sub cx, si                       ; count = prev - new
    mov ax, si
    add ax, UI_PROG_COL_BAR
    mov dl, al
    mov dh, UI_ROW_PROGRESS
    mov bl, UI_ATTR_DIM
.clear_loop:
    mov al, 0xB0
    call vga_putc_at
    inc dl
    loop .clear_loop
    jmp .set_prev

.fill_delta:
    ; new > prev: fill from prev .. new-1
    mov cx, si
    sub cx, ax                       ; count = new - prev
    add ax, UI_PROG_COL_BAR
    mov dl, al
    mov dh, UI_ROW_PROGRESS
    mov bl, UI_ATTR_OK
.fill_loop:
    mov al, 0xDB
    call vga_putc_at
    inc dl
    loop .fill_loop

.set_prev:
    mov [ui_prog_prev_filled], si

.percent:
    ; percent display
    mov ax, di
    mov dh, UI_ROW_PROGRESS
    mov dl, UI_PROG_COL_BAR + UI_PROG_WIDTH + 2
    mov bl, UI_ATTR_LABEL
    call vga_print_percent_at

    ; Update sector counters line: done/total
    mov ax, bx
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 16
    mov bl, UI_ATTR_LABEL
    call vga_print_u16_5_at

    mov al, '/'
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 21
    mov bl, UI_ATTR_LABEL
    call vga_putc_at

    mov ax, [kernel_sectors_total]
    mov dh, UI_ROW_PROGRESS_INFO
    mov dl, 22
    mov bl, UI_ATTR_LABEL
    call vga_print_u16_5_at

    call ui_anim_progress_tick

.done:
    pop es
    pop ds
    popad
    ret

; Verify the loaded kernel against the expected header checksum.
; Uses a simple sum32(bytes) modulo 2^32. If the header checksum is 0, verification is skipped.
ui_checksum_verify:
    pushad

    mov eax, [kernel_checksum_expected]
    test eax, eax
    jz .skip

    call ui_checksum_show_verifying

    call kernel_checksum_sum32
    mov [kernel_checksum_actual], eax

    cmp eax, [kernel_checksum_expected]
    jne .fail

    call ui_checksum_show_ok
    popad
    ret

.skip:
    call ui_checksum_show_skip
    popad
    ret

.fail:
    call ui_checksum_show_fail

    ; Keep the FAIL state visible briefly on the splash before switching to text.
    cmp byte [ui_gfx], 0
    je .fatal
    mov cx, 0x0007
    mov dx, 0xA120          ; 500ms
    call ui_sleep_us

.fatal:
    call ui_fatal_prepare

    mov si, msg_ar_err_checksum
    mov ax, UI_GFX_RIGHT_X
    mov dx, 64
    mov bl, 0x0C            ; red
    call gfx_write_u16_rtl

    mov si, msg_ar_expected
    mov ax, UI_GFX_RIGHT_X
    mov dx, 96
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov si, msg_ascii_0x
    mov ax, 8
    mov dx, 96
    mov bl, GFX_TEXT_COLOR
    call gfx_write_ascii_ltr

    mov eax, [kernel_checksum_expected]
    mov ax, 24
    mov dx, 96
    mov bl, GFX_TEXT_COLOR
    call gfx_write_hex32_ltr

    mov si, msg_ar_actual
    mov ax, UI_GFX_RIGHT_X
    mov dx, 112
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    mov si, msg_ascii_0x
    mov ax, 8
    mov dx, 112
    mov bl, GFX_TEXT_COLOR
    call gfx_write_ascii_ltr

    mov eax, [kernel_checksum_actual]
    mov ax, 24
    mov dx, 112
    mov bl, GFX_TEXT_COLOR
    call gfx_write_hex32_ltr

    mov si, msg_ar_halt
    mov ax, UI_GFX_RIGHT_X
    mov dx, 144
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    cli
    hlt

; Show checksum status in the active UI mode.
ui_checksum_show_verifying:
    cmp byte [ui_gfx], 0
    je .text

    mov ax, 0
    mov dx, UI_GFX_Y_CHECKSUM
    mov cx, GFX_WIDTH
    mov si, GFX_FONT_H
    mov bl, GFX_BG_COLOR
    call gfx_fill_rect

    mov si, msg_ar_checksum_ver
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_CHECKSUM
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl
    ret

.text:
    call ui_status_csum_loading
    ret

ui_checksum_show_ok:
    cmp byte [ui_gfx], 0
    je .text

    mov ax, 0
    mov dx, UI_GFX_Y_CHECKSUM
    mov cx, GFX_WIDTH
    mov si, GFX_FONT_H
    mov bl, GFX_BG_COLOR
    call gfx_fill_rect

    mov si, msg_ar_checksum_ok
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_CHECKSUM
    mov bl, GFX_BAR_FILL_COLOR
    call gfx_write_u16_rtl
    ret

.text:
    call ui_status_csum_ok
    ret

ui_checksum_show_fail:
    cmp byte [ui_gfx], 0
    je .text

    mov ax, 0
    mov dx, UI_GFX_Y_CHECKSUM
    mov cx, GFX_WIDTH
    mov si, GFX_FONT_H
    mov bl, GFX_BG_COLOR
    call gfx_fill_rect

    mov si, msg_ar_checksum_fail
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_CHECKSUM
    mov bl, 0x0C            ; red
    call gfx_write_u16_rtl
    ret

.text:
    call ui_status_csum_fail
    ret

ui_checksum_show_skip:
    cmp byte [ui_gfx], 0
    je .text

    mov ax, 0
    mov dx, UI_GFX_Y_CHECKSUM
    mov cx, GFX_WIDTH
    mov si, GFX_FONT_H
    mov bl, GFX_BG_COLOR
    call gfx_fill_rect

    mov si, msg_ar_checksum_skip
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_CHECKSUM
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl
    ret

.text:
    call ui_status_csum_skip
    ret

; Compute sum32(bytes) modulo 2^32 over the loaded kernel body (kernel_size bytes at 0x10000).
; Output: EAX = checksum.
kernel_checksum_sum32:
    pushad
    push es

    xor eax, eax
    mov edx, [kernel_size]

    mov bx, KERNEL_LOAD_SEG
    mov es, bx
    xor di, di
    xor ecx, ecx

.loop:
    test edx, edx
    jz .done

    mov cl, [es:di]
    add eax, ecx

    inc di
    jnz .no_wrap
    mov bx, es
    add bx, 0x1000
    mov es, bx
.no_wrap:
    dec edx
    jmp .loop

.done:
    mov [tmp_dword], eax
    pop es
    popad
    mov eax, [tmp_dword]
    ret

; Print EAX as 8 hex digits (no prefix).
print_hex32:
    push ax
    push bx
    push cx
    push dx
    push si

    mov [tmp_dword], eax
    mov si, tmp_dword+3
    mov cx, 4
.hex_loop:
    mov al, [si]
    call print_hex
    dec si
    loop .hex_loop

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Print AX as a 5-char right-aligned decimal number at DH:DL, using attribute BL.
; Input: AX=value, DH=row, DL=leftmost column. Uses spaces for leading zeros.
vga_print_u16_5_at:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov si, ax              ; value
    mov bh, dh              ; row (preserve across vga_putc_at)

    ; DI = rightmost column (left + 4)
    xor di, di
    mov di, dx
    and di, 0x00FF
    add di, 4

    mov bp, 0               ; emitted-nonzero flag
    mov cx, 5

.u16_loop:
    mov ax, si
    xor dx, dx
    div word [dec_base]     ; AX=quotient, DX=remainder
    mov si, ax

    mov al, dl              ; digit (0..9) from remainder

    ; Leading spaces unless we've emitted a nonzero digit, or we're at last digit.
    cmp bp, 0
    jne .emit_digit
    cmp si, 0
    jne .mark_nonzero
    cmp cx, 1
    je .emit_digit
    cmp al, 0
    jne .mark_nonzero
    mov al, ' '
    jmp .emit

.mark_nonzero:
    mov bp, 1
.emit_digit:
    add al, '0'

.emit:
    ; Set DH=row, DL=column from DI (16-bit safe)
    push ax
    mov ax, di
    mov dl, al
    pop ax
    mov dh, bh

    call vga_putc_at
    dec di
    loop .u16_loop

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Print AX as "NNN%" at DH:DL with attribute BL (AX expected 0..100)
vga_print_percent_at:
    push ax
    push bx
    push cx
    push dx

    cmp ax, 100
    jne .lt100

    mov al, '1'
    call vga_putc_at
    inc dl
    mov al, '0'
    call vga_putc_at
    inc dl
    mov al, '0'
    call vga_putc_at
    inc dl
    mov al, '%'
    call vga_putc_at
    jmp .done

.lt100:
    mov cl, al              ; save percent (0..99) before clobbering AL
    mov al, ' '
    call vga_putc_at
    inc dl

    ; Convert AL (0..99) into tens/ones: AH=tens, AL=ones.
    mov al, cl
    aam
    mov cl, al              ; save ones

    mov al, ah              ; tens
    add al, '0'
    cmp al, '0'
    jne .tens_emit
    mov al, ' '
.tens_emit:
    call vga_putc_at
    inc dl

    mov al, cl              ; ones
    add al, '0'
    call vga_putc_at
    inc dl

    mov al, '%'
    call vga_putc_at

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; VGA clear: fill screen with spaces using attribute BL
vga_clear:
    push ax
    push cx
    push di
    push es

    mov ax, VGA_SEG
    mov es, ax
    xor di, di

    mov ah, bl
    mov al, ' '

    mov cx, VGA_COLS * VGA_ROWS
    rep stosw

    pop es
    pop di
    pop cx
    pop ax
    ret

; VGA write string at (DH=row, DL=col) with attribute BL, SI points to string.
vga_write_string_at:
    push ax
    push dx
    push si

.next:
    lodsb
    test al, al
    jz .done
    call vga_putc_at
    inc dl
    jmp .next

.done:
    pop si
    pop dx
    pop ax
    ret

; VGA put char AL at (DH=row, DL=col) with attribute BL.
; Input: AL=char, BL=attr, DH=row, DL=col
vga_putc_at:
    push ax
    push bx
    push dx
    push di
    push es

    ; Save char in BH (BX is preserved by push/pop).
    mov bh, al

    mov ax, VGA_SEG
    mov es, ax

    ; DI = row*160 + col*2
    xor ax, ax
    mov al, dh
    mov di, ax

    mov ax, 160
    mul di                  ; DX:AX = row*160
    mov di, ax

    xor ax, ax
    mov al, dl
    shl ax, 1
    add di, ax

    mov al, bh              ; restore char
    mov ah, bl              ; attribute
    mov [es:di], ax

    pop es
    pop di
    pop dx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------------------------
; Tier 2 Bootloader UX Helpers (Mode 13h, 320x200x256)
; ------------------------------------------------------------------------------

; Set VGA graphics mode 13h (320x200x256).
gfx_set_mode_13:
    push ax
    mov ax, 0x0013
    int 0x10
    pop ax
    ret

; Clear entire graphics framebuffer to BL color.
gfx_clear:
    push ax
    push cx
    push di
    push es

    mov ax, GFX_SEG
    mov es, ax
    xor di, di

    mov al, bl
    mov cx, GFX_WIDTH * GFX_HEIGHT
    rep stosb

    pop es
    pop di
    pop cx
    pop ax
    ret

; Draw a horizontal line: (AX=x, DX=y, CX=len), color BL.
gfx_hline:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov si, ax              ; x

    mov ax, GFX_SEG
    mov es, ax

    mov ax, dx              ; y
    mul word [gfx_pitch]    ; DX:AX = y*320
    add ax, si              ; + x
    mov di, ax

    mov al, bl
    rep stosb

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Plot a single pixel at (AX=x, DX=y) with color BL.
gfx_putpixel:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    mov si, ax              ; x

    mov ax, GFX_SEG
    mov es, ax

    mov ax, dx              ; y
    mul word [gfx_pitch]
    add ax, si
    mov di, ax

    mov al, bl
    mov [es:di], al

    pop es
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

; Draw a vertical line: (AX=x, DX=y, CX=len), color BL.
gfx_vline:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov si, ax              ; x

    mov ax, GFX_SEG
    mov es, ax

    mov ax, dx              ; y
    mul word [gfx_pitch]
    add ax, si
    mov di, ax

    mov al, bl
.loop:
    mov [es:di], al
    add di, GFX_WIDTH
    loop .loop

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Fill a rectangle: (AX=x, DX=y, CX=w, SI=h), color BL.
gfx_fill_rect:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push es

    mov di, ax              ; x

    mov ax, GFX_SEG
    mov es, ax

    mov ax, dx              ; y
    mul word [gfx_pitch]    ; DX:AX = y*pitch
    add ax, di              ; + x
    mov di, ax

    mov al, bl              ; color
    mov bx, cx              ; width
    mov bp, si              ; height

.row:
    mov cx, bx
    rep stosb
    add di, GFX_WIDTH
    sub di, bx
    dec bp
    jnz .row

    pop es
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw an 8x16 glyph from boot_font_8x16 at (AX=x, DX=y).
; Input: BH=glyph index, BL=color.
gfx_draw_glyph_8x16:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov di, ax              ; x

    ; SI = &boot_font_8x16[glyph*16]
    mov si, boot_font_8x16
    xor ax, ax
    mov al, bh
    shl ax, 4               ; *16
    add si, ax

    ; DI = y*pitch + x
    mov ax, GFX_SEG
    mov es, ax

    mov ax, dx              ; y
    mul word [gfx_pitch]
    add ax, di
    mov di, ax

    mov cx, GFX_FONT_H      ; 16 rows
.row:
    mov al, [si]
    mov dl, 8
.bit:
    shl al, 1               ; MSB first
    jnc .skip
    mov [es:di], bl
.skip:
    inc di
    dec dl
    jnz .bit

    add di, GFX_WIDTH - GFX_FONT_W
    inc si
    loop .row

    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Write a null-terminated ASCII string left-to-right at (AX=x, DX=y), color BL.
; Input: DS:SI=string.
gfx_write_ascii_ltr:
    push ax
    push bx
    push dx
    push si
    push di

    mov di, ax              ; cursor x

.loop:
    lodsb
    test al, al
    jz .done

    mov bh, al
    mov ax, di
    call gfx_draw_glyph_8x16
    add di, GFX_FONT_W
    jmp .loop

.done:
    pop di
    pop si
    pop dx
    pop bx
    pop ax
    ret

; Write AL as 2 hex digits (upper-case) left-to-right at (AX=x, DX=y), color BL.
; Output: AX = updated x after the two digits.
gfx_write_hex8_ltr:
    push bx
    push dx
    push di

    mov di, ax              ; cursor x
    mov ah, al              ; save byte

    mov al, ah
    shr al, 4
    call gfx_write_hex_nibble_ltr

    mov al, ah
    and al, 0x0F
    call gfx_write_hex_nibble_ltr

    mov ax, di              ; updated x

    pop di
    pop dx
    pop bx
    ret

; Write EAX as 8 hex digits left-to-right at (AX=x, DX=y), color BL.
; Output: AX = updated x after the eight digits.
gfx_write_hex32_ltr:
    push bx
    push cx
    push dx
    push si
    push di

    mov [tmp_dword], eax
    mov di, ax              ; cursor x

    mov si, tmp_dword+3
    mov cx, 4
.loop:
    mov al, [si]
    mov ax, di
    call gfx_write_hex8_ltr
    mov di, ax
    dec si
    loop .loop

    mov ax, di              ; updated x

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret

; Helper: write one hex nibble in AL at (DI=x, DX=y), color BL.
; Updates DI by +8.
gfx_write_hex_nibble_ltr:
    cmp al, 9
    jbe .digit
    add al, ('A' - 10)
    jmp .emit
.digit:
    add al, '0'
.emit:
    mov bh, al
    mov ax, di
    call gfx_draw_glyph_8x16
    add di, GFX_FONT_W
    ret

; CF=1 if AX is an ASCII digit (0-9) or Arabic-Indic digit (0660-0669).
gfx_u16_is_digit:
    cmp ax, 0x0030
    jb .check_ar
    cmp ax, 0x0039
    jbe .yes
.check_ar:
    cmp ax, 0x0660
    jb .no
    cmp ax, 0x0669
    jbe .yes
.no:
    clc
    ret
.yes:
    stc
    ret

; Find an Arabic shaping entry in ar_form_table for AX=codepoint.
; Output: CF=0 found and DI points to entry; CF=1 not found.
ar_find_entry:
    push cx

    mov di, ar_form_table
    mov cx, ar_form_count
.loop:
    cmp ax, [di]
    je .found
    add di, AR_FORM_ENTRY_SIZE
    loop .loop

    stc
    pop cx
    ret

.found:
    clc
    pop cx
    ret

; Find a Lam-Alef ligature entry for AX=alef_variant_cp.
; Output: CF=0 found and DI points to entry; CF=1 not found.
ar_find_lamalef:
    push cx

    mov di, ar_lamalef_table
    mov cx, ar_lamalef_count
.loop:
    cmp ax, [di]
    je .found
    add di, 4
    loop .loop

    stc
    pop cx
    ret

.found:
    clc
    pop cx
    ret

; Write a 0-terminated UTF-16LE string right-to-left at (AX=x, DX=y), color BL.
; Arabic letters are shaped and rendered using Presentation Forms-B glyphs.
; Digits are rendered in LTR order within the RTL line.
gfx_write_u16_rtl:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov [gfx_cursor_x], ax
    mov bp, dx              ; y
    mov [gfx_text_color], bl
    mov byte [ar_prev_type], 0

.next_cp:
    mov ax, [si]
    test ax, ax
    jz .done

    call gfx_u16_is_digit
    jc .digit_run

    ; Lam-Alef ligature: LAM (0644) + Alef variant.
    cmp ax, 0x0644
    jne .not_lam
    mov dx, [si+2]
    test dx, dx
    jz .not_lam
    mov ax, dx
    call ar_find_lamalef
    jc .not_lam

    ; connect_prev if previous was dual-joining.
    mov al, [ar_prev_type]
    cmp al, 'D'
    jne .lam_iso
    mov bh, [di+3]          ; fin_low
    jmp .lam_emit
.lam_iso:
    mov bh, [di+2]          ; iso_low
.lam_emit:
    mov bl, [gfx_text_color]
    mov ax, [gfx_cursor_x]
    mov dx, bp
    call gfx_draw_glyph_8x16
    sub word [gfx_cursor_x], GFX_FONT_W

    add si, 4               ; consume LAM + Alef
    mov byte [ar_prev_type], 0
    jmp .next_cp

.not_lam:
    ; Arabic shaping entry?
    mov ax, [si]
    call ar_find_entry
    jc .non_arabic

    mov dl, [di+2]          ; curr_type ('D','R','U')
    mov cl, dl              ; preserve across draws (DX is reused for Y)

    ; connect_prev -> DH (0/1)
    xor dh, dh
    mov al, [ar_prev_type]
    cmp al, 'D'
    jne .cp_done
    cmp dl, 'D'
    je .cp_yes
    cmp dl, 'R'
    jne .cp_done
.cp_yes:
    mov dh, 1
.cp_done:

    ; connect_next -> AL (0/1)
    xor al, al
    cmp dl, 'D'             ; only dual-joining connects left
    jne .cn_done
    mov ax, [si+2]
    test ax, ax
    jz .cn_done

    push di                 ; save current entry pointer
    call ar_find_entry
    jc .cn_restore

    mov ah, [di+2]          ; next_type
    cmp ah, 'D'
    je .cn_yes
    cmp ah, 'R'
    jne .cn_restore
.cn_yes:
    mov al, 1
.cn_restore:
    pop di                  ; restore current entry pointer
.cn_done:

    ; Select form byte -> BH.
    mov bh, [di+3]          ; iso_low
    test dh, dh
    jz .no_prev
    test al, al
    jnz .use_med
    mov bh, [di+4]          ; fin_low
    jmp .emit
.use_med:
    mov bh, [di+6]          ; med_low
    jmp .emit
.no_prev:
    test al, al
    jz .emit
    mov bh, [di+5]          ; ini_low

.emit:
    cmp bh, 0
    jne .draw
    mov bh, [di+3]          ; fallback iso_low

.draw:
    mov bl, [gfx_text_color]
    mov ax, [gfx_cursor_x]
    mov dx, bp
    call gfx_draw_glyph_8x16
    sub word [gfx_cursor_x], GFX_FONT_W

    add si, 2
    mov [ar_prev_type], cl
    jmp .next_cp

.non_arabic:
    mov ax, [si]

    ; Bidi mirroring for parentheses in RTL.
    cmp ax, 0x0028
    jne .chk_rparen
    mov bh, 0x29
    jmp .na_emit
.chk_rparen:
    cmp ax, 0x0029
    jne .na_map
    mov bh, 0x28
    jmp .na_emit

.na_map:
    cmp ax, 0x0100
    jb .na_low
    mov bh, 0x3F            ; '?'
    jmp .na_emit
.na_low:
    mov bh, al

.na_emit:
    mov bl, [gfx_text_color]
    mov ax, [gfx_cursor_x]
    mov dx, bp
    call gfx_draw_glyph_8x16
    sub word [gfx_cursor_x], GFX_FONT_W

    add si, 2
    mov byte [ar_prev_type], 0
    jmp .next_cp

.digit_run:
    ; Scan full digit run.
    mov di, si              ; scan ptr
    xor cx, cx              ; len
.scan:
    mov ax, [di]
    test ax, ax
    jz .scanned
    call gfx_u16_is_digit
    jnc .scanned
    add di, 2
    inc cx
    jmp .scan
.scanned:
    ; DI = run_end, CX = len
    push di                 ; save run_end
    sub di, 2               ; last digit

.draw_digits:
    test cx, cx
    jz .digits_done

    mov ax, [di]
    cmp ax, 0x0660
    jb .ascii_digit
    sub ax, 0x0660
    add al, 0x10            ; Arabic-Indic glyphs at 0x10..0x19
    mov bh, al
    jmp .d_emit
.ascii_digit:
    mov bh, al
.d_emit:
    mov bl, [gfx_text_color]
    mov ax, [gfx_cursor_x]
    mov dx, bp
    call gfx_draw_glyph_8x16
    sub word [gfx_cursor_x], GFX_FONT_W

    sub di, 2
    dec cx
    jmp .draw_digits

.digits_done:
    pop si                  ; SI = run_end
    mov byte [ar_prev_type], 0
    jmp .next_cp

.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw a simple pyramid logo (filled triangle).
gfx_draw_pyramid_logo:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov bp, GFX_LOGO_HEIGHT
    xor si, si              ; row index

.row:
    ; len = row*4 + 1
    mov ax, si
    shl ax, 2
    inc ax
    mov bx, ax              ; len

    ; x = center - (len/2)
    mov di, ax
    shr di, 1               ; half
    mov ax, GFX_LOGO_X_CENTER
    sub ax, di              ; x

    ; y = start + row
    mov dx, GFX_LOGO_Y_START
    add dx, si

    mov cx, bx              ; len
    mov bl, GFX_LOGO_COLOR
    call gfx_hline

    inc si
    dec bp
    jnz .row

    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Draw the Mode 13h splash screen.
ui_gfx_draw_boot_screen:
    push ax
    push bx
    push dx
    push si

    call gfx_set_mode_13
    mov byte [ui_gfx], 1

    mov bl, GFX_BG_COLOR
    call gfx_clear

    ; Title/subtitle (Arabic-first).
    mov si, msg_ar_title
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_TITLE
    mov bl, GFX_TEXT_COLOR
    call gfx_write_u16_rtl

    mov si, msg_ar_subtitle
    mov ax, UI_GFX_RIGHT_X
    mov dx, UI_GFX_Y_SUBTITLE
    mov bl, GFX_DIM_COLOR
    call gfx_write_u16_rtl

    call gfx_draw_pyramid_logo

    ; Progress bar shell (fill updates happen during kernel load).
    call ui_gfx_progress_init

    pop si
    pop dx
    pop bx
    pop ax
    ret

; Initialize the graphics-mode progress bar (outline + empty fill).
ui_gfx_progress_init:
    push ax
    push bx
    push cx
    push dx

    mov word [ui_prog_prev_filled], 0

    ; Border box
    mov ax, GFX_BAR_X - 1
    mov dx, GFX_BAR_Y - 1
    mov cx, GFX_BAR_W + 2
    mov bl, GFX_BAR_BORDER_COLOR
    call gfx_hline

    mov ax, GFX_BAR_X - 1
    mov dx, GFX_BAR_Y + GFX_BAR_H
    mov cx, GFX_BAR_W + 2
    mov bl, GFX_BAR_BORDER_COLOR
    call gfx_hline

    mov ax, GFX_BAR_X - 1
    mov dx, GFX_BAR_Y - 1
    mov cx, GFX_BAR_H + 2
    mov bl, GFX_BAR_BORDER_COLOR
    call gfx_vline

    mov ax, GFX_BAR_X + GFX_BAR_W
    mov dx, GFX_BAR_Y - 1
    mov cx, GFX_BAR_H + 2
    mov bl, GFX_BAR_BORDER_COLOR
    call gfx_vline

    ; Empty bar fill
    xor bx, bx
.bg_row:
    mov ax, GFX_BAR_X
    mov dx, GFX_BAR_Y
    add dx, bx
    mov cx, GFX_BAR_W
    mov bl, GFX_BAR_BG_COLOR
    call gfx_hline

    inc bx
    cmp bx, GFX_BAR_H
    jb .bg_row

    pop dx
    pop cx
    pop bx
    pop ax
    ret

; Update graphics progress bar. Input: CX = remaining sectors.
ui_gfx_update_progress:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp

    mov ax, [kernel_sectors_total]
    test ax, ax
    jz .done

    ; done = total - remaining
    mov bx, ax
    sub bx, cx

    ; filled = (done * GFX_BAR_W) / total
    mov ax, bx
    mov cx, GFX_BAR_W
    mul cx                  ; DX:AX = done*width
    mov cx, [kernel_sectors_total]
    div cx                  ; AX = filled (0..GFX_BAR_W)
    mov si, ax              ; filled

    mov ax, [ui_prog_prev_filled]
    cmp si, ax
    je .done

    ja .fill_delta

    ; new < prev: clear from new .. prev-1
    mov bp, ax
    sub bp, si              ; delta = prev - new
    mov di, si              ; start = new
    mov bl, GFX_BAR_BG_COLOR
    jmp .draw_delta

.fill_delta:
    mov bp, si
    sub bp, ax              ; delta = new - prev
    mov di, ax              ; start = prev
    mov bl, GFX_BAR_FILL_COLOR

.draw_delta:
    xor bx, bx              ; row
.row_loop:
    mov ax, GFX_BAR_X
    add ax, di
    mov dx, GFX_BAR_Y
    add dx, bx
    mov cx, bp
    call gfx_hline

    inc bx
    cmp bx, GFX_BAR_H
    jb .row_loop

    mov [ui_prog_prev_filled], si

.done:
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ------------------------------------------------------------------------------
; Data
; ------------------------------------------------------------------------------
boot_drive:      db 0
kernel_size:     dd 0
kernel_checksum_expected: dd 0
kernel_checksum_actual:   dd 0
kernel_sectors:  dw 0
kernel_sectors_total: dw 0

ui_verbose:      db 0
ui_prog_prev_filled: dw 0
ui_spin_idx:    db 0
ui_gfx:         db 0
dec_base:       dw 10
gfx_pitch:      dw GFX_WIDTH
gfx_cursor_x:   dw 0
gfx_text_color: db 0
ar_prev_type:   db 0
tmp_dword:      dd 0

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
msg_ascii_0x:    db '0x', 0

; UI strings (Tier 1)
msg_ui_title:     db 'PyramidOS Bootloader (Stage 2)', 0
msg_ui_rule:      db '--------------------------------------------------------------------------------', 0
msg_hint_f8:      db 'Press F8 for boot options (Splash/Verbose).', 0

msg_lbl_a20:      db 'A20 Line', 0
msg_lbl_e820:     db 'Memory Map (E820)', 0
msg_lbl_hdr:      db 'Kernel Header', 0
msg_lbl_kernel:   db 'Kernel Load', 0
msg_lbl_pm:       db 'Protected Mode', 0
msg_lbl_checksum: db 'Kernel Checksum', 0
msg_lbl_progress: db 'Loading:', 0

msg_stat_pending: db '[ .... ]', 0
msg_stat_loading: db '[ LOAD ]', 0
msg_stat_ok:      db '[ OK   ]', 0
msg_stat_fail:    db '[ FAIL ]', 0
msg_stat_chk:     db '[ CHK  ]', 0
msg_stat_skip:    db '[ SKIP ]', 0

msg_menu_title:   db 'Boot Options', 0
msg_menu_1:       db '1) Splash (Mode 13h, Quiet)', 0
msg_menu_2:       db '2) Verbose (Text debug output)', 0

msg_logo_1:       db '   /\\    PyramidOS', 0
msg_logo_2:       db '  /__\\   Sovereign Boot Sequence', 0
msg_lbl_sectors:  db 'Sectors:', 0
spinner_chars:    db 0x7C, 0x2F, 0x2D, 0x5C  ; | / - \\ (spinner)
msg_gfx_title:    db 'PyramidOS', 0
msg_gfx_subtitle: db 'Sovereign Boot Sequence', 0
msg_gfx_autoboot: db 'Auto boot in:', 0
msg_gfx_enter:    db 'Press ENTER to boot now.', 0
msg_gfx_sec:      db 's', 0
msg_gfx_checksum_ver:  db 'Checksum: VERIFY', 0
msg_gfx_checksum_ok:   db 'Checksum: PASS', 0
msg_gfx_checksum_fail: db 'Checksum: FAIL', 0
msg_gfx_checksum_skip: db 'Checksum: SKIP', 0

msg_checksum_mismatch:    db 'Kernel checksum mismatch.', 13, 10, 0
msg_checksum_expected:    db 'Expected: 0x', 0
msg_checksum_actual_str:  db 13, 10, 'Actual:   0x', 0
msg_checksum_halt:        db 13, 10, 'Halting.', 0

; ---------------------------------------------------------------------------
; Arabic UI + Shaping Tables + Bitmap Font
; ---------------------------------------------------------------------------
%include "arabic_strings.inc"
%include "arabic_forms.inc"
%include "boot_font_8x16.inc"

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

times (STAGE2_SECTOR_COUNT*512)-($-$$) db 0
