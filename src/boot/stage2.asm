[BITS 16]
[ORG 0x7E00]

;;;;;;;;;;;; CONSTANTS ;;;;;;;;;;;;

KERNEL_SECTORS equ 20
KERNEL_ADDR_TMP equ 0x1000 ; will be moved after jumping to protected mode
KERNEL_ADDR equ 0x100000   ; 1MB

PML4_BASE equ 0x1000
PDPT_BASE equ 0x2000
PD_BASE   equ 0x3000
PT_BASE   equ 0x4000

CODE_SEG equ gdtCode - gdtStart
DATA_SEG equ gdtData - gdtStart
CODE_SEG_64 equ gdt64Code - gdt64Start
DATA_SEG_64 equ gdt64Data - gdt64Start

;;;;;;;;;;;; MAIN CODE ;;;;;;;;;;;;

start:
    cli

    mov [bootDrive], dl
    call loadKernel

    mov ah, 0x0           ; Set video mode
    mov al, 0x3           ; 80x25 16-color text mode
    int 0x10              ; Call BIOS video interrupt


    ; load GDT
    lgdt [gdtDescriptor]

    ; Enable A20 line
    in al, 0x92
    or al, 2               
    out 0x92, al

    ; Switch to protected mode
    mov eax, cr0           
    or eax, 1             ; Set PE (Protection Enable) bit
    mov cr0, eax 

    ; Far jump to flush the prefetch queue and load new CS
    jmp CODE_SEG:protectedMode

loadKernel:
    pusha

    mov ah, 0x02                ; Read sectors
    mov al, KERNEL_SECTORS      ; Number of sectors to read
    mov ch, 0x00                ; Cylinder number
    mov cl, 0x04                ; Sector number
    mov dh, 0x00                ; Head number
    mov dl, [bootDrive]         ; Drive number
    mov bx, KERNEL_ADDR_TMP     ; Buffer address es:bx
    int 0x13
    jc diskError

    popa
    ret

diskError:
    mov si, DISK_ERROR_MSG
    call printString
    jmp $

printString:
    pusha
    mov ah, 0x0E               ; Teletype output
    .loop:
        lodsb                  ; AL = [DS:SI], SI++
        test al, al            ; End of string?
        je .done
        int 0x10               ; Print character in AL
        jmp .loop
    .done:
        popa
        ret


[BITS 32]
protectedMode:
    ; We are now in protected mode
    mov ax, DATA_SEG      
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ebp, 0x9C00      ; Set up stack beyond bootloader
    mov esp, ebp

    call moveKernel

    call checkCpuid
    call checkLongMode
    call setupPaging

    lgdt [gdt64Descriptor]
    
    mov ax, DATA_SEG_64
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    jmp CODE_SEG_64:longMode

moveKernel:
    push esi
    push edi
    push ecx
    
    mov esi, KERNEL_ADDR_TMP        ; Source
    mov edi, KERNEL_ADDR            ; Destination
    mov ecx, KERNEL_SECTORS * 512   ; Size in bytes
    rep movsb                       ; Copy bytes
    
    pop ecx
    pop edi
    pop esi
    ret

error:
    ; Error letter in al
    mov dword [0xb8000], 0x4f524f45 ; white on red  "ER
    mov dword [0xb8004], 0x4f3a4f52 ; white on red  "R:"
    mov dword [0xb8008], 0x4f204f20 ; white on red  "  "
    mov byte  [0xb800a], al         ; second space is overwritten by the error letter
    hlt
    jmp $
    ; C = noCPUID, L = noLongMode

checkCpuid:
    ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
    ; in the FLAGS register. If we can flip it, CPUID is available.
    pusha

    pushfd
    pop eax          ; Get the FLAGS register

    
    mov ecx, eax     ; Copy it to ECX for later comparison
    
    xor eax, 1 << 21 ; Flip the ID bit

    
    push eax
    popfd            ; Copy EAX to FLAGS via the stack

    pushfd
    pop eax          ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)

    push ecx
    popfd            ; Restore FLAGS from the old version stored in ECX

    
    cmp eax, ecx     ; Compare EAX and ECX. If they are equal then that means the bit
    je .noCpuid      ; wasn't flipped, and CPUID isn't supported.

    popa
    ret
.noCpuid:
    mov al, "C"
    jmp error

checkLongMode:
    pusha

    ; Check if extended functions are available
    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb .NoLongMode

    ; Check if long mode is available
    mov eax, 0x80000001
    cpuid
    test edx, 1 << 29      ; Test if the LM-bit, which is bit 29, is set in the D-register.
    jz .NoLongMode

    popa
    ret

.NoLongMode:
    mov al, "L"
    jmp error

setupPaging:
    ; Clear memory for paging structures
    mov edi, PML4_BASE
    mov cr3, edi        ; Set CR3 to point to PML4
    xor eax, eax
    mov ecx, 4096
    rep stosd          ; Clear 4096 dwords (16KB total for all tables)
    mov edi, cr3       ; Reset EDI to PML4 base

    ; PML4[0] -> PDPT
    mov eax, PDPT_BASE
    or eax, 0b11       ; Present + Writable
    mov [PML4_BASE], eax
    
    ; PDPT[0] -> PD
    mov eax, PD_BASE
    or eax, 0b11       ; Present + Writable
    mov [PDPT_BASE], eax
    
    ; PD[0] -> PT
    mov eax, PT_BASE
    or eax, 0b11       ; Present + Writable
    mov [PD_BASE], eax
    
    ; Identity map first 2MB using 4KB pages
    mov edi, PT_BASE
    mov eax, 0         ; Start at physical address 0
    mov ecx, 512       ; Map 512 pages (2MB)
    
    .mapPages:
        or eax, 0b11       ; Present + Writable
        mov [edi], eax
        add eax, 0x1000    ; Next page (4KB)
        add edi, 8         ; Next entry
        loop .mapPages
    
    ; Enable PAE
    mov eax, cr4
    or eax, 1 << 5     ; Set PAE bit
    mov cr4, eax
    
    ; Set long mode bit in EFER MSR
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8     ; Set LM bit
    wrmsr
    
    ; Enable paging
    mov eax, cr0
    or eax, 1 << 31    ; Set PG bit
    mov cr0, eax
    
    ret

[BITS 64]
longMode:
    ; We are now in long mode
    cli
    mov ax, DATA_SEG_64
    mov ds, ax 
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    
    ;Call the kernel
    jmp KERNEL_ADDR

;;;;;;;;;;;; DATA ;;;;;;;;;;;;

bootDrive db 0
DISK_ERROR_MSG db "Disk read error!", 0

;;;;;;;;;;;; GDT ;;;;;;;;;;;;;

gdtStart:
    ; Mandatory null entry
    dq 0

gdtCode:        ; Code segment
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10011010b ; Access byte 
    db 11001111b ; Flags
    db 0x0

gdtData:       ; Data segment
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10010010b
    db 11001111b
    db 0x0

gdtEnd:

gdtDescriptor:
    dw gdtEnd - gdtStart - 1   ; Size
    dd gdtStart                ; Start address


gdt64Start:
    dq 0

gdt64Code:
    dw 0xFFFF
    dw 0
    db 0
    db 10011010b
    db 10101111b        ; flags are not the same as 32-bit
    db 0

gdt64Data:
    dw 0xFFFF
    dw 0
    db 0
    db 10010010b
    db 11001111b
    db 0

gdt64End:

gdt64Descriptor:
    dw gdt64End - gdt64Start - 1  ; Size
    dq gdt64Start                 ; Address