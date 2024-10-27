[BITS 16]
[ORG 0x7C00]

STAGE2_SECTORS equ 2
STAGE2_ADDR    equ 0x7E00   ; just after the boot sector

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    mov [bootDrive], dl

    ; load stage2
    mov ah, 0x02            ; Read sectors
    mov al, STAGE2_SECTORS  ; Number of sectors to read
    mov ch, 0               ; Cylinder number
    mov cl, 2               ; Sector number
    mov dh, 0               ; Head number
    mov dl, [bootDrive]     ; Drive number
    mov bx, STAGE2_ADDR     ; Buffer address es:bx
    int 0x13
    jc diskError

    ; Give control to stage2
    mov dl, [bootDrive]
    jmp STAGE2_ADDR

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

;;;;;;;;;;;; DATA ;;;;;;;;;;;;

bootDrive db 0
DISK_ERROR_MSG db "Disk read error!", 0

times 510-($-$$) db 0
dw 0xaa55
