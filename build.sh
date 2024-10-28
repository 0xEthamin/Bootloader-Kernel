export PATH=$PATH:/usr/local/x86_64elfgcc/bin

nasm "src/boot/stage1.asm" -f bin -o "Binaries/stage1.bin"
nasm "src/boot/stage2.asm" -f bin -o "Binaries/stage2.bin"

dd if=/dev/zero of=Binaries/boot.bin bs=512 count=3
dd if=Binaries/stage1.bin of=Binaries/boot.bin conv=notrunc
dd if=Binaries/stage2.bin of=Binaries/boot.bin seek=1 conv=notrunc

nasm "src/boot/zeroes.asm" -f bin -o "Binaries/zeroes.bin"

nasm "src/kernel/kernel_entry.asm" -f elf64 -o "Binaries/kernel_entry.o"
x86_64-elf-gcc -ffreestanding -m64 -g -c "src/kernel/kernel.cpp" -o "Binaries/kernel.o"
x86_64-elf-ld -o "Binaries/full_kernel.bin" -Ttext 0x100000 "Binaries/kernel_entry.o" "Binaries/kernel.o" --oformat binary

cat "Binaries/boot.bin" "Binaries/full_kernel.bin" "Binaries/zeroes.bin"  > "Binaries/OS.bin"

find Binaries/ -type f ! -name "OS.bin" | xargs rm -f

qemu-system-x86_64 -drive format=raw,file="Binaries/OS.bin",index=0,if=floppy,  -m 128M 
