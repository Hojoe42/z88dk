;
; Based on an article by
; Laurens Holst, Ricardo Bittencourt, Arturo Ragozini
;

; PSG version (TIKI100, 4mhz CPU)
; calibrated for a fixed 8khz bitrate

;
;$Id: playzb4.asm $
;

; extern void __LIB__ playzb4(uchar *SamStart, ushort SamLen);
; play 4 bit pulse wave encoded data using sid master volume

    SECTION code_clib

    PUBLIC  playzb4
    PUBLIC  _playzb4
    
    EXTERN  psg_init

playzb4:
_playzb4:

;call    csv
;ld      l,(ix+6)        ;sample start addr
;ld      h,(ix+7)
;ld      e,(ix+8)        ;sample length
;ld      d,(ix+9)

;-------------------------------------
; Resets the PSG (Tiki100 $16,$17.  MSX=$A0,$A1)
;-------------------------------------

    call    psg_init

    xor     a
    ;ld      e,a
    ld      bc,$ff17      ; $17
    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    inc     a
    out     (c),b

    out     ($16),a
    ld      b,$bf
    out     (c),b
    exx
        
    pop     bc
    pop     de                          ;sample length
    pop     hl                          ;sample start addr
    push    hl
    push    de
    push    bc

rep1:

    ld      a, (hl)                     ; a = sample byte
    and     $f0                         ; 4 bit nibble

    call    play_sample

    ld      a, (hl)                     ; a = sample byte
    rlca                                ; a = a div 16
    rlca                                ;
    rlca                                ;
    rlca                                ;
    and     $f0                         ; 4 bit nibble

    call    play_sample

    inc     hl                          ; hl = hl+1
    dec     e                           ;
    jr      nz, rep1                    ;
    dec     d                           ; de = de-1
    jr      nz, rep1                    ;until de = 0

    ret



;
play_sample:

    ; Tuned for a 4mhz CPU
    ld      b, 20
rep1b:                                  ;repeat
    djnz    rep1b

    exx
    ld e,a
    ld hl,PSG_SAMPLE_TABLE
    add hl,de
    ld b,(hl)
    inc h
    ld e,(hl)
    inc h
    ld h,(hl)
    ld a,8          ; YM volume level register
    out ($16),a     ; play as fast as possible
    inc a
    out (c),b
    out ($16),a
    out (c),e
    inc a
    out ($16),a
    out (c),h
    exx
    ret
    


PSG_SAMPLE_TABLE:
    defb 00,01,02,03,04,03,05,03,04,05,06,06,05,06,06,06
    defb 06,06,07,06,07,08,08,08,07,07,09,07,09,09,08,08
    defb 09,09,08,09,09,09,09,09,10,10,10,10,09,09,10,10
    defb 10,10,09,10,11,11,11,11,11,11,11,11,10,10,10,11
    defb 11,11,11,11,11,11,11,12,11,11,12,12,11,12,11,12
    defb 12,12,12,11,12,11,12,12,12,12,11,12,12,12,12,11
    defb 12,13,12,13,11,13,13,13,13,13,13,11,13,13,13,13
    defb 13,13,13,12,13,13,13,12,12,13,12,13,13,13,13,13
    defb 13,12,13,13,13,13,13,13,13,14,13,13,14,14,14,14
    defb 14,14,13,14,14,13,14,14,14,14,14,14,13,14,14,14
    defb 14,14,14,13,14,14,13,14,14,13,13,14,14,14,14,14
    defb 14,14,14,14,13,14,14,13,14,14,14,14,14,14,13,14
    defb 14,14,15,14,15,15,15,15,15,15,15,15,15,15,15,15
    defb 14,15,15,15,15,15,15,14,15,15,15,15,15,15,15,15
    defb 15,15,15,15,15,15,15,15,15,15,15,14,15,14,14,14
    defb 14,14,15,15,14,15,15,14,15,15,15,15,15,15,15,14

    defb 00,00,00,00,00,02,00,02,02,03,01,02,04,04,03,04
    defb 04,05,04,05,05,02,03,04,06,06,01,06,02,03,06,07
    defb 05,06,07,06,06,06,07,06,04,04,05,06,08,07,06,06
    defb 07,06,08,07,03,04,03,04,04,05,05,05,08,09,09,07
    defb 07,07,08,07,08,08,08,02,08,09,03,05,09,05,08,06
    defb 06,07,06,10,07,09,08,07,08,08,09,08,08,09,08,10
    defb 09,00,08,01,10,02,03,04,04,05,06,10,06,06,06,07
    defb 06,07,07,10,08,08,07,11,11,08,11,08,09,09,09,08
    defb 09,11,09,09,10,10,10,10,10,00,10,09,02,02,04,03
    defb 04,04,11,05,05,11,07,07,07,07,07,08,10,08,08,08
    defb 08,08,09,11,09,09,12,08,09,12,11,09,10,10,09,10
    defb 10,10,10,09,11,10,10,12,10,10,11,11,11,10,12,11
    defb 11,11,00,11,01,02,03,04,03,04,04,05,05,05,06,07
    defb 12,07,07,07,08,07,08,12,08,08,08,09,08,09,09,09
    defb 08,09,09,09,09,10,10,09,10,10,10,13,09,13,13,13
    defb 13,13,10,11,13,11,10,13,11,11,11,11,11,10,10,12

    defb 00,00,00,00,00,00,00,01,01,00,00,00,01,00,02,02
    defb 03,02,01,04,01,01,01,01,03,04,00,05,01,01,04,01
    defb 01,00,04,02,03,04,01,05,01,02,01,00,02,06,03,04
    defb 01,05,06,04,00,00,02,02,03,02,03,04,06,02,03,02
    defb 03,04,00,05,02,03,04,00,05,00,02,00,03,02,07,01
    defb 02,00,04,00,03,07,00,05,02,03,08,04,05,00,06,07
    defb 03,00,07,00,08,01,01,01,02,01,00,09,02,03,04,01
    defb 05,03,04,07,01,02,06,01,02,05,04,06,02,03,04,07
    defb 05,07,06,06,00,01,02,03,04,00,05,08,00,01,00,02
    defb 02,03,00,03,04,03,00,01,02,03,04,00,09,02,03,04
    defb 04,05,00,08,02,03,00,07,05,03,09,06,00,01,07,03
    defb 04,04,05,08,10,06,06,08,07,07,00,00,01,08,09,04
    defb 05,05,00,06,00,00,00,00,02,02,03,02,03,04,03,00
    defb 01,02,03,04,00,05,02,06,04,04,05,00,06,02,03,04
    defb 07,05,05,06,06,00,01,07,03,04,04,00,08,02,03,04
    defb 04,05,07,00,06,01,08,07,04,05,05,06,06,09,09,11

