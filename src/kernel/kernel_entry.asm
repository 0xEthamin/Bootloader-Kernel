section .text
    [bits 64]
    [extern _start]
    call _start
    jmp $

; This is the entry point for our kernel, which will be assembled in ELF format, so we can't put it directly in the boot.asm file.
