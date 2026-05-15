[org 0x0100]

jmp start

playerPos: dw 3920          ; Player position (center of last row: 160*24 + 80)
direction: dw 2             ; Direction: up:-160, down=160, left=-2, right=2
timerCount: dw 0            ; Timer interrupt counter
timer: dd 0                 ; Old timer interrupt vector
keyboard: dd 0              ; Old keyboard interrupt vector
gameOver: db 0              ; Game over flag

win: db 'Game Win!$'
lost: db 'Game Lost!$'

start:
    push es
    xor ax, ax
    mov es, ax ; old interrupt vectors saved
    
    
    mov ax, [es:0x08*4]
    mov [timer], ax
    mov ax, [es:0x08*4+2]
    mov [timer+2], ax ; timer interrupt saved
    
    mov ax, [es:0x09*4]
    mov [keyboard], ax
    mov ax, [es:0x09*4+2]
    mov [keyboard+2], ax ; keyboard interrupt saved
    
    pop es
    
    ; setting new interrupt vectors
    cli
    
    push ds
    push cs
    pop ds
    mov dx, timerISR
    mov ax, 0x2508
    int 0x21
    pop ds ; timer interrupt set
    
    push ds
    push cs
    pop ds
    mov dx, keyboardISR
    mov ax, 0x2509
    int 0x21
    pop ds ; keyboard interrupt set
    
    sti
    
    call clearScreen
    
    call placeObstacles
    
    ; goal: top left corner, red background
    mov ax, 0xb800
    mov es, ax
    mov di, 0
    mov word [es:di], 0x4420
    
    ; Place player (center of last row, blue asterisk)
    mov di, [playerPos]
    mov word [es:di], 0x192A    ; Blue asterisk
    
gameLoop:
    ; check if game over
    cmp byte [gameOver], 0
    jne endGame
    
    ; infinite loop, interrupts handle breaking the loop
    jmp gameLoop

endGame:
    mov cx, 0xFFFF

waitLoop:
    loop waitLoop
    
    cli ; restore interrupts
    
    push ds
    xor ax, ax
    mov ds, ax
    
    ; Restore timer
    mov ax, [cs:timer]
    mov [0x08*4], ax
    mov ax, [cs:timer+2]
    mov [0x08*4+2], ax
    
    ; Restore keyboard
    mov ax, [cs:keyboard]
    mov [0x09*4], ax
    mov ax, [cs:keyboard+2]
    mov [0x09*4+2], ax
    
    pop ds
    sti
    
    ; Display message
    mov ax, 0xb800
    mov es, ax
    mov di, 160*12 + 70    ; Middle of screen
    
    cmp byte [gameOver], 1
    je showWin
    
    ; Show lost message
    mov si, lost
    jmp displayMsg
    
showWin:
    mov si, win
    
displayMsg:
    mov ah, 0x0F

nextChar:
    lodsb
    cmp al, '$'
    je exitProgram
    stosb
    mov al, ah
    stosb
    jmp nextChar

exitProgram:
    mov ah, 0 ; Wait for key
    int 0x16
    
    call clearScreen ; Clear screen before exit
   
    mov ax, 0x4c00
    int 0x21

clearScreen:
    push es
    push di
    push cx
    push ax
    
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov cx, 2000
    mov ax, 0x0720
    cld
    rep stosw
    
    pop ax
    pop cx
    pop di
    pop es
    ret

placeObstacles:
    push es
    push di
    push cx
    push ax
    
    mov ax, 0xb800
    mov es, ax
    
    ; Right boundary
    mov di, 158              ; Column 79
    mov cx, 25               ; 25 rows

rightBoundary:
    mov word [es:di], 0x2220 ; Green space
    add di, 160
    loop rightBoundary
    
    ; Some obstacles in the middle
    ; Row 5, columns 20-30
    mov di, 160*5 + 40
    mov cx, 10

obs1:
    mov word [es:di], 0x2220
    add di, 2
    loop obs1
    
    ; Row 10, columns 10-20
    mov di, 160*10 + 20
    mov cx, 10

obs2:
    mov word [es:di], 0x2220
    add di, 2
    loop obs2
    
    ; Row 15, columns 50-60
    mov di, 160*15 + 100
    mov cx, 10

obs3:
    mov word [es:di], 0x2220
    add di, 2
    loop obs3
    
    ; Row 20, columns 30-40
    mov di, 160*20 + 60
    mov cx, 10

obs4:
    mov word [es:di], 0x2220
    add di, 2
    loop obs4
    
    pop ax
    pop cx
    pop di
    pop es
    ret

timerISR:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push ds
    push es
    
    push cs
    pop ds
    
    ; increment counter
    inc word [timerCount]
    
    ; Check if 2 timer ticks passed
    cmp word [timerCount], 2
    jl timerEnd
    
    ; Reset counter
    mov word [timerCount], 0
    
    ; Check if game over
    cmp byte [gameOver], 0
    jne timerEnd
    
    call movePlayer ; subroutine for moving player according to key pressed
    
timerEnd:
    pop es
    pop ds
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    
    jmp far [cs:timer] ; Chain to old timer interrupt

keyboardISR:
    push ax
    push ds
    
    push cs
    pop ds
    
    in al, 0x60 ; reading scan code
    
    ; Check arrow keys
    cmp al, 0x48         ; Up arrow
    je setUp
    cmp al, 0x50         ; Down arrow
    je setDown
    cmp al, 0x4B         ; Left arrow
    je setLeft
    cmp al, 0x4D         ; Right arrow
    je setRight
    jmp keyboardEnd
    
setUp:
    mov word [direction], -160
    jmp keyboardEnd

setDown:
    mov word [direction], 160
    jmp keyboardEnd

setLeft:
    mov word [direction], -2
    jmp keyboardEnd

setRight:
    mov word [direction], 2
    
keyboardEnd:
    ; send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    pop ds
    pop ax
    iret

movePlayer:
    push ax
    push bx
    push cx
    push dx
    push di
    push es
    
    mov ax, 0xb800
    mov es, ax
    
    ; Clear old position
    mov di, [playerPos]
    mov word [es:di], 0x0720
    
    ; Calculate new position
    mov ax, [playerPos]
    add ax, [direction]
    mov [playerPos], ax
    
    ; Check new position
    mov di, ax
    mov bx, [es:di]
    
    ; Check if goal (red background)
    cmp bh, 0x44
    je winGame
    
    ; Check if obstacle (green)
    cmp bh, 0x22
    je loseGame
    
    ; Place player at new position
    mov word [es:di], 0x192A
    jmp moveEnd
    
winGame:
    mov byte [gameOver], 1
    jmp moveEnd
    
loseGame:
    mov byte [gameOver], 2
    
moveEnd:
    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret