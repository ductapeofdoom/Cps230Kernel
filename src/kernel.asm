; CpS 230 Team Project: Nathan Collins and Stephen Sidwell
;---------------------------------------------------
; description goes here
;---------------------------------------------------
bits 16

extern functionThatKeepsStuffFromBreaking_
extern moveBlock0_
extern moveBlock1_
extern moveBlock2_
extern pal_counter_

;For boostrapped programs, all addresses start at 0
;org 0x0

; Where to find the INT 8 handler vector within the IVT [interrupt vector table]
IVT8_OFFSET_SLOT    equ 4 * 8           ; Each IVT entry is 4 bytes; this is the 8th
IVT8_SEGMENT_SLOT   equ IVT8_OFFSET_SLOT + 2    ; Segment after Offset


global start_

section .text
start_:

    ;Make code and data segments the same to simplify addressing
    mov     ax, cs
    mov     ds, ax
    
    ; Set ES=0x0000 (segment of IVT)
    mov     ax, 0x0000
    mov     es, ax
    
    ; Set VGA graphics mode (320x200x8-bit)
    mov ah, 0
    mov al, 0x13
    int 0x10

    ;do stuff
    jmp     bootstrap

;Task to move a block across the screen
task1: 
    ;External C Function
    ;See test.c
    call    moveBlock1_
    
    mov     cx, 50000
    
.loop:
    dec     cx
    jnz     .loop
    

    jmp     task1
    
;Task to move another block across the screen 
task2:
    ;External C Function
    ;See test.c
    call    moveBlock2_
    
    mov     cx, 50000
    
.loop:
    dec     cx
    jnz     .loop
    
    jmp     task2

;Task to keep a palette offset counting
;Used to shift the color of the mandlebrot design only
task3:
    ;External C Function
    ;See test.c
    call pal_counter_
    
    mov     cx, 50000
    
.loop:
    dec     cx
    jnz     .loop
    
    jmp     task3

;IVT 8 Handler Function
;Used for preemptive multitasking
;Also used to play the background music
yield:
    ;Flags, CS, and IP should all have been pushed by the interrupt
    ;Push GPRs 
    pusha
    ;Push DS and ES
    push    ds
    push    es
    
    ;Assembly function to do music things
    call    playMusic
    
    ;Get current stack index and adjust for word size
    mov    ax, [stack_idx]
    mov    cx, 2
    imul   cx
    mov    bx, ax
    ;Save current stack pointer
    mov    [stacks + bx], sp 

    ;Check to see if the stack index needs to wrap to the first task
    cmp    word[stack_idx], 3
    je     .wrap
    ;If not just increment the index
    inc word[stack_idx]
    jmp .end
;if so reset index back to 0
.wrap:
    mov word[stack_idx], 0
.end:
    ;Get new stack index and adjust for word size
    mov ax, [stack_idx]
    imul cx
    mov bx, ax
    ;Move new stack pointer into sp
    mov sp, [stacks + bx]
    pop     es
    pop     ds
    popa
    ;Chain to next interrupt handler
    jmp far [cs:ivt8_offset]    ; Use CS as the segment here, since who knows what DS is now

;Kickstart function to start the first task3
;Clears the intial stack and in the process sets the interrupt flag
start_first_task:
    pop     es
    pop     ds
    popa
    iret

bootstrap:
    ;Pay no attention to the order of this code

    ;Set up stacks for all 4 tasks
    ;Same steps are taken for all 4


    ;Moving block 1
    ;Move the task's stack pointer into sp
    mov     sp, stack2 + 255 ; top of stack2
    ;Set up initial stack by pushing flags, cs, code address of the task, ds, and cs
    pushf
    push    cs
    push    task2            ; location to return to
    pusha
    push    ds
    push    es
    ;Save the task's stack pointer into the stack pointer array
    mov     [stacks + 2*1], sp
    
    ;Moving block 2
    ;See the above setup for more comments
    mov     sp, stack1 + 255 ; top of stack1
    pushf
    push    cs
    push    task1            ; location to return to
    pusha
    push    ds
    push    es
    mov     [stacks + 2*0], sp

    ;Task to change color pallete
    ;See the first setup for more comments
    mov     sp, stack4 + 255 ; top of stack4
    pushf
    push    cs
    push    task3            ; location to return to
    pusha
    push    ds
    push    es
    mov     [stacks + 2*3], sp


    ;Mandlebrot setup
    ;Same as all the above with one exception
    ;The stack pointer is not stored or changed after the setup is complete
    mov     sp, stack3 + 255 ; top of stack1
    pushf
    push    cs
    push    mandlebrot_task            ; location to return to
    pusha
    push    ds
    push    es




    ;Install IVT 8 handler for task switching
    cli
    mov     ax, [es:IVT8_SEGMENT_SLOT]
    mov     [ivt8_segment], ax
    mov     ax, [es:IVT8_OFFSET_SLOT]
    mov     [ivt8_offset], ax
    mov     [es:IVT8_SEGMENT_SLOT], cs
    mov     word [es:IVT8_OFFSET_SLOT], yield

    ;Since the stack pointer is still on the mandlebrot_task's stack that will be the first task exectuted
    ;Kickstarts the task outside of the interrupt handler
    jmp     start_first_task

; ------------------------------------------------------------------------------------------------
; now all the really gross code for the music

; random numbers copied from the example code.
SPEAKER_PORT    equ 0x61
PIT_CTL         equ 0x43
PIT_PROG        equ 0xb6      ; 0b10110110: 10 (chan 2) 11 (read LSB/MSB) 011 (mode 3) 0 (binary)
PIT_CHAN2       equ 0x42
PIT_FREQ        equ 0x1234DD

playMusic:
    ; musicPos contains two bytes. 
    ; The first, which will become al, tells us the note we're on. e.g. the 43rd note
    ; The second, which will become ah, tells us the position within the note. e.g. 31 clock cycles left
    ; A clock cycle is 1/18.2 s
    mov     ax, [musicPos]
    dec     ah ; the position within the note
    
    jz      .nextNote ; if we're at the last position within a note
    
    ; if not, store back to memory, and return
    mov     [musicPos], ax
    
    ; we want to put a space at the end of a note just before we switch to the next note
    ; If we're on the very last cycle of a note, blank out the sound
    cmp     ah, 1
    je      .space
    
    ret

.space:
    ; this magic incantation tells the speaker to be quiet.
    mov     al, [portval]
    out     SPEAKER_PORT, al
    
    ret
    
.nextNote:
    inc     al ; go to the next note
    
    cmp     al, NOTE_NUM ; see if we've reached the end of the music
    jne     .after
    mov     al, 0 ; if so, go back to the beginning
    
.after:
    ; figure out where the next note is in memory
    mov     bl, al
    mov     bh, 0
    shl     bx, 2
    
    ; pull in the number of cycles that we specified for the next note
    mov     ah, [musicData + bx]
    ; multiply by 4 to slow down the tempo
    ; If you remove this, it's really fun to listen to . . .
    shl     ah, 2
    
    ; I think we're all done with messing around with ax, so we can go ahead and store it back in it's place
    mov     [musicPos], ax
    
    ; get the current frequency to play
    mov     bx, [musicData + bx + 2]
    
    ; now we need to play that music
    ; copied/edited from example code
    
    ; Capture initial speaker state
    in      al, SPEAKER_PORT
    and     al, 0xfc
    mov     [portval], al

    ; Program PIT channel 2 to count at (0x1234DD / freq) [to generate that frequency]
    ; NASM has already done the math below, since DOS-BOX doesn't support the divide instructions
    
    mov     al, PIT_PROG
    out     PIT_CTL, al
    mov     al, bl
    out     PIT_CHAN2, al
    mov     al, bh
    out     PIT_CHAN2, al
    
    ; Turn on the speaker
    mov     al, [portval]
    or      al, 3
    out     SPEAKER_PORT, al
    
    ret

; end realy gross code
; ------------------------------------------------------------------------------------------------

; ------------------------------------------------------------------------------------------------
; Start Mandlebrot code
;Reference: http://jonisalonen.com/2013/lets-draw-the-mandelbrot-set/


;Using half of the columns to only draw to half the screen
PpR equ 160 ; 160 pixels per row/scanline
RpS equ 200 ; 200 rows per screen/framebuffer
ITERATIONS  equ 256
mandlebrot_task:

    ; Set up ES to be our framebuffer segment
    ;Needs to be done since es can be a lot of things in this program
    mov ax, 0xA000
    mov es, ax

;Taken from example file mouspal in the class directory
.palcycle:
    ; Select starting color (DI) for VGA palette transformation
    ; (Color transforms "wrap" around, so if we start at color
    ; 200, the first 56 colors in the table will go in palette
    ; slots 200-255, then the remaining 200 will go in 0-199...)
    mov dx, 0x3C8   ; "starting color" port
    mov ax, di
    xor ah, ah
    out dx, al
    
    ; Blast the color table out to the VGA registers
    mov cx, 256
    mov dx, 0x3C9   ; "R/G/B data" port
    mov si, palette ; source = palette array
.palloop:
    lodsb
    out dx, al      ; Red
    lodsb
    out dx, al      ; Green
    lodsb
    out dx, al      ; Blue
    loop    .palloop
    

    ; Clear screen to black (copy 320*200 byte of ZERO to the framebuffer)
    mov al, 0
    mov cx, 320*200
    mov di, 0
    rep stosb
    

;Begin Mandlebrot logic
    mov cx, 0
;Row Loop
.compare_row:
    cmp cx, RpS
    jge .end_comp_row
    ;Save cx for after inner loop
    push cx
    mov cx, 0

;Column Loop
.compare_col:
    cmp cx, PpR
    jge .end_comp_col

    ;Get current row value into bx and save again
    pop bx
    push bx

    ;So here we doa lot of flops to do a little bit of math
    ;The formula is essentially this,
    ;while(x^2 + y^2 < 4 and iterations < MAX_ITER):
    ;We actually do complex math with doing complex math by treating a complex number as an (x,y) pair
    ;Heres what we do
    ;x_new = x*x - y*y + c_re;
    ;y = 2*x*y + c_im;
    ;x = x_new;
    ;increment iterations
    ;loop
    mov word[iteration], 0
    fld dword[zero]
    fst dword[x]
    fst dword[x0]
    fst dword[y0]
    fstp dword[y]

    mov [temp_col], cx
    fild word [temp_col]
    fsub dword [width_adj]
    fmul dword [const_four]
    fdiv dword [width]
    fstp dword [x0]

    mov [temp_row], bx
    fild word [temp_row]
    fsub dword [height_adj]
    fmul dword [const_four]
    fdiv dword [width]
    fstp dword [y0]

.float_comp:
    fld dword[x]
    fmul dword[x]
    fstp dword[x2]
    fld dword[y]
    fmul dword[y]
    fstp dword[y2]
    fld dword[x2]
    fld dword[y2]
    faddp
    fld dword[const_four]

    ;Because 8086 floating point operations dont' support direct x87 flag compares we do a little bit of magic
    ;Fcmop will set the flags on the x87
    fcomp
    ;We grab the x87 status word
    fnstsw word [status_word]
    mov ax, [status_word]
    ;We need to get the values of three spefici bits of the status word namely the 9th, 11th, and 15th bits
    ;Note 17664 == 100010100000000
    mov di, 17664
    and ax, di
    ;If we get 0 back we are still less than 4
    cmp ax, 0

    je .loopy
    ;Here we check if we are equeal to 4
    mov ax, [status_word]
    and ax, 16384
    cmp ax, 16384
    jne .end_crazy_pls
.loopy:
    ;Check our iterations to see if we are still valid
    cmp word [iteration], ITERATIONS
    jge .end_crazy_pls

    ;Calculate new x and y values
    fld dword[x2]
    fld dword[y2]
    fsub
    fld dword[x0]
    fadd
    fst dword[new_x]

    fld dword[const_two]
    fld dword[x]
    fmul
    fld dword[y]
    fmul
    fld dword[y0]
    fadd
    fst dword[y]
    fld dword[new_x]
    fst dword[x]
    inc word[iteration]

    jmp .float_comp

.end_crazy_pls:
    ;Check iterations to see if we are still bounded
    cmp word[iteration], ITERATIONS
    jge .end_of_all
    ;If bounded, get the current position on the screen 
    ;320*row + col
    mov ax, 320
    imul bx
    push ax
    mov ax, cx
    pop dx
    add ax, dx

    push bx
    mov bx, ax
    mov ax, [iteration]
    add ax, [_cur_pal_offset]
    ;Set color to number of iterations + palette_offset
    mov byte[es:bx], al
    pop bx
    jmp .end_of_all
.end_of_all:
    inc cx
    jmp .compare_col
.end_comp_col:


    pop cx
    inc cx
    jmp .compare_row
.end_comp_row:

    jmp mandlebrot_task    


section .data
x0  dd  0.0
y0  dd  0.0
x   dd  0.0
new_x   dd  0.0
y   dd  0.0
x2  dd  0.0
y2  dd  0.0
zero    dd  0.0
width_adj   dd  80.0
width       dd  160.0
height_adj  dd  100.0
height      dd  200.0
const_four  dd  4.0
const_two   dd  2.0
temp_col    dw  0
temp_row    dw  0
iteration   dw  0
junk    dq  0.0
status_word dw  0
temp    dw 0

;Stolen from example file mouspal.asm
; Smooth-blending 256 color palette
; generated by a Python script
; (RGB values in the range 0-63)
palette db  0, 0, 0
    db  1, 0, 0
    db  2, 0, 0
    db  3, 0, 0
    db  4, 0, 0
    db  5, 0, 0
    db  6, 0, 0
    db  7, 0, 0
    db  8, 0, 0
    db  9, 0, 0
    db  10, 0, 0
    db  11, 0, 0
    db  12, 0, 0
    db  13, 0, 0
    db  14, 0, 0
    db  15, 0, 0
    db  16, 0, 0
    db  17, 0, 0
    db  18, 0, 0
    db  19, 0, 0
    db  20, 0, 0
    db  21, 0, 0
    db  22, 0, 0
    db  23, 0, 0
    db  24, 0, 0
    db  25, 0, 0
    db  26, 0, 0
    db  27, 0, 0
    db  28, 0, 0
    db  29, 0, 0
    db  30, 0, 0
    db  31, 0, 0
    db  32, 0, 0
    db  33, 0, 0
    db  34, 0, 0
    db  35, 0, 0
    db  36, 0, 0
    db  37, 0, 0
    db  38, 0, 0
    db  39, 0, 0
    db  40, 0, 0
    db  41, 0, 0
    db  42, 0, 0
    db  43, 0, 0
    db  44, 0, 0
    db  45, 0, 0
    db  46, 0, 0
    db  47, 0, 0
    db  48, 0, 0
    db  49, 0, 0
    db  50, 0, 0
    db  51, 0, 0
    db  52, 0, 0
    db  53, 0, 0
    db  54, 0, 0
    db  55, 0, 0
    db  56, 0, 0
    db  57, 0, 0
    db  58, 0, 0
    db  59, 0, 0
    db  60, 0, 0
    db  61, 0, 0
    db  62, 0, 0
    db  63, 0, 0
    db  63, 0, 0
    db  63, 1, 0
    db  63, 2, 0
    db  63, 3, 0
    db  63, 4, 0
    db  63, 5, 0
    db  63, 6, 0
    db  63, 7, 0
    db  63, 8, 0
    db  63, 9, 0
    db  63, 10, 0
    db  63, 11, 0
    db  63, 12, 0
    db  63, 13, 0
    db  63, 14, 0
    db  63, 15, 0
    db  63, 16, 0
    db  63, 17, 0
    db  63, 18, 0
    db  63, 19, 0
    db  63, 20, 0
    db  63, 21, 0
    db  63, 22, 0
    db  63, 23, 0
    db  63, 24, 0
    db  63, 25, 0
    db  63, 26, 0
    db  63, 27, 0
    db  63, 28, 0
    db  63, 29, 0
    db  63, 30, 0
    db  63, 31, 0
    db  63, 32, 0
    db  63, 33, 0
    db  63, 34, 0
    db  63, 35, 0
    db  63, 36, 0
    db  63, 37, 0
    db  63, 38, 0
    db  63, 39, 0
    db  63, 40, 0
    db  63, 41, 0
    db  63, 42, 0
    db  63, 43, 0
    db  63, 44, 0
    db  63, 45, 0
    db  63, 46, 0
    db  63, 47, 0
    db  63, 48, 0
    db  63, 49, 0
    db  63, 50, 0
    db  63, 51, 0
    db  63, 52, 0
    db  63, 53, 0
    db  63, 54, 0
    db  63, 55, 0
    db  63, 56, 0
    db  63, 57, 0
    db  63, 58, 0
    db  63, 59, 0
    db  63, 60, 0
    db  63, 61, 0
    db  63, 62, 0
    db  63, 63, 0
    db  63, 63, 0
    db  63, 63, 1
    db  63, 63, 2
    db  63, 63, 3
    db  63, 63, 4
    db  63, 63, 5
    db  63, 63, 6
    db  63, 63, 7
    db  63, 63, 8
    db  63, 63, 9
    db  63, 63, 10
    db  63, 63, 11
    db  63, 63, 12
    db  63, 63, 13
    db  63, 63, 14
    db  63, 63, 15
    db  63, 63, 16
    db  63, 63, 17
    db  63, 63, 18
    db  63, 63, 19
    db  63, 63, 20
    db  63, 63, 21
    db  63, 63, 22
    db  63, 63, 23
    db  63, 63, 24
    db  63, 63, 25
    db  63, 63, 26
    db  63, 63, 27
    db  63, 63, 28
    db  63, 63, 29
    db  63, 63, 30
    db  63, 63, 31
    db  63, 63, 32
    db  63, 63, 33
    db  63, 63, 34
    db  63, 63, 35
    db  63, 63, 36
    db  63, 63, 37
    db  63, 63, 38
    db  63, 63, 39
    db  63, 63, 40
    db  63, 63, 41
    db  63, 63, 42
    db  63, 63, 43
    db  63, 63, 44
    db  63, 63, 45
    db  63, 63, 46
    db  63, 63, 47
    db  63, 63, 48
    db  63, 63, 49
    db  63, 63, 50
    db  63, 63, 51
    db  63, 63, 52
    db  63, 63, 53
    db  63, 63, 54
    db  63, 63, 55
    db  63, 63, 56
    db  63, 63, 57
    db  63, 63, 58
    db  63, 63, 59
    db  63, 63, 60
    db  63, 63, 61
    db  63, 63, 62
    db  63, 63, 63
    db  63, 63, 63
    db  63, 63, 63
    db  62, 62, 62
    db  61, 61, 61
    db  60, 60, 60
    db  59, 59, 59
    db  58, 58, 58
    db  57, 57, 57
    db  56, 56, 56
    db  55, 55, 55
    db  54, 54, 54
    db  53, 53, 53
    db  52, 52, 52
    db  51, 51, 51
    db  50, 50, 50
    db  49, 49, 49
    db  48, 48, 48
    db  47, 47, 47
    db  46, 46, 46
    db  45, 45, 45
    db  44, 44, 44
    db  43, 43, 43
    db  42, 42, 42
    db  41, 41, 41
    db  40, 40, 40
    db  39, 39, 39
    db  38, 38, 38
    db  37, 37, 37
    db  36, 36, 36
    db  35, 35, 35
    db  34, 34, 34
    db  33, 33, 33
    db  32, 32, 32
    db  31, 31, 31
    db  30, 30, 30
    db  29, 29, 29
    db  28, 28, 28
    db  27, 27, 27
    db  26, 26, 26
    db  25, 25, 25
    db  24, 24, 24
    db  23, 23, 23
    db  22, 22, 22
    db  21, 21, 21
    db  20, 20, 20
    db  19, 19, 19
    db  18, 18, 18
    db  17, 17, 17
    db  16, 16, 16
    db  15, 15, 15
    db  14, 14, 14
    db  13, 13, 13
    db  12, 12, 12
    db  11, 11, 11
    db  10, 10, 10
    db  9, 9, 9
    db  8, 8, 8
    db  7, 7, 7
    db  6, 6, 6
    db  5, 5, 5
    db  4, 4, 4
    db  3, 3, 3
    db  2, 2, 2
    db  1, 1, 1


;End Mandlebrot Code
;------------------------------------------------------------------------------------------


section .data
; seed for random number generation
seed        dw 0

saved_sp    dw 0

;number of times to run before exiting
timesToRun  dw 10


ivt8_offset     dw  0
ivt8_segment    dw  0

int_msg     db "Int", 13, 10, 0

msg1        db "I am task A!", 13, 10, 0
msg2        db "I am task B!", 13, 10, 0
msg3        db "I am task C!", 13, 10, 0

;Task stacks
stack1      times 256 db 0
stack2      times 256 db 0
stack3      times 256 db 0
stack4      times 256 db 0

stacks times 4 dw 0 ;Stack pointer array array

stack_idx dw  2 ;Stating task and current task, Zero-based

NOTE_NUM  equ 130

; first number is the number of which note in the song we're on. The second is the position within that note
musicPos  db (NOTE_NUM - 1), 1

; there are 40 notes + 2 for the amen and one for a blank space to let us regain our sanity before it starts again
; we'll make NASM do the math for us on what frequencies to use
; University Hymn
musicData dw 4, (PIT_FREQ / 392), 2, (PIT_FREQ / 349), 2, (PIT_FREQ / 349), 4, (PIT_FREQ / 311), 4, (PIT_FREQ / 392), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 523), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 415), 8, (PIT_FREQ / 392), 4, (PIT_FREQ / 392), 3, (PIT_FREQ / 440), 1, (PIT_FREQ / 440), 4, (PIT_FREQ / 466), 4, (PIT_FREQ / 523), 2, (PIT_FREQ / 587), 2, (PIT_FREQ / 523), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 440), 8, (PIT_FREQ / 466), 4, (PIT_FREQ / 466), 2, (PIT_FREQ / 415), 2, (PIT_FREQ / 392), 4, (PIT_FREQ / 349), 4, (PIT_FREQ / 392), 2, (PIT_FREQ / 311), 2, (PIT_FREQ / 311), 2, (PIT_FREQ / 349), 2, (PIT_FREQ / 349), 8, (PIT_FREQ / 392), 4, (PIT_FREQ / 415), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 523), 4, (PIT_FREQ / 622), 4, (PIT_FREQ / 415), 2, (PIT_FREQ / 392), 2, (PIT_FREQ / 349), 2, (PIT_FREQ / 311), 2, (PIT_FREQ / 294), 8, (PIT_FREQ / 311), 8, (PIT_FREQ / 311), 8, (PIT_FREQ / 311), 16, 1, \
             2, (PIT_FREQ / 415), 1, (PIT_FREQ / 392), 1, (PIT_FREQ / 415), 1, (PIT_FREQ / 349), 2, (PIT_FREQ / 415), 1, (PIT_FREQ / 466), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 554), 1, (PIT_FREQ / 587), 2, (PIT_FREQ / 622), 2, (PIT_FREQ / 622), 2, (PIT_FREQ / 622), 1, (PIT_FREQ / 554), 1, (PIT_FREQ / 523), 2, (PIT_FREQ / 523), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 6, (PIT_FREQ / 523), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 2, (PIT_FREQ / 523), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 2, (PIT_FREQ / 622), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 622), 4, (PIT_FREQ / 554), 3, (PIT_FREQ / 466), 1, (PIT_FREQ / 466), 2, (PIT_FREQ / 466), 1, (PIT_FREQ / 440), 1, (PIT_FREQ / 466), 2, (PIT_FREQ / 466), 1, (PIT_FREQ / 440), 1, (PIT_FREQ / 466), 6, (PIT_FREQ / 554), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 466), 1, (PIT_FREQ / 523), 2, (PIT_FREQ / 622), 1, (PIT_FREQ / 622), 2, (PIT_FREQ / 699), 2, (PIT_FREQ / 699), 6, (PIT_FREQ / 466), 2, (PIT_FREQ / 622), 2, (PIT_FREQ / 622), 1, (PIT_FREQ / 554), 1, (PIT_FREQ / 523), 2, (PIT_FREQ / 523), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 6, (PIT_FREQ / 523), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 2, (PIT_FREQ / 523), 1, (PIT_FREQ / 494), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 554), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 466), 1, (PIT_FREQ / 392), 4, (PIT_FREQ / 466), 3, (PIT_FREQ / 415), 1, (PIT_FREQ / 415), 2, (PIT_FREQ / 415), 1, (PIT_FREQ / 392), 1, (PIT_FREQ / 415), 2, (PIT_FREQ / 494), 1, (PIT_FREQ / 466), 1, (PIT_FREQ / 415), 5, (PIT_FREQ / 831), 1, (PIT_FREQ / 415), 1, (PIT_FREQ / 466), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 622), 1, (PIT_FREQ / 415), 1, (PIT_FREQ / 466), 1, (PIT_FREQ / 523), 1, (PIT_FREQ / 622), 1, (PIT_FREQ / 311), 1, (PIT_FREQ / 349), 1, (PIT_FREQ / 523), 4, (PIT_FREQ / 466), 2, (PIT_FREQ / 415), 1, (PIT_FREQ / 415), 16, 1
             ; other music . . .
portval   dw 0

;External Variables used in C functions
global _cur_pal_offset
_cur_pal_offset dw 0
global _currPos0
_currPos0 dw 0
global _currPos1
_currPos1 dw 60
global _currPos2
_currPos2 dw 120