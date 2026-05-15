[org 0x0100]
jmp start
player: dw 3920
playerDirection: db 3
timerCounter: db 0
movePlayerflag: db 0
GameOver: db 0

OldTimerOffset: dw 0
OldTimerSegment: dw 0
OldKbdOffset: dw 0
OldKbdSegment: dw 0

GameLostMessage: db 'Game LOST$'
GameWinMessage: db 'Game WON$'


clearScreen:
    push es
    push ax
    push cx
    push di
    mov ax, 0xb800
    mov es, ax
    xor di, di
    mov ax, 0x0720
    mov cx, 2000
    cld 
    rep stosw
    pop di
    pop cx
    pop ax
    pop es
    ret

place_obstacles:
    mov ax, 0xb800
    mov es, ax
    mov ax, 0x2220
    call cols_right
    call othercol1
    call othercol2
    call othercol3
    call row1
    call row2
    call row3
    ret
   
    
cols_right:
    pusha 
    push es
    push ds
    mov cx, 25
    mov di, 158

    col_loop:
    mov [es: di], ax
    add di, 160
    loop col_loop

    pop ds
    pop es
    popa
    ret
othercol1:
    pusha 
    push es
    push ds
    mov cx, 6
    mov di, 492
    othercol1_loop:
    mov [es: di], ax
    add di, 160
    loop othercol1_loop
    pop ds
    pop es
    popa
    ret
othercol2:
    pusha 
    push es
    push ds
    mov cx, 6
    mov di, 396
    othercol2_loop:
    mov [es: di], ax
    add di, 160
    loop othercol2_loop
    pop ds
    pop es
    popa
    ret
othercol3:
    pusha 
    push es
    push ds
    mov cx, 6
    mov di, 1480
    othercol3_loop:
    mov [es: di], ax
    add di, 160
    loop   othercol3_loop
    pop ds
    pop es
    popa
    ret

row1:
    pusha 
    push es
    push ds
    mov cx, 10
    mov di, 1480
    row1_loop:
    mov [es: di], ax
    add di, 2
    loop   row1_loop
    pop ds
    pop es
    popa
    ret

row2:
    pusha 
    push es
    push ds
    mov cx, 10
    mov di, 420
    row2_loop:
    mov [es: di], ax
    add di, 2
    loop   row2_loop
    pop ds
    pop es
    popa
    ret

row3:
    pusha 
    push es
    push ds
    mov cx, 10
    mov di, 2354
    row3_loop:
    mov [es: di], ax
    add di, 2
    loop   row3_loop
    pop ds
    pop es
    popa
    ret

place_asterisk:
    pusha
    push es
    push ds
    mov di, 3920
    mov ax, 0x172A
    mov [es: di], ax
    pop ds
    pop es
    popa
    ret

place_goal:
    pusha
    push es
    push ds
    mov di, 0
    mov ax, 0x4420
    mov [es: di], ax
    pop ds
    pop es
    popa
    ret

TimerISR:
    pusha
    push ds
    push es

    inc byte [timerCounter]
    cmp byte [timerCounter], 2
    jl timerIsrChain

    mov byte [timerCounter],0
    mov byte [movePlayerflag],1

timerIsrChain:
    pop es
    pop ds
    popa
    mov al, 0x20
    out 0x20, al

    jmp far [OldTimerOffset]

   

installTimer:
    push es
    
    mov ax, 0x0000
    mov es, ax

    mov ax, [es: 8*4]     
    mov [OldTimerOffset], ax
    mov ax, [es: 8*4+2]   
    mov [OldTimerSegment], ax

    cli
    mov word [es: 8*4], TimerISR
    mov word [es: 8*4+2], cs  
    sti

    pop es
    ret

KbdISR:
    pusha
    push ds
    push es

    in al, 0x60
    test al, 0x80;for key release(release code)
    jnz KbdISR_Chain

    cmp al, 0x48 
    je KbdISR_Up
    cmp al, 0x50 
    je KbdISR_Down
    cmp al, 0x4B 
    je KbdISR_Left
    cmp al, 0x4D 
    je KbdISR_Right
    
KbdISR_Chain:
    pop es
    pop ds
    popa
    mov al, 0x20
    out 0x20, al 
    jmp far [OldKbdOffset]

KbdISR_Up:
    mov byte [playerDirection], 0 
    jmp KbdISR_Chain
KbdISR_Down:
    mov byte [playerDirection], 1 
    jmp KbdISR_Chain
KbdISR_Left:
    mov byte [playerDirection], 2 
    jmp KbdISR_Chain
KbdISR_Right:
    mov byte [playerDirection], 3 
    jmp KbdISR_Chain
    
MovePlayer:
    pusha
    push es

    mov ax, 0xb800
    mov es, ax

    mov di, [player]
    mov si, di

    mov al, [playerDirection]
    cmp al, 0
    jne checkDown

    cmp di, 160;at the second row
    jb GameLost;if below that, then error
    sub si, 160
    jmp CollisionCheck

    checkDown:
    cmp al, 1
    jne checkLeft
    cmp di, 3840;at the bottom
    jae GameLost
    add si, 160
    jmp CollisionCheck

    checkLeft:
    cmp al, 2
    jne checkRight

    mov bx, di
    and bx, 0x00FF
    cmp bx, 0
    je GameLost
    sub si, 2
    jmp CollisionCheck

    checkRight:
        cmp al, 3
        jne moveEnd
        mov bx, di
        and bx, 0x00ff
        cmp bx, 158
        je GameLost
        add si, 2

CollisionCheck:
    mov ax, [es: si]
    
    cmp ax, 0x2220; collision
    je GameLost

    cmp ax, 0x4420
    je Gamewin

    mov ax, 0x0720
    mov [es:di], ax

    mov ax, 0x172A
    mov [es:si], ax

    mov [player], si
    jmp moveEnd

GameLost:
    mov byte [GameOver], 1
    call PrintGameLost
    jmp moveEnd

Gamewin:
    mov byte [GameOver], 2
    call printGameWon

moveEnd:
    mov byte [movePlayerflag], 0
    pop es
    popa
    ret

installKbdISR:
    push es
    
    mov ax, 0x0000
    mov es, ax
    mov ax, [es: 9*4]     
    mov [OldKbdOffset], ax
    mov ax, [es: 9*4+2]   
    mov [OldKbdSegment], ax

    cli                       
    mov word [es: 9*4], KbdISR
    mov word [es: 9*4+2], cs  
    sti                       
    
    pop es
    ret

uninstallISRs:
    push es
    push ax
    
    mov ax, 0x0000
    mov es, ax
    
    cli 
    
    
    mov ax, [OldTimerOffset]
    mov [es: 8*4], ax
    mov ax, [OldTimerSegment]
    mov [es: 8*4+2], ax

    
    mov ax, [OldKbdOffset]
    mov [es: 9*4], ax
    mov ax, [OldKbdSegment]
    mov [es: 9*4+2], ax
    
    sti 
    
    pop ax
    pop es
    ret
PrintGameLost:
    mov dx, GameLostMessage
    mov ah, 09h
    int 21h
    ret
printGameWon:
    mov dx, GameWinMessage
    mov ah, 09h
    int 21h
    ret


start:
    call clearScreen
    call place_obstacles
    call place_goal
    call place_asterisk

    call installTimer
    call installKbdISR 

    GameLoop:
    cmp byte [GameOver], 0
    jne GameEnd

    cmp byte [movePlayerflag], 1
    jne GameLoop

    call MovePlayer
    jmp GameLoop
    
    GameEnd:
        call uninstallISRs
mov ax, 0x4c00
int 0x21
