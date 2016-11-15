@echo off

if not defined DevEnvDir (
    call "\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat"
)
cd build
nasm -fbin -ombr.com ..\src\bootstrapper.asm
nasm -fbin -opayload.com ..\src\kernel.asm
cl ..\src\mkfloppy.c
call mkfloppy.exe boot.img mbr.com payload.com
cd ..