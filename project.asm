[org 0x0100]

jmp start

;-------------------------------------------------
;; String Data
    greetings: db ' WELCOME TO MINI CANDY CRUSH! '
    timerStart: db ' Your game will start in: '
    high_greet: db ' HOPE YOU MADE YOUR HIGH SCORE '
    graded_score: db ' Your recorded score is: '
    welcomeMSG: db 'MINI CANDY CRUSH'
    exitHint1: db 'Press'
    exitHint2: db 'ESC'
    exitHint3: db 'To Exit'
    madeBY: db 'MADE BY'
    rollNo: db '21L-5695'
    scoreMSG: db 'SCORE'
    lengraded_score:dw 25
    lenhigh_greet: dw 31
    lenStart:dw 26
    lenGreet: dw 30
    lenMadeBy: dw 7
    lenRollno: dw 8
    lenWelcom: dw 16
    lenEscape1: dw 5
    lenEscape2: dw 3
    lenEscape3: dw 7
    lenScore: dw 5
;-------------------------------------------------
;; Game Data
    countDown: db 3
    pos_rollNo: db 4, 4
    pos_madeBy: db 3, 4
    pos_welcom: db 3, 32
    pos_score: db 3, 72
    KbISR: dd 0
; ------------------------------------------------
;; Grid Data
    grid: db 5, 18, 16, 61
    clr_grid: db 10010000b
    clr_selection: db 00000111b
    first_box: dw 0, 0 ; the co-ordinates of the first box in the grid : relative to grid position

    candy_clrs: db 10000000b, 11000000b, 01110000b, 11010000b, 11110000b, 10000000b
    len_colors: dw 6
; ------------------------------------------------
;; User Data
    score: dw 0

keyboardISR:
    push ax
    
    in al, 0x60 ; reading from keyboard port
    cmp al, 0x01 ; esc - exit
    jne sweetExit

    mov ax, [KbISR] ; offset
    mov [es: 9 * 4], ax
    mov ax, [KbISR + 2] ; segment
    mov [es: 9 * 4 + 2], ax

    mov al, 0x20
    out 0x20, al

    call disableMouseCursor
    call __printOverScreen ; the game over screen we need to show before exiting

    mov ax, 0x4c00
    int 0x21

    sweetExit:
    mov al, 0x20
    out 0x20, al

    pop ax
    iret

start:
    ; Intensive Colors ON
        mov ax, 1003h
        mov bx, 0
        mov bl, 0
        int 10h

    ;; Greet Screen
    call __printGreetScreen
    
    mov ax, 0
    int 33h
    cmp ax, 0 ; if the mouse is not present ;; MOUSE NOT DETECTED
    je cleanExit

    ; Hooking Keyboard for potential exit
    mov ax, 0
    mov es, ax

    mov ax, [es: 9 * 4] ; offset
    mov [KbISR], ax
    mov ax, [es: 9 * 4 + 2] ; segment
    mov [KbISR + 2], ax

    ; Hiding Cursor
        mov ah, 01h
        mov cl, 0
        mov ch, 00101000b
        int 10h

    push 1
    call changeScreen ; game engine in page 1
    call clearScreen

    ;; Grid Printing
    call __printGrid

    ;; Top Row
    call __printTopHeaders

    cli
    mov word[es: 9 * 4], keyboardISR
    mov word[es: 9 * 4 + 2], cs
    sti

gameLoop:
    ; Selecting box 1
    call mouse_interupt
    ; this will return:
    ; AH = Attribute of the candy
    ; DX = row of the box
    ; CX = column of the box

    mov al, ah
    mov ah, 0
    mov si, ax ; storing the attribute for potential swap
    push dx
    push cx

    ; We need to wait for the user to release the button to proceed to next click
    call waitforButtonRelease
    
    push dx
    push cx
    push 1
    call selectDeselectCandy

    push dx
    push cx

    push dx
    push cx

    ; Selecting box 2
    call mouse_interupt

    push dx
    push cx
    call checkValidMove

    ; BX will have the value if the move is valid
    cmp bx, 0 ; it is not 1
    je noSwap

    ; Swaping the candies
    mov al, ah
    mov ah, 0
    push ax
    call __printBlock
    call waitforButtonRelease
    call disableMouseCursor

    push dx
    push cx
    push si
    call __printBlock

    push 0
    call selectDeselectCandy
    call checkFiveCombination
    call checkPopVertical
    call checkPopHorizontal
    call EnableMouseCursor
    jmp keepGoing

    noSwap:
        sub sp, 4
        call waitforButtonRelease
        push 0
        call selectDeselectCandy
    
    keepGoing:
    jmp gameLoop

    cleanExit:
        mov ax, 0x4c00
        int 0x21

checkValidMove:
    push bp
    mov bp, sp
    push si
    push di

    ;; This subroutine will tell us if a move is valid given the two boxes

    ;; OUTPUT
    ; will return BX = 1 if Valid else 0

    ;; PARAMTERS:
    ; [bp + 10] = row1
    ; [bp + 8] = col1
    ; [bp + 6] = row2
    ; [bp + 4] = col2

    mov si, [bp + 10] ; row of box 1
    mov di, [bp + 8] ; col of box 1
    mov bx, 0

    ; row down check
    add si, 4
    cmp si, [bp + 6]
    jne __case2
    cmp di, [bp + 4]
    je validEnd

    __case2:
    ; row up check
    sub si, 4
    sub si, 4
    cmp si, [bp + 6] ; row of box 2
    jne __case3
    cmp di, [bp + 4]
    je validEnd

    __case3:
    ; col right check
    add si, 4
    add di, 8
    cmp di, [bp + 4] ; col of box 2
    jne __case4
    cmp si, [bp + 6]
    je validEnd

    __case4:
    ; col left check
    sub di, 8
    sub di, 8
    cmp di, [bp + 4]
    jne officialEnd
    cmp si, [bp + 6]
    jne officialEnd

    validEnd:
        mov bx, 1
    
    officialEnd:
        pop di
        pop si
        pop bp
        ret 8

selectDeselectCandy:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;; PARAMTERS
    ; [bp + 8] = Row
    ; [bp + 6] = Col
    ; [bp + 4] = select / deselect - 0 for deselect - 1 for select

    mov si, [bp + 8]
    mov di, [bp + 6]

    mov ah, 09h
    mov al, '-'
    mov bh, 1
    cmp word[bp + 4], 1
    jne ____sselectclr
    mov bl, [clr_selection]
    jmp ____forw1

    ____sselectclr:
        mov al, ' '
        mov bl, 0x07

    ____forw1:
    dec si
    push si
    push di
    call setCursorPosition

    mov cx, 7
    int 10h

    add si, 4
    push si
    push di
    call setCursorPosition

    int 10h

    cmp word[bp + 4], 1
    jne ____ssselectclr
        mov al, '|'
    
    ____ssselectclr:
    mov cx, 1
    sub si, 4
    add di, 7
    mov dh, 0
    mov dl, 3

    _____rightBorder:
        inc si
        push si
        push di
        call setCursorPosition
        int 10h
        inc dh
        cmp dh, dl
        jne _____rightBorder
        
    mov dh, 0
    sub di, 8

    _____leftBorder:
        push si
        push di
        call setCursorPosition
        int 10h
        dec si
        inc dh
        cmp dh, dl
        jne _____leftBorder    

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6

checkFiveCombination:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov dx, 0 ; / 0 / 4 / 8 / 12

    Rowcheck:
        mov si, [first_box]
        mov di, [first_box + 2]
        add si, dx
        push si
        push di
        call readColor
        mov bh, ah ; bh has the color we need to check
        mov cx, 4

        ; Checking rows
        row___:
            add di, 8
            push si
            push di
            call readColor
            cmp ah, bh
            jne _______forw1_____
            loop row___

            ; here we have the respective row with all same color candies
            push dx
            push 2 ; removing 5 combo
            call gapFillRow
            mov bl, bh
            mov bh, 0

            push 0xF
            push 0xFFFF
            call __delay

            push bx
            call deleteAllColorInstances

            push 0xF
            push 0xFFFF
            call __delay

            mov di, [first_box + 2]
            push si
            push di
            call deleteCandyInstance

            _______forw1_____:
            add dx, 4
            cmp dx, 16
            jne Rowcheck

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 

checkPopVertical:
    push bp
    mov bp, sp
    sub sp, 2 ; 1 LV
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; LV
    ; [bp - 2] ; Flag for Pop Check

    mov word[bp - 2], 0
    mov dx, 0 ; / 0 / 8 / 16 / 24 / 32

    fullColcheck:
        mov si, [first_box]
        mov di, [first_box + 2]
        add di, dx
        push si
        push di
        call readColor
        mov bh, ah ; bh has the color we need to check
        mov cx, 3

        ; Checking columns
        col1:
            add si, 4
            push si
            push di
            call readColor
            cmp ah, bh
            jne ______forw1
            loop col1

            ; here we have the respective column with all same color candies
            push dx
            call gapFillCol
            mov word[bp - 2], 1

            ______forw1:
            add dx, 8
            cmp dx, 40
            jne fullColcheck

    cmp word[bp - 2], 1
    jne ______weGood
    call checkPopVertical ; a recursive call just to be sure we have the matching boxes popped
    call checkPopHorizontal

    ______weGood:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret

checkPopHorizontal:
    push bp
    mov bp, sp
    sub sp, 2 ; 1 LV
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; LV
    ; [bp - 2] = Flag for Pop Check

    mov word[bp - 2], 0
    mov dx, 0 ; / 0 / 4 / 8 / 12

    LeftRowcheck:
        mov si, [first_box]
        mov di, [first_box + 2]
        add si, dx
        push si
        push di
        call readColor
        mov bh, ah ; bh has the color we need to check
        mov cx, 3

        ; Checking rows
        row1:
            add di, 8
            push si
            push di
            call readColor
            cmp ah, bh
            jne _______forw1
            loop row1

            ; here we have the respective column with all same color candies
            push dx
            push 0
            call gapFillRow
            mov word[bp - 2], 1

            _______forw1:
            add dx, 4
            cmp dx, 16
            jne LeftRowcheck

    mov dx, 0
    RightRowcheck:
        mov si, [first_box]
        mov di, [first_box + 2]
        add di, 8
        add si, dx
        push si
        push di
        call readColor
        mov bh, ah ; bh has the color we need to check
        mov cx, 3

        ; Checking rows
        row2:
            add di, 8
            push si
            push di
            call readColor
            cmp ah, bh
            jne _______forw_1
            loop row2

            ; here we have the respective column with all same color candies
            push dx
            push 1
            call gapFillRow
            mov word[bp - 2], 1

            _______forw_1:
            add dx, 4
            cmp dx, 16
            jne RightRowcheck

    cmp word[bp - 2], 1
    jne ______weReallyGood
    call checkPopHorizontal ; a recursive call just to be sure we have the matching boxes popped
    call checkPopVertical

    ______weReallyGood:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret

gapFillCol:
    push bp
    mov bp, sp
    push cx
    push si
    push di

    ;; PARAMETERS
    ; [bp + 4] = number to add to determine column

    mov si, [first_box] ; row
    mov di, [first_box + 2] ; col

    add di, [bp + 4]
    mov cx, 4

    ___go1:
        push si
        push di
        push 0
        call __printBlock
        inc word[score]
        call printScore

        push 0
        push 0xFFFF
        call __delay

        add si, 4
        loop ___go1
    
    ; we need to fill out the columns once again with random colours
    mov cx, 4
    sub si, 4

    ___go2:
        push si
        push di
        call __printRandomBlock

        push 0
        push 0xFFFF
        call __delay

        sub si, 4
        loop ___go2

    pop di
    pop si
    pop cx
    pop bp
    ret 2

gapFillRow:
    push bp
    mov bp, sp
    sub sp, 2 ; 1 LV
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ;; PARAMETERS:
    ; [bp + 6] = number to add to get the corresponding row
    ; [bp + 4] = 0 / 1 for left right row checks - 2 for a complete 5 combo check

    ; LV
    ; [bp - 2] = flag for bomb placement

    mov word[bp - 2], 0 ; init zero
    mov si, [first_box]
    mov di, [first_box + 2]
    add si, [bp + 6]
    mov dx, 4

    cmp word[bp + 4], 1
    jne ______forw9

    add di, 8

    ______forw9:
    mov bx, [first_box] ; row

    cmp word[bp + 4], 2 ; if we have a 5 combo check
    jne ______forw9____
        mov dx, 5

    ______forw9____:
    mov cx, dx

    ___go3:
        push si
        push di
        push 0
        call __printBlock
        inc word[score]
        call printScore

        push 0
        push 0xFFFF
        call __delay

        add di, 8
        loop ___go3

    ;; Row 1
    cmp si, bx
    jne ______forw2

    mov cx, dx
    sub di, 8

    ___go4:
        push si
        push di
        call __printRandomBlock

        push 0
        push 0xFFFF
        call __delay

        sub di, 8
        loop ___go4
        cmp word[bp + 4], 2 ; if we need to place a bomb as in 5 combo
        jne ______forw10____
            cmp word[bp - 2], 0
            jne ______forw10____
            add di, 8
            push si
            push di
            call __printBomb
            mov word[bp - 2], 1
        ______forw10____:
        jmp aGoodbye

    ______forw2:
    ;; Row 2
    add bx, 4
    cmp si, bx
    jne ______forw3

    sub di, 8
    mov cx, dx

    ___go5:
        sub si, 4
        push si
        push di
        call readColor
        cmp ah, 0b
        jne _____alrightGoOn3
            sub si, 4
            push si
            push di
            call readColor
            add si, 4
            
        _____alrightGoOn3:
        add si, 4
        mov al, ah
        mov ah, 0
        push si ; row
        push di ; col
        push ax ; attribute
        call __printBlock

        sub di, 8
        loop ___go5
        cmp word[bp + 4], 2 ; if we need to place a bomb as in 5 combo
        jne ______forw11____
            cmp word[bp - 2], 0
            jne ______forw11____
            add di, 8
            push si
            push di
            call __printBomb
            mov word[bp - 2], 1
            sub di, 8
        ______forw11____:
        sub si, 4
        add di, 32
        cmp word[bp + 4], 2 ; if we have a 5 combo check
        jne _____skip____
            add di, 8
        _____skip____:
        mov cx, dx
        jmp ___go4

    ______forw3:
    ;; Row 3
    add bx, 4
    cmp si, bx
    jne ______forw4

    sub di, 8
    mov cx, dx

    ___go6:
        sub si, 4
        push si
        push di
        call readColor
        cmp ah, 0b
        jne _____alrightGoOn2
            sub si, 4
            push si
            push di
            call readColor
            add si, 4
            
        _____alrightGoOn2:
        add si, 4
        mov al, ah
        mov ah, 0
        push si ; row
        push di ; col
        push ax ; attribute
        call __printBlock

        sub di, 8
        loop ___go6
        cmp word[bp + 4], 2 ; if we need to place a bomb as in 5 combo
        jne ______forw12____
            cmp word[bp - 2], 0
            jne ______forw12____
            add di, 8
            push si
            push di
            call __printBomb
            mov word[bp - 2], 1
            sub di, 8
        ______forw12____:
        sub si, 4
        add di, 32
        cmp word[bp + 4], 2 ; if we have a 5 combo check
        jne _____skip____2
            add di, 8
        _____skip____2:
        mov cx, dx
        jmp ___go5
    
    ______forw4:
    ;; Row 4
    add bx, 4
    cmp si, bx
    jne aGoodbye

    sub di, 8
    mov cx, dx

    ___go7:
        sub si, 4
        push si
        push di
        call readColor

        cmp ah, 0
        jne _____alrightGoOn
            sub si, 4
            push si
            push di
            call readColor
            add si, 4

        _____alrightGoOn:
        add si, 4
        mov al, ah
        mov ah, 0
        push si ; row
        push di ; col
        push ax ; attribute
        call __printBlock

        sub di, 8
        loop ___go7
        cmp word[bp + 4], 2 ; if we need to place a bomb as in 5 combo
        jne ______forw13____
            cmp word[bp - 2], 0
            jne ______forw13____
            add di, 8
            push si
            push di
            call __printBomb
            mov word[bp - 2], 1
            sub di, 8
        ______forw13____:
        sub si, 4
        add di, 32
        cmp word[bp + 4], 2 ; if we have a 5 combo check
        jne _____skip____3
            add di, 8
        _____skip____3:
        mov cx, dx
        jmp ___go6

    aGoodbye:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    mov sp, bp
    pop bp
    ret 4

deleteCandyInstance:
    push bp
    mov bp, sp
    push ax
    push bx
    push si
    push di

    ; this sub-routine will take the co-ordinates and remove that candy from the grid

    ;; PARAMETERS:
    ; [bp + 6] = row
    ; [bp + 4] = col

    mov si, [bp + 6]
    mov di, [bp + 4]

    mov bx, [first_box] ; the reference row

    ; this will remove that block from the screen
    ___printBlack:
        push si
        push di
        push 0
        call __printBlock
        inc word[score]
        call printScore

        push 0
        push 0xFFFF
        call __delay

    ;; Row 1
    cmp si, bx
    jne ______forw2_

    ___go4_:
        push si
        push di
        call __printRandomBlock

        push 0
        push 0xFFFF
        call __delay

        jmp aGreatbye

    ______forw2_:
    ;; Row 2
    add bx, 4
    cmp si, bx
    jne ______forw3_

    ___go5_:
        sub si, 4
        push si
        push di
        call readColor
        cmp ah, 0b
        jne _____alrightGoOn8
        add si, 8
        push si
        push di
        call readColor
        sub si, 8
        
    _____alrightGoOn8:

        add si, 4
        mov al, ah
        mov ah, 0
        push si ; row
        push di ; col
        push ax ; attribute
        call __printBlock

        sub si, 4
        jmp ___go4_

    ______forw3_:
    ;; Row 3
    add bx, 4
    cmp si, bx
    jne ______forw4_

    ___go6_:
        sub si, 4
        push si
        push di
        call readColor
        cmp ah, 0b
        jne _____alrightGoOn7
        sub si, 4
        push si
        push di
        call readColor
        add si, 4
        
    _____alrightGoOn7:

        add si, 4
        mov al, ah
        mov ah, 0
        push si ; row
        push di ; col
        push ax ; attribute
        call __printBlock

        sub si, 4
        jmp ___go5_
    
    ______forw4_:
    ;; Row 4
    add bx, 4
    cmp si, bx
    jne aGreatbye

    sub si, 4
    push si
    push di
    call readColor
    cmp ah, 0b
    jne _____alrightGoOn6
        sub si, 4
        push si
        push di
        call readColor
        add si, 4
        
    _____alrightGoOn6:
    add si, 4
    mov al, ah
    mov ah, 0
    push si ; row
    push di ; col
    push ax ; attribute
    call __printBlock

    sub si, 4
    jmp ___go6_

    aGreatbye:
    pop di
    pop si
    pop bx
    pop ax
    pop bp
    ret 4

deleteAllColorInstances:
    push bp
    mov bp, sp
    push cx
    push dx
    push si
    push di

    ;; PARAMETERS:
    ; [bp + 4] = color attribute

    mov si, [first_box] ; row
    mov cx, 4
    
    __outerLoop:
    mov dh, 0
    mov dl, 5
    mov di, [first_box + 2] ; col

    __innerLoop:
        push si
        push di
        call readColor ; will return attribute in AH
        mov al, ah
        cmp al, byte[bp + 4]
        jne _____skip
            push si
            push di
            call deleteCandyInstance
        _____skip:
        add di, 8
        inc dh
        cmp dh, dl
        jne __innerLoop
    add si, 4
    loop __outerLoop

    pop di
    pop si
    pop dx
    pop cx
    pop bp
    ret 2

EnableMouseCursor:
    push ax

    mov ax, 1
    int 33h

    pop ax
    ret

disableMouseCursor:
    push ax

    mov ax, 2
    int 33h

    pop ax
    ret

waitforButtonRelease:
    push ax
    push bx
    push cx
    push dx

    ___l1:
        mov ax, 3
        int 33h

        cmp bx, 0
        jne ___l1

    pop dx
    pop cx
    pop bx
    pop ax
    ret

mouse_interupt:

    ; BX = 1, if Left Button is Pressed
    ; BX = 2, if right Button is Pressed
    ; BX = 3, if both buttons are Pressed

    ; Getting Mouse Position
    ; DX = Row in pixels
    ; CX = Column in pixels

    ; Setting Mouse Resolution - Limiting to the box region

    ; Width
    mov ax, 7
    mov cx, 490 ; Right width
    mov dx, 155 ; Left Width
    int 33h

    ; Height
    mov ax, 8
    mov cx, 50
    mov dx, 180
    int 33h

    ; Showing the mouse cursor
    mov ax, 1
    int 33h

    ; Getting the mouse position and buttons
    mov ax, 3
    int 33h

    ;; We need to convert co-ordinates to 80x25 Screen Size therefore divide by 8
    shr cx, 3   ; col
    shr dx, 3   ; row

    ; Left Click
    cmp bx, 1
    jne mouse_interupt

    ; now we have the click co-ordiantes 
    ; all we need to do is to read those co-ordinates and check if the attribute is black
    ; if the attribute is black then we have a border and we won't be taking that move

    call disableMouseCursor

    push dx
    push cx
    call setCursorPosition

    mov bh, 1
    mov ah, 08h
    int 10h

    cmp ah, 0x07 ; if we have the black space (border) we do not take that move
    je mouse_interupt

    call getBox ; getting the orginal co-ordinates of the box selected
    ; cx and dx will now contain the selected box

    push dx
    push cx
    call setCursorPosition

    ; this will get us the attribute of the selected box in AH for later use
    mov bh, 1
    mov ah, 08h
    int 10h

    call EnableMouseCursor
    ret

getBox:
    push si
    push di

    ; IMPLICIT PARAMTERS ; will change them with orginal box constraints
    ; CX = Col
    ; DX = Row

    ; Sub-routine to get the top most co-ordinates of the box user has selected

    mov di, [first_box + 2] ; 21
    mov si, [first_box] ; 7

    colCheck:
        add di, 8
        cmp cx, di
        jge colCheck

        sub di, 8
        mov cx, di
        jmp rowCheck

    rowCheck:
        add si, 4
        cmp dx, si
        jge rowCheck

        sub si, 4
        mov dx, si

    ; cx has the selected column
    ; dx has the selected row

    ; Print Test
    ; mov [score], dx
    ; call printScore

    ; push 0xF
    ; push 0xFFFF
    ; call __delay

    ; mov [score], cx
    ; call printScore

    pop di
    pop si
    ret

__printGreetScreen:

    ; changing to screen 0 (Greet Screen)
    push 0
    call changeScreen

    push 0
    push 0
    push 0
    call setPageCursorPosition

    ; Printing Background
    mov ah, 09h
    mov al, ' '
    mov bh, 0
    mov bl, 01100000b
    mov cx, 2000
    int 10h

    ; Printing Greet String
    mov ah, 13h
    mov al, 00b
    mov bh, 0
    mov bl, 00001110b
    mov cx, [lenGreet]
    mov dh, 8 ; row
    mov dl, 26 ; col
    push ds
    pop es
    mov bp, greetings
    int 10h

    ; Printing the next string
    mov bl, 00001010b
    mov cx, [lenStart]
    mov dh, 10
    mov dl, 28
    mov bp, timerStart
    int 10h

    push 12 ; row
    push 40 ; col
    push 0 ; page number
    call setPageCursorPosition

    mov dh, 0
    mov dl, 4

    ; Countdown
    counntdown:
        mov ah, 0Ah
        mov al, [countDown]
        add al, 0x30
        mov cx, 1
        int 10h
        dec byte[countDown]
        push 0xF
        push 0xFFFF
        call __delay
        inc dh
        cmp dh, dl
        jne counntdown

    ret

__printOverScreen:
       ; changing to screen 2 (Game Over Screen)
    push 2
    call changeScreen

    push 0
    push 0
    push 2
    call setPageCursorPosition

    ; Printing Background
    mov ah, 09h
    mov al, ' '
    mov bh, 2
    mov bl, 01100000b
    mov cx, 2000
    int 10h

    ; Printing High Greet String
    mov ah, 13h
    mov al, 00b
    mov bh, 2
    mov bl, 00001110b
    mov cx, [lenhigh_greet]
    mov dh, 8 ; row
    mov dl, 25 ; col
    push ds
    pop es
    mov bp, high_greet
    int 10h

    ; Printing the next string
    mov bl, 00001010b
    mov cx, [lengraded_score]
    mov dh, 10
    mov dl, 28
    mov bp, graded_score
    int 10h

    push 12 ; row
    push 40 ; col
    push 2 ; page number
    call setPageCursorPosition

    mov si, 12
    mov di, 40

    mov ax, [score]
    cmp ax, 0
    je ____iprint0

    ____idiv:
        mov dx, 0
        mov bx, 10
        div bx
        add dl, 0x30 ; converting into ASCII Form

        push ax
        mov ah, 09h
        mov al, dl
        mov bh, 2
        mov bl, 1010b
        mov cx, 1
        int 10h
        pop ax

        ; // Setting Position With respect to each letter
        dec di
        push si
        push di
        push 2
        call setPageCursorPosition

        cmp ax, 0
        jne ____idiv
        jmp __________lastForwInMyProgram
    
    ____iprint0:
        mov bh, 2
        mov bl, 1010b
        mov cx, 1
        mov ah, 09h
        mov al, '0'
        int 10h

    __________lastForwInMyProgram:
    push 0xF
    push 0xFFFF
    call __delay
    ret

__printTopHeaders:
    push ax
    push bx
    push dx
    push cx
    push es
    push bp

    ; Made by
        mov ah, 13h
        mov al, 00b
        mov bh, 1
        mov bl, 00001110b
        mov cx, [lenMadeBy]
        mov dh, [pos_madeBy]
        mov dl, [pos_madeBy + 1]
        push ds
        pop es
        mov bp, madeBY
        int 10h

    ; Roll #
        mov bl, 00001010b
        mov cx, [lenRollno]
        mov dh, [pos_rollNo]
        mov dl, [pos_rollNo + 1]
        mov bp, rollNo
        int 10h

    ; WELCOME String
        mov bl, 00001110b
        mov cx, [lenWelcom]
        mov dh, [pos_welcom]
        mov dl, [pos_welcom + 1]
        mov bp, welcomeMSG
        int 10h

    ; Score String
        mov cx, [lenScore]
        mov dh, [pos_score]
        mov dl, [pos_score + 1]
        mov bp, scoreMSG
        int 10h 
        call printScore

    ; ESC String
        ; Press
        mov cx, [lenEscape1]
        mov dh, 10
        mov dl, 7
        mov bp, exitHint1
        int 10h

        ; ESC
        mov cx, [lenEscape2]
        mov dh, 11
        mov dl, 8
        mov bp, exitHint2
        int 10h

        ; To Exit
        mov cx, [lenEscape3]
        mov dh, 12
        mov dl, 6
        mov bp, exitHint3
        int 10h

    pop bp
    pop es
    pop cx
    pop dx
    pop bx
    pop ax
    ret

__printGrid:
    push dx
    push bx
    push ax
    push cx
    push si
    push di

    ;; KEY
    ; si - has the row
    ; di - has the column
    ; dh - has the iteration count
    ; dl - has the total count

    mov dh, 0
    mov dl, [grid]
    mov si, dx
    mov dh, 0
    mov dl, [grid + 1]
    mov di, dx

    push si
    push di
    call setCursorPosition

    ; Length of grid
        mov dx, 0
        mov dl, [grid + 3]
        sub dl, [grid + 1]
        mov cx, 1
        mov dh, 0

        mov ah, 09h
        mov al, '-'
        mov bl, [clr_grid]
        mov bh, 1

    ; Top Portion
    inc dl
    ___top:
        int 10h
        inc di
        push si
        push di
        call setCursorPosition
        inc dh
        push 0
        push 0x4FFF
        call __delay
        cmp dh, dl
        jne ___top

        mov dh, 0
        dec dl
        sub dl, 25

    ; Right Portion
    ___right:
        int 10h
        inc si
        push si
        push di
        call setCursorPosition
        inc dh
        push 0
        push 0x4FFF
        call __delay
        cmp dh, dl
        jne ___right

        mov dh, 0
        add dl, 25

    ; Down Portion
    inc dl
    ___down:
        int 10h
        dec di
        push si
        push di
        call setCursorPosition
        inc dh
        push 0
        push 0x4FFF
        call __delay
        cmp dh, dl
        jne ___down

        mov dh, 0
        dec dl
        sub dl, 25

    ; Left Portion
    ___left:
        int 10h
        dec si
        push si
        push di
        call setCursorPosition
        inc dh
        push 0
        push 0x4FFF
        call __delay
        cmp dh, dl
        jne ___left   

    mov dh, 0

    add si, 2
    add di, 3

    mov [first_box], si ; row
    mov [first_box + 2], di ; col

    push si
    push di
    push word[candy_clrs]
    call __printBlock

    push 0x3
    push 0xFFFF
    call __delay

    mov cx, 4

    __fillGridRight1:
        add di, 8
        push si
        push di
        cmp cx, 4
        je oddColor
        cmp cx, 2
        je oddColor
        push word[candy_clrs]
        jmp wego1
        oddColor:
        push word[candy_clrs + 1]
        wego1:
        call __printBlock
        push 0x3
        push 0xFFFF
        call __delay
        loop __fillGridRight1

        add si, 4
        sub di, 32 ; we have a distance of 8 columns from next box so we multiply 8 by 4 to go back
        push si
        push di
        push word[candy_clrs + 2]
        call __printBlock

        mov cx, 4

    __fillGridRight2:
        add di, 8
        push si
        push di
        cmp cx, 4
        je odd1Color
        cmp cx, 2
        je odd1Color
        push word[candy_clrs + 2]
        jmp wego2
        odd1Color:
        push word[candy_clrs + 3]
        wego2:
        call __printBlock
        loop __fillGridRight2

        push 0x6
        push 0xFFFF
        call __delay

        add si, 4
        sub di, 32 ; 8 * 4 
        push si
        push di
        push word[candy_clrs + 4]
        call __printBlock

        mov cx, 4

    __fillGridRight3:
        add di, 8
        push si
        push di
        cmp cx, 4
        je odd2Color
        cmp cx, 2
        je odd2Color
        push word[candy_clrs + 4]
        jmp wego3
        odd2Color:
        push word[candy_clrs + 5]
        wego3:
        call __printBlock
        loop __fillGridRight3

        push 0x6
        push 0xFFFF
        call __delay

        add si, 4
        sub di, 32 ; 8 * 4 
        push si
        push di
        push word[candy_clrs + 1]
        call __printBlock

        mov cx, 4

    __fillGridRight4:
        add di, 8
        push si
        push di
        cmp cx, 4
        je odd3Color
        cmp cx, 2
        je odd3Color
        push word[candy_clrs + 1]
        jmp wego4
        odd3Color:
        push word[candy_clrs]
        wego4:
        call __printBlock
        loop __fillGridRight4
        
    pop di
    pop si
    pop cx
    pop ax
    pop bx
    pop dx
    ret

__printRandomBlock:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; PARAMETERS
    ; [bp + 6] = row
    ; [bp + 4] = col

    mov si, [bp + 6] ; row
    mov di, [bp + 4] ; col

    push si
    push di
    call setCursorPosition

    ; Width of block = 7
    ; Height of block = 3

    ;; Fetching random colour from available attributes
    sub sp, 2
    call generateRandomColor
    pop bx ; attribute

    mov ah, 09h
    mov al, ' '
    mov bh, 1
    mov dh, 0
    mov cx, 7 ; Width
    mov dl, 3 ; Height

    __printBBox:
        int 10h
        inc si
        push si
        push di
        call setCursorPosition
        inc dh
        cmp dh, dl
        jne __printBBox 

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

__printBlock:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; PARAMETERS
    ; [bp + 8] = row
    ; [bp + 6] = col
    ; [bp + 4] = attribute

    mov si, [bp + 8] ; row
    mov di, [bp + 6] ; col

    push si
    push di
    call setCursorPosition

    ; Width of block = 7
    ; Height of block = 3

    mov bx, [bp + 4] ; attribute

    mov ah, 09h
    mov al, ' '
    mov bh, 1
    mov dh, 0
    mov cx, 7 ; Width
    mov dl, 3 ; Height

    __printBox:
        int 10h
        inc si
        push si
        push di
        call setCursorPosition
        inc dh
        cmp dh, dl
        jne __printBox 

    ; Shape inside box
    ; mov si, [bp + 8] ; resetting
    ; add si, 1
    ; add di, 3

    ; push si
    ; push di
    ; call setCursorPosition

    ; mov ah, 0Ah
    ; mov al, '$'
    ; mov bh, 1
    ; mov cx, 1
    ; int 10h

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 6

__printBomb:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; PARAMETERS
    ; [bp + 6] = row
    ; [bp + 4] = col

    mov si, [bp + 6] ; row
    mov di, [bp + 4] ; col

    push si
    push di
    call setCursorPosition

    ; Width of block = 7
    ; Height of block = 3

    mov bl, 0 ; attribute

    mov ah, 09h
    mov al, ' '
    mov bh, 1
    mov dh, 0
    mov cx, 7 ; Width
    mov dl, 3 ; Height

    __printTHEBox:
        int 10h
        inc si
        push si
        push di
        call setCursorPosition
        inc dh
        cmp dh, dl
        jne __printTHEBox

    ; Shape inside box
    mov bl, 00001110b
    mov ah, 09h
    mov al, '$'
    mov bh, 1

    mov si, [bp + 6] ; resetting
    add di, 3
    mov cx, 1
    push si
    push di
    call setCursorPosition
    int 10h

    ; mov bl, 00001100b

    inc si
    sub di, 1
    mov cx, 3
    push si
    push di
    call setCursorPosition
    int 10h

    inc si
    mov di, [bp + 4]
    mov cx, 7
    push si
    push di
    call setCursorPosition
    int 10h

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 4

printScore:
    ;; This Subroutine when called will print out the score in reverse order from memory
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Position to Print
    mov dh, 0
    mov dl, [pos_score]
    inc dl
    mov si, dx
    push si
    mov dl, [pos_score + 1]
    add dx, 4
    mov di, dx
    push di
    call setCursorPosition

    mov ax, [score]
    cmp ax, 0
    je ____print0

    ____div:
        mov dx, 0
        mov bx, 10
        div bx
        add dl, 0x30 ; converting into ASCII Form

        push ax
        mov ah, 09h
        mov al, dl
        mov bh, 1
        mov bl, 1010b
        mov cx, 1
        int 10h
        pop ax

        ; // Setting Position With respect to each letter
        dec di
        push si
        push di
        call setCursorPosition

        cmp ax, 0
        jne ____div
        jmp end
    
    ____print0:
        mov bh, 1
        mov bl, 1010b
        mov cx, 1
        mov ah, 09h
        mov al, '0'
        int 10h

    end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

setCursorPosition:
    push bp
    mov bp, sp
    push dx
    push bx
    push ax

    ;; PARAMETERS
    ; [bp + 4] = Col
    ; [bp + 6] = Row

    ; Setting Cursor Position
    mov dh, [bp + 6]
    mov dl, [bp + 4]
    mov bh, 1 ; Page is default 1
    mov ah, 02h
    int 10h

    pop ax
    pop bx
    pop dx
    pop bp
    ret 4

setPageCursorPosition:
    push bp
    mov bp, sp
    push dx
    push bx
    push ax

    ;; PARAMETERS
    ; [bp + 8] = Row
    ; [bp + 6] = Col
    ; [bp + 4] = Page Number

    ; Setting Cursor Position
    mov dh, [bp + 8]
    mov dl, [bp + 6]
    mov bh, [bp + 4]
    mov ah, 02h
    int 10h

    pop ax
    pop bx
    pop dx
    pop bp
    ret 6

__delay:
    push bp
    mov bp, sp
    push cx
    push dx
    push ax

    ;;INPUTS
    ; [bp + 4] = lower word interval
    ; [bp + 6] = higher word interval

    mov ah, 0x86
    mov cx, [bp + 6]
    mov dx, [bp + 4]
    int 0x15

    pop ax
    pop dx
    pop cx
    pop bp
    ret 4

changeScreen:
    ;; Sub-routine to switch to a new screen 
    push bp
    mov bp, sp
    push ax

    ;; PARAMTERS
    ; [bp + 4] = Screen Number

    mov al, byte[bp + 4]
    mov ah, 0x05
    int 0x10

    pop ax
    pop bp
    ret 2

generateRandomColor:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx

    ;; OUTPUT PARAMETERS
    ; [bp + 4] = Output Variable with the random color attribute

    rdtsc ; this will get a random number in ax dx
    xor dx, dx
    mov cx, [len_colors]; number of colours we have
    div cx
    mov bx, dx
    mov dx, [candy_clrs + bx] ; fetching the random attribute from array
    mov [bp + 4], dx

    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret

readColor:
    push bp
    mov bp, sp
    push bx
    push si
    push di

    ;; Implicitly returns character and attribute in AX
    ; AH = Attribute
    ; AL = Character

    ;; PARAMETERS:
    ; [bp + 6] = row
    ; [bp + 4] = col

    mov si, [bp + 6]
    mov di, [bp + 4]

    push si
    push di
    call setCursorPosition

    mov al, 0
    mov ah, 08h
    mov bh, 1
    int 10h

    ; AH - has the attribute
    ; AL - has the character

    pop di
    pop si
    pop bx
    pop bp
    ret 4

clearScreen:
    push ax
    push bx
    push cx

    push 0
    push 0
    call setCursorPosition

    mov ah, 09h
    mov al, ' '
    mov bh, 1
    mov bl, 07
    mov cx, 2000
    int 10h

    pop cx
    pop bx
    pop ax
    ret
