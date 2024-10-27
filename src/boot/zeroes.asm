times 12800 db 0 ; 25 sectors of 512 bytes each

; We want to be able to read a large number of sectors to be sure of reading the entire kernel.
; but if we read more sectors than the size of the disk, it'll cause an error
; So we fill with zeroes.