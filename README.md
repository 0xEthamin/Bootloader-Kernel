# x86 Bootloader

This project is a complete x86 bootloader that switches to long mode (64bit) and calls a C kernel (64bit).  

The future idea would be to call rust instead of C  

It's double-staged because it's too long to fit on 512 bytes.  
So src/boot/stage1.asm is the entry point that calls src/boot/stage2.asm.
