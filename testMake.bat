@echo off

rem assemble the asm files
nasm -fbin -o build\mbr.com src\boot.asm
nasm -fobj -o build\payload.obj src\kernel.asm

rem compile the C file
call tools\binnt\wcc -0 -od -s -zls src\test.c > NUL

rem move the output of the C compilation to the build folder
move test.obj build\ > NUL

rem now link it
call tools\binnt\wlink format DOS name build\payload.com file build\payload.obj file build\test.obj

rem put stuff together into floppy disk image
call tools\mkfloppy.exe build/boot.img build/mbr.com build/payload.com

rem start DOS-Box
call tools\dbd.exe .

rem when we close DOS-Box, clean off the screen
cls