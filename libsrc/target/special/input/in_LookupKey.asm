; uint in_LookupKey(uchar c)

    SECTION code_clib
    PUBLIC  in_LookupKey
    PUBLIC  _in_LookupKey
    EXTERN  in_keytranstbl

; Given the ascii code of a character, returns the scan row and mask
; corresponding to the key that needs to be pressed to generate the
; character.
;
; The scan row returned will have bit 7 set and bit 6 set to
; indicate if CAPS, SYM SHIFTS also have to be pressed to generate the
; ascii code, respectively.

; enter: L = ascii character code
; exit : L = scan row
;        H = mask
;        else: L = scan row, H = mask
;              bit 7 of L set if SHIFT needs to be pressed
;              bit 6 of L set if CTRL needs to be pressed
; uses : AF,BC,HL

; The 16-bit value returned is a scan code understood by
; in_KeyPressed.

in_LookupKey:
_in_LookupKey:
    ld      a, l
    ld      hl, in_keytranstbl
    ld      bc, 72*3
    cpir
    jr      nz, notfound

    ld      a, +(72*3)-1
    sub     c                           ;A = position in table
    ld      c, a
    ld      hl, 0
    cp      72*2
    jr      c, not_function_table
    sub     72*2
    ld      c, a
    ld      a, l
    or      @01000000
    ld      l, a
    jr      continue

notfound:
    ld      hl, 0
    scf
    ret


not_function_table:
    cp      72
    jr      c, continue
    sub     72
    ld      c, a
    ld      a, l
    or      @10000000
    ld      l, a

continue:
	; l = flags
	; c = character
	; find the row divide by 6
    ld      a, c
    ld      c, 255
find_row:
    inc     c
    sub     6
    jr      nc, find_row
    add     6
	; c = row number, a = character in row
	; find the mask
    ld      b, @00000100
    ld      e, a
find_mask:
    ld      a, e
    and     a
    jr      z, found_mask
    ld      a, b
    rlca
    ld      b, a
    dec     e
    jr      find_mask

found_mask:
	; l = modifiers
	; c = row number
	; b = mask
    ld      a, l
    or      c
    ld      l, a
    ld      h, b
    and     a
    ret


