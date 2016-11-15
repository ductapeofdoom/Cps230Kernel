@echo off

if not defined DevEnvDir (
    call "\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"
)
nasm -fbin -ombr.com lab9_mbr.asm
nasm -fbin -opayload.com lab9_payload.asm
cl mkfloppy.c
call mkfloppy.exe boot.img mbr.com payload.com