short functionThatKeepsStuffFromBreaking(short x) {
    return 5 + 3;
}

short setPixel(short x, short y, short value) {
    short pos = (320 * y + x);
    
    __asm {
        push    ax
        push    di
        push    dx
        
        mov     ax, 0xA000
        mov     di, pos
        push    es
        push    ax
        pop     es
        mov     ax, value
        stosb
        pop     es
        
        pop     dx
        pop     di
        pop     ax
    }
    return 0;
}

void moveBlock(short curPos, short yPos) {
    short x = curPos + 160;
    short y = yPos;
    for (; y < yPos + 10; y ++) {
        setPixel(x, y, 0); // black in Stephen's pallette
    }
    
    x = curPos + 11;
    x = (x % 160);
    x += 160;
    
    y = yPos;
    for (; y < yPos + 10; y ++) {
        setPixel(x, y, 193); // white in Stephen's pallette
    }
}

extern short currPos0;
extern short currPos1;
extern short currPos2;
// short currPos0 = 0;
// short currPos1 = 60;
// short currPos2 = 120;

void moveBlock0() {
    moveBlock(currPos0, 50);
    currPos0 ++;
    currPos0 = currPos0 % 160;
}

void moveBlock1() {
    moveBlock(currPos1, 100);
    currPos1 ++;
    currPos1 = currPos1 % 160;
}

void moveBlock2() {
    moveBlock(currPos2, 150);
    currPos2 ++;
    currPos2 = currPos2 % 160;
}
