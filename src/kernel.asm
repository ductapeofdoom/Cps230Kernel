; CpS 230 Team Project: Nathan Collins and Stephen Sidwell
;---------------------------------------------------
; description goes here
;---------------------------------------------------
bits 16

;For boostrapped programs, all addresses start at 0
org 0x0

; Where to find the INT 8 handler vector within the IVT [interrupt vector table]
IVT8_OFFSET_SLOT    equ 4 * 8           ; Each IVT entry is 4 bytes; this is the 8th
IVT8_SEGMENT_SLOT   equ IVT8_OFFSET_SLOT + 2    ; Segment after Offset

section .text
start:

    ;Make code and data segments the same to simplify addressing
    mov     ax, cs
    mov     ds, ax

    ; Set ES=0x0000 (segment of IVT)
    mov     ax, 0x0000
    mov     es, ax
    

    ;do stuff
    jmp     bootstrap
done:
    ; ; Terminate program
    ; mov     ah, 0x4C  ; DOS API Function number (terminate with status code)
    ; mov     al, 0     ; Parameter (status code 0 == success)
    ; int     0x21      ; Call DOS
    ;Loop infinitley
    jmp $

;some ideas for later
;stacks      times 32 dw  0 ; 32 stacks
;currProg    dw  0 ; id of currently executing task
;numProg     dw  2 ; number of tasks we want to run

task1:
    ; mov     ah, 0x09            ; DOS API Function number (write string)
    mov     dx, msg1            ; Parameter (pointer to "$"-terminated ASCII string)
    ; int     0x21                ; Call DOS (via a "software interrupt")
    ;Use BIOS I/O instead of DOS I/O
    call    puts
    jmp     task1
    ; call    yield
    ; jmp     task1

task2:
    ; mov	    ah, 0x09            ; DOS API Function number (write string)
    mov	    dx, msg2            ; Parameter (pointer to "$"-terminated ASCII string)
    ; int	    0x21                ; Call DOS (via a "software interrupt")
    ;Use BIOS I/O instead of DOS I/O
    call    puts
    jmp     task2
    ;stop after 10 times
    ; dec     WORD [timesToRun] 
    ; cmp     WORD [timesToRun], 0
    ; je      done
    
    ; call    yield
    ; jmp     task2

yield:
    ;Flags, CS, and IP should all have been pushed by the interrupt
    ;Push GPRs 
    pusha
    ;Push DS and ES
    push    ds
    push    es
    
    call    playMusic
    
    ;Switch stacks
    xchg    [saved_sp], sp  
    pop     es
    pop     ds
    popa
    ;Chain to next interrupt handler
    jmp far [cs:ivt8_offset]    ; Use CS as the segment here, since who knows what DS is now

start_first_task:
    pop     es
    pop     ds
    popa
    iret

bootstrap:
    mov     sp, stack2 + 255 ; top of stack2
    pushf
    push    cs
    push    task2            ; location to return to
    pusha
    push    ds
    push    es
    mov     [saved_sp], sp
    
    mov     sp, stack1 + 255 ; top of stack1
    pushf
    push    cs
    push    task1            ; location to return to
    pusha
    push    ds
    push    es

    ; TODO Install interrupt hook
    ; 0. disable interrupts (so we can't be...INTERRUPTED...)
    cli
    ; 1. save current INT 8 handler address (segment:offset) into ivt8_offset and ivt8_segment
    mov     ax, [es:IVT8_SEGMENT_SLOT]
    mov     [ivt8_segment], ax
    mov     ax, [es:IVT8_OFFSET_SLOT]
    mov     [ivt8_offset], ax
    ; 2. set new INT 8 handler address (OUR code's segment:offset)
    mov     [es:IVT8_SEGMENT_SLOT], cs
    mov     word [es:IVT8_OFFSET_SLOT], yield

    jmp     start_first_task

setupRand:
    ; BIOS call to get current system time
    mov     ah, 0x01
    int     0x1A
    mov     [seed], dx ; return value
    ret

getRand:
    ; C equivalent:
        ; x = current_time()
        ; seed = seed * x + 1337
    ; return value goes in ax
    ; trashes ax and dx at least
    
    ; BIOS call to get system time
    mov     ah, 0x01
    int     0x1A
    ; puts result in dx
    
    mov     ax, [seed]
    imul    ax, dx ; result from the call to get time
    ; imul puts result in ax:dx
    
    mov     ax, dx
    add     ax, 1337 ; response goes in ax
    ret

puts:
    push    ax
    push    cx
    push    si
    
    mov     ah, 0x0e
    mov     cx, 1       ; no repetition of chars
    
    mov     si, dx
.loop:
    mov     al, [si]
    inc     si
    cmp     al, 0
    jz      .end
    int     0x10
    jmp     .loop
.end:
    pop     si
    pop     cx
    pop     ax
    ret

; ------------------------------------------------------------------------------------------------
; now all the really gross code for the music

SPEAKER_PORT    equ 0x61
PIT_CTL         equ 0x43
PIT_PROG        equ 0xb6      ; 0b10110110: 10 (chan 2) 11 (read LSB/MSB) 011 (mode 3) 0 (binary)
PIT_CHAN2       equ 0x42
PIT_FREQ        equ 0x1234DD

playMusic:
    mov     ax, [musicPos]
    dec     ah ; the position within the note
    
    jz      .nextNote ; if we're at the last position within a note
    
    ; if not
    mov     [musicPos], ax
    
    ; we want to put a space at the end of a note just before we switch to the next note
    cmp     ah, 1
    je      .space
    
    ret

.space:
    mov	al, [portval]
	out	SPEAKER_PORT, al
    
    ret
    
.nextNote:
    inc     al ; go to the next note
    
    cmp     al, 43 ; there are 3 notes
    jne     .after
    mov     al, 0
    
.after:
    mov     bl, al
    mov     bh, 0
    shl     bx, 2
    
    mov     ah, [musicData + bx]
    shl     ah, 2 ; multiply by 4 so the music isn't too fast to hear
    
    ; I think we're all done with messing around with ax, so we can go ahead and store it back in it's place
    mov     [musicPos], ax
    
    ; get the current frequency to play
    mov     bx, [musicData + bx + 2]
    
    ; now we need to play that music
    ; copied/edited from example code
    
    ; Capture initial speaker state
	in	al, SPEAKER_PORT
	and	al, 0xfc
	mov	[portval], al

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

stack1      times 256 db 0
stack2      times 256 db 0

; first number is the number of which note in the song we're on. The second is the position within that note
musicPos  db 42, 1
; there are 40 notes + 2 for the amen and one for a blank space to let us regain our sanity before it starts again
; we'll make NASM do the math for us on what frequencies to use
musicData dw 4, (PIT_FREQ / 392), 2, (PIT_FREQ / 349), 2, (PIT_FREQ / 349), 4, (PIT_FREQ / 311), 4, (PIT_FREQ / 392), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 523), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 415), 8, (PIT_FREQ / 392), 4, (PIT_FREQ / 392), 3, (PIT_FREQ / 440), 1, (PIT_FREQ / 440), 4, (PIT_FREQ / 466), 4, (PIT_FREQ / 523), 2, (PIT_FREQ / 587), 2, (PIT_FREQ / 523), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 440), 8, (PIT_FREQ / 466), 4, (PIT_FREQ / 466), 2, (PIT_FREQ / 415), 2, (PIT_FREQ / 392), 4, (PIT_FREQ / 349), 4, (PIT_FREQ / 392), 2, (PIT_FREQ / 311), 2, (PIT_FREQ / 311), 2, (PIT_FREQ / 349), 2, (PIT_FREQ / 349), 8, (PIT_FREQ / 392), 4, (PIT_FREQ / 415), 2, (PIT_FREQ / 466), 2, (PIT_FREQ / 523), 4, (PIT_FREQ / 622), 4, (PIT_FREQ / 415), 2, (PIT_FREQ / 392), 2, (PIT_FREQ / 349), 2, (PIT_FREQ / 311), 2, (PIT_FREQ / 294), 8, (PIT_FREQ / 311), 8, (PIT_FREQ / 311), 8, (PIT_FREQ / 311), 16, 1
portval   dw 0