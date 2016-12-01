@echo off

nasm -fbin -o build/mbr.com src\boot.asm
nasm -fbin -o build/payload.com src\kernel.asm

call tools\mkfloppy.exe build/boot.img build/mbr.com build/payload.com

call tools\dbd.exe .

cls