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
    mov ax, 0x0000
    mov es, ax
    

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
    jmp task1
    ; call    yield
    ; jmp     task1

task2:
    ; mov	    ah, 0x09            ; DOS API Function number (write string)
    mov	    dx, msg2            ; Parameter (pointer to "$"-terminated ASCII string)
    ; int	    0x21                ; Call DOS (via a "software interrupt")
    ;Use BIOS I/O instead of DOS I/O
    call puts
    jmp task2
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
    push ds
    push es
    
    ;Switch stacks
    xchg    [saved_sp], sp  
    pop es
    pop ds
    popa
    ;Chain to next interrupt handler
    jmp far [cs:ivt8_offset]    ; Use CS as the segment here, since who knows what DS is now

start_first_task:
    pop es
    pop ds
    popa
    iret

bootstrap:
    mov     sp, stack2 + 255 ; top of stack2
    pushf
    push cs
    push    task2            ; location to return to
    pusha
    push ds
    push es
    mov     [saved_sp], sp
    
    mov     sp, stack1 + 255 ; top of stack1
    pushf
    push cs
    push    task1            ; location to return to
    pusha
    push ds
    push es

    ; TODO Install interrupt hook
    ; 0. disable interrupts (so we can't be...INTERRUPTED...)
    cli
    ; 1. save current INT 8 handler address (segment:offset) into ivt8_offset and ivt8_segment
    mov ax, [es:IVT8_SEGMENT_SLOT]
    mov [ivt8_segment], ax
    mov ax, [es:IVT8_OFFSET_SLOT]
    mov [ivt8_offset], ax
    ; 2. set new INT 8 handler address (OUR code's segment:offset)
    mov [es:IVT8_SEGMENT_SLOT], cs
    mov word[es:IVT8_OFFSET_SLOT], yield

    jmp start_first_task

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


section .data
; seed for random number generation
seed        dw 0

saved_sp    dw 0

;number of times to run before exiting
timesToRun dw 10


ivt8_offset dw  0
ivt8_segment    dw  0

int_msg     db "Int", 13, 10, 0

msg1        db "I am task A!", 13, 10, 0
msg2        db "I am task B!", 13, 10, 0

stack1      times 256 db 0
stack2      times 256 db 0