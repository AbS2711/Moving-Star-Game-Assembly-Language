; Typing Bubbles Game - Complete Implementation
; Phase I & II Combined
[org 0x0100]

jmp start

; ============== DATA SECTION ==============
; Game Configuration
TIMER_TICKS equ 18          ; Speed of bubble movement (lower = faster)
GAME_TIME equ 2184          ; 2 minutes = 120 seconds * 18.2 ticks/sec
BUBBLE_SPACING equ 3        ; 3x3 space for each bubble

; Game State Variables
score: dw 0                  ; Current score
time_remaining: dw GAME_TIME ; Time left in ticks
bubble_count: db 10          ; Number of active bubbles
game_over_flag: db 0         ; 1 = game over
timer_counter: db 0          ; Counter for bubble movement

; Bubble Structure (each bubble: row, col, char, active)
bubbles: times 40 db 0       ; 10 bubbles * 4 bytes each
                             ; Format: [row][col][char][active]

; Letters for bubbles
letters: db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
letter_index: db 0

; Old interrupt handlers
oldkb: dd 0
oldtimer: dd 0

; Messages
msg_score: db 'Score: $'
msg_time: db 'Time: $'
msg_gameover: db 'GAME OVER! Final Score: $'
msg_press: db 'Press ESC to exit$'

; ============== UTILITY SUBROUTINES ==============

; Clear screen
clrscr:
    push es
    push ax
    push cx
    push di
    
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ax, 0x0720          ; Space with normal attribute
    mov cx, 2000
    cld
    rep stosw
    
    pop di
    pop cx
    pop ax
    pop es
    ret

; Print string at current cursor
; Parameters: DS:DX = string address
printstr_dos:
    push ax
    mov ah, 9
    int 0x21
    pop ax
    ret

; Print number at position
; Parameters: row, col, number
printnum:
    push bp
    mov bp, sp
    push es
    push ax
    push bx
    push cx
    push dx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    ; Calculate screen position
    mov ax, [bp+8]          ; row
    mov bl, 80
    mul bl
    add ax, [bp+6]          ; col
    shl ax, 1
    mov di, ax
    add di, 8               ; Start from rightmost position
    
    mov ax, [bp+4]          ; number
    mov bx, 10
    mov cx, 0
    
digit_loop:
    xor dx, dx
    div bx
    add dl, '0'
    mov dh, 0x07
    push dx
    inc cx
    cmp ax, 0
    jne digit_loop
    
print_digits:
    pop dx
    mov [es:di], dx
    sub di, 2
    loop print_digits
    
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop es
    pop bp
    ret 6

; Random number generator (simple LCG)
random:
    push dx
    mov ah, 0x00
    int 0x1a                ; Get system time
    mov ax, dx
    and ax, 0xFF
    pop dx
    ret

; ============== BUBBLE MANAGEMENT ==============

; Initialize bubbles
init_bubbles:
    push ax
    push bx
    push cx
    push si
    
    mov cx, 10              ; 10 bubbles
    mov si, bubbles
    xor bl, bl              ; letter index
    
init_loop:
    call random
    and al, 0x0F            ; Row 0-15
    mov [si], al            ; row
    
    call random
    and al, 0x4F            ; Col 0-79 (roughly)
    and al, 0x4E
    mov [si+1], al          ; col
    
    ; Assign letter
    mov al, [letters + bx]
    mov [si+2], al          ; char
    inc bl
    cmp bl, 26
    jl skip_reset
    xor bl, bl
skip_reset:
    
    mov byte [si+3], 1      ; active
    
    add si, 4
    loop init_loop
    
    pop si
    pop cx
    pop bx
    pop ax
    ret

; Draw all bubbles
draw_bubbles:
    push es
    push ax
    push bx
    push cx
    push si
    push di
    
    mov ax, 0xb800
    mov es, ax
    mov si, bubbles
    mov cx, 10
    
draw_loop:
    cmp byte [si+3], 0      ; Check if active
    je skip_draw
    
    ; Calculate position
    mov al, [si]            ; row
    mov bl, 80
    mul bl
    xor bh, bh
    mov bl, [si+1]          ; col
    add ax, bx
    shl ax, 1
    mov di, ax
    
    ; Draw 3x3 bubble
    mov al, [si+2]          ; character
    mov ah, 0x1F            ; Cyan on blue
    
    ; Center character
    mov [es:di+80*2+2], ax
    
    ; Border
    mov ax, 0x1FDB          ; Block character
    mov [es:di], ax
    mov [es:di+2], ax
    mov [es:di+4], ax
    mov [es:di+160], ax
    mov [es:di+164], ax
    mov [es:di+320], ax
    mov [es:di+322], ax
    mov [es:di+324], ax
    
skip_draw:
    add si, 4
    loop draw_loop
    
    pop di
    pop si
    pop cx
    pop bx
    pop ax
    pop es
    ret

; Move bubbles down
move_bubbles:
    push ax
    push si
    push cx
    
    mov si, bubbles
    mov cx, 10
    
move_loop:
    cmp byte [si+3], 0      ; active?
    je skip_move
    
    inc byte [si]           ; Increment row
    cmp byte [si], 22       ; Bottom of screen?
    jl skip_move
    
    ; Deactivate bubble
    mov byte [si+3], 0
    
skip_move:
    add si, 4
    loop move_loop
    
    pop cx
    pop si
    pop ax
    ret

; Check if letter pressed matches a bubble
check_letter:
    push ax
    push si
    push cx
    
    mov si, bubbles
    mov cx, 10
    
check_loop:
    cmp byte [si+3], 0      ; active?
    je skip_check
    
    mov ah, [si+2]          ; bubble char
    cmp al, ah              ; match?
    jne skip_check
    
    ; Match found!
    mov byte [si+3], 0      ; Deactivate
    add word [score], 10    ; Add 10 points
    jmp check_done
    
skip_check:
    add si, 4
    loop check_loop
    
check_done:
    pop cx
    pop si
    pop ax
    ret

; ============== DISPLAY UI ==============

display_ui:
    push es
    push ax
    push bx
    push di
    
    mov ax, 0xb800
    mov es, ax
    
    ; Display Score
    mov di, 0
    mov si, msg_score
    mov ah, 0x0F
disp_score_str:
    lodsb
    cmp al, '$'
    je disp_score_num
    stosw
    jmp disp_score_str
    
disp_score_num:
    push 0
    push 7
    push word [score]
    call printnum
    
    ; Display Time
    mov di, 140             ; Column 70
    mov si, msg_time
    mov ah, 0x0F
disp_time_str:
    lodsb
    cmp al, '$'
    je disp_time_num
    stosw
    jmp disp_time_str
    
disp_time_num:
    ; Convert ticks to seconds
    mov ax, [time_remaining]
    mov bl, 18
    div bl                  ; AX / 18 = seconds
    xor ah, ah
    
    push 0
    push 76
    push ax
    call printnum
    
    pop di
    pop bx
    pop ax
    pop es
    ret

; ============== INTERRUPT HANDLERS ==============

; Keyboard interrupt
kbisr:
    push ax
    push ds
    
    push cs
    pop ds
    
    in al, 0x60             ; Read scancode
    
    ; Convert scancode to letter (simplified)
    cmp al, 0x1E            ; A
    jl not_letter
    cmp al, 0x2C            ; Z
    jg not_letter
    
    ; Convert to ASCII
    sub al, 0x1E
    add al, 'A'
    
    call check_letter
    
not_letter:
    mov al, 0x20
    out 0x20, al            ; EOI
    
    pop ds
    pop ax
    iret

; Timer interrupt
timer:
    push ax
    push ds
    
    push cs
    pop ds
    
    ; Decrement time
    dec word [time_remaining]
    cmp word [time_remaining], 0
    jg time_ok
    mov byte [game_over_flag], 1
    
time_ok:
    ; Move bubbles periodically
    inc byte [timer_counter]
    cmp byte [timer_counter], TIMER_TICKS
    jl timer_done
    
    mov byte [timer_counter], 0
    call move_bubbles
    
timer_done:
    mov al, 0x20
    out 0x20, al            ; EOI
    
    pop ds
    pop ax
    iret

; ============== MAIN PROGRAM ==============

start:
    ; Save old interrupts
    xor ax, ax
    mov es, ax
    
    mov ax, [es:9*4]
    mov [oldkb], ax
    mov ax, [es:9*4+2]
    mov [oldkb+2], ax
    
    mov ax, [es:8*4]
    mov [oldtimer], ax
    mov ax, [es:8*4+2]
    mov [oldtimer+2], ax
    
    ; Install new handlers
    cli
    mov word [es:9*4], kbisr
    mov [es:9*4+2], cs
    mov word [es:8*4], timer
    mov [es:8*4+2], cs
    sti
    
    ; Initialize game
    call clrscr
    call init_bubbles
    
game_loop:
    call clrscr
    call display_ui
    call draw_bubbles
    
    ; Small delay
    mov cx, 0x0FFF
delay_loop:
    loop delay_loop
    
    ; Check game over
    cmp byte [game_over_flag], 1
    je end_game
    
    ; Check ESC key
    mov ah, 1
    int 0x16                ; Check for key
    jz game_loop            ; No key pressed
    
    mov ah, 0
    int 0x16                ; Read key
    cmp al, 27              ; ESC?
    jne game_loop
    
end_game:
    call clrscr
    
    ; Display final score
    mov dx, msg_gameover
    call printstr_dos
    
    mov ax, [score]
    push 0
    push 20
    push ax
    call printnum
    
    ; Restore interrupts
    xor ax, ax
    mov es, ax
    cli
    mov ax, [oldkb]
    mov [es:9*4], ax
    mov ax, [oldkb+2]
    mov [es:9*4+2], ax
    mov ax, [oldtimer]
    mov [es:8*4], ax
    mov ax, [oldtimer+2]
    mov [es:8*4+2], ax
    sti
    
    ; Terminate
    mov ax, 0x4c00
    int 0x21