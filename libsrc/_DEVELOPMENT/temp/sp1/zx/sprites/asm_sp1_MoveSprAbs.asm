; void sp1_MoveSprAbs(struct sp1_ss *s, struct sp1_Rect *clip, uchar *frame, uchar row, uchar col, uchar vrot, uchar hrot)
; 04.2006 aralbrec, Sprite Pack v3.0
; sinclair spectrum version

; *** PLEASE HELP ME I'VE BEEN MADE UGLY BY BUGFIXES

INCLUDE "config_private.inc"

SECTION code_clib
SECTION code_temp_sp1

PUBLIC asm_sp1_MoveSprAbs

EXTERN asm_sp1_GetUpdateStruct, __sp1_add_spr_char, __sp1_remove_spr_char

asm_sp1_MoveSprAbs:

; enter: ix = & struct sp1_ss 
;        hl = sprite frame address (0 = no change)
;         d = new row coord in chars 
;         e = new col coord in chars 
;         b = new horizontal rotation (0..7) ie horizontal pixel position 
;         c = new vertical rotation (0..7) ie vertical pixel position 
;        iy = clipping rectangle entirely on screen
;             (iy+0) = row, (iy+1) = col, (iy+2) = width, (iy+3) = height
; uses : all except ix, iy which remain unchanged

   ld (ix+5),b             ; store new horizontal rotation
   ld a,b
   
   cp (ix+17)              ; decide if last col should draw, result in b
   rl b
   
   add a,a
   add a,SP1V_ROTTBL/256
   ld (ix+9),a             ; store effective horizontal rotation (MSB of lookup table to use)
   
   xor a
   sub c                   ; a = - (vertical rotation in pixels)
   bit 7,(ix+4)
   jp z, onebytedef
   sub c                   ; a = - 2*(vertical rotation) for 2-byte definitions
   set 7,c

.onebytedef

   ld (ix+4),c             ; store new vertical rotation
   ld c,a                  ; c = vertical rotation offset for graphics ptrs
   
   ld a,(ix+4)             ; decide if last row should draw
   and $07
   cp (ix+18)
   ld a,b
   rla
   ex af,af

   ld a,h
   or l
   jr nz, newframe
   
   ld l,(ix+6)
   ld h,(ix+7)             ; hl = old sprite frame pointer
   jp framerejoin
   
.newframe

   ld (ix+6),l
   ld (ix+7),h             ; store new frame pointer
   
.framerejoin

   ld a,c
   or a
   jr z, skipadj
   
   ld b,$ff                ; bc = negative vertical rotation offset
   add hl,bc               ; add vertical rotation offset

.skipadj

   ld (ix+11),l
   ld (ix+12),h            ; store new effective offset for graphics pointers
   
   ;  d = new row coord (chars)
   ;  e = new col coord (chars)
   ; ix = & struct sp1_ss
   ; iy = clipping rectangle
   ; a' = bit 0 = 1 if last row should not draw, bit 1 = 1 if last col should not draw
   ;
   ; 329 cycles to this point worst case

   ld (ix+19),0

   ld a,(ix+0)             ; has the row coord changed?
   cp d
   jp nz, changing0
   ld a,(ix+1)             ; has the col coord changed?
   cp e
   jp nz, changing1

; not changing character coordinate, no need to remove sprite from update struct lists

; /////////////////////////////////////////////////////////////////////////////////
;              MOVE SPRITE, CHARACTER COORDINATES NOT CHANGING
; /////////////////////////////////////////////////////////////////////////////////

   ld h,(ix+15)
   ld l,(ix+16)
   push de
   exx
   pop de
   ld hl,(SP1V_UPDATELISTT)
   ld bc,6
   add hl,bc
   push hl
   call asm_sp1_GetUpdateStruct
   ld b,(ix+0)
   pop de
   push hl
   push de

   ; b  = row coord
   ; c  = col coord (in column loop)
   ; hl = struct sp1_update
   ; hl'= & struct sp1_cs
   ; a' = bit 0 = 1 if last row should not draw, bit 1 = 1 if last col should not draw
   ; iy = & clipping rectangle
   ; ix = & struct sp1_ss
   ; stack = & struct sp1_update.ulist (tail of invalidated list), row

;   INCLUDE "temp/sp1/zx/sprites/__sp1_move_nc.asm"
; -- included file here, it's the only included instance

NCrowloop:

   ld a,b
   inc b                     ; row++
   
   ; is row in clipping rectangle?
   
   sub (iy+0)
   jp c, NCcliprow0
   sub (iy+3)
   jp nc, NCcliprow0
   
   ; is this the last row?
   
   ; ****************************************************************
   ; **** FIXED BUG HERE MESSED UP REGISTER ALLOCATION, IMPROVE LATER
   ld a,b
   sub (ix+0)
   cp (ix+3)
   jp nz, NCnotlastrow
   ; ****************************************************************
   
   ; this is the last row, should it be drawn?
   
   ex af,af
   bit 0,a
   jp nz, NCcliprow1
   ex af,af

NCnotlastrow:

   ld c,(ix+1)               ; c = column

NCcolloop:

   ld a,c
   inc c                     ; column++

   ; has this update struct been removed from the display?
   
   bit 6,(hl)
   ex (sp),hl
   jr nz, NCclipcol0

   ; hl = & struct sp1_update.ulist (tail)
   ; stack = & struct sp1_update, row

   ; is column in clipping rectangle?
   
   sub (iy+1)
   jr c, NCclipcol0
   sub (iy+2)
   jr nc, NCclipcol0
   
   ; is this the last column in row?

   ; ****************************************************************
   ; **** FIXED BUG HERE MESSED UP REGISTER ALLOCATION, IMPROVE LATER
   ld a,c
   sub (ix+1)
   cp (ix+2)
   jp nz, NCnotlastcol       ; z flag set if it is the last column in row
   ; ****************************************************************
   
   ; this is the last col, should it be drawn?
   
   ex af,af
   bit 1,a
   jr nz, NCclipcol1
   ex af,af

NCnotlastcol:

   exx
   push af
   inc (ix+19)               ; number of active sprite chars++

   ; hl = & struct sp1_cs
   ; stack = flag = z if last col, & struct sp1_update, row
   
   ; is sprite char already in update struct list?
   
   ld d,(hl)
   inc hl
   ld e,(hl)                 ; de = & next struct sp1_cs in sprite
   inc hl                    ; hl = & struct sp1_cs.update
   
   ld a,(hl)                 ; if MSB of update struct this spr char is != 0
   or a                      ;   then already in list
   jr z, NCaddit

   ; already in update struct list so no need to add spr char to update struct list

   ; de = & next struct sp1_cs in sprite
   ; hl = & struct sp1_cs.update
   ; stack = flag = z if last col, & struct sp1_update, row
   
   pop bc
   pop hl

NCrejoinaddit:

   ; de = & next struct sp1_cs
   ; hl = & struct sp1_update
   ;  c = bit 6 set if last col
   ; stack = row

   ; invalidate
   
   ld a,(hl)                 ; skip if char already invalidated
   xor $80
   jp p, NCalreadyinv0
   ld (hl),a                 ; mark as invalidated
   
   push hl
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

NCalreadyinv0:

   bit 6,c                   ; is this last col?
   jr nz, NCnextrow

NCnextcol:

   ; this is not the last column in row
   
   ; hl = & struct sp1_update
   ; de = & next struct sp1_cs
   ; stack = row
   
   ld bc,10
   add hl,bc
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs
   exx
   ex (sp),hl

   jp NCcolloop

NCclipcol1:

   ex af,af

NCclipcol0:

   exx
   
   ; hl = & struct sp1_cs
   ; stack = & struct sp1_update, row
   
   ld d,(hl)
   inc hl
   ld e,(hl)                 ; de = & next struct sp1_cs in sprite
   inc hl
   
   ; is this spr char on the display now?
   
   ld a,(hl)
   or a
   jr nz, NCremoveit
   
   ; ok, not on display
   
   inc hl
   inc hl
   inc hl                    ; hl = & struct sp1_cs.type

NCrejoinremove:

   ; is this the last col in row?
   
   bit 6,(hl)
   pop hl                    ; hl = & struct sp1_update
   jr z, NCnextcol

NCnextrow:

   ; this was last column, move to next row

   ; de = & next struct sp1_cs
   ; hl = & struct sp1_update
   ; stack = row

   pop hl

   ld a,d                    ; all done if there is no next sp1_cs
   or a
   jp z, done

   ld bc,10*SP1V_DISPWIDTH
   add hl,bc
   push hl
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs
   exx
   ex (sp),hl

   jp NCrowloop

NCaddit:

   ; add the sprite char to update struct's sprite list

   ; de = & next struct sp1_cs in sprite
   ; hl = & struct sp1_cs.update
   ; stack = flag = z if last col, & struct sp1_update, row

   pop af                    ; f = flag
   ld b,d
   ld c,e                    ; bc = & next struct sp1_cs in update
   pop de                    ; de = & struct sp1_update
   push de
   push af
   ld (hl),d
   inc hl
   ld (hl),e                 ; write struct update this spr char belongs to
   inc hl
   ld a,(hl)                 ; a = plane
   inc hl
   
   bit 7,(hl)                ; is spr char occluding type?
   jp z, NCnotoccluding10
   ex de,hl
   inc (hl)                  ; increase # occluding sprites in update struct
   ex de,hl

NCnotoccluding10:

   inc hl
   push bc
   ld b,h
   ld c,l                    ; bc = & struct sp1_cs.attr_mask
   ld hl,4
   add hl,de                 ; hl = & struct sp1_update.slist
   call __sp1_add_spr_char   ; add sprite to update list
   pop de
   pop bc
   pop hl

   ; de = & next struct sp1_cs
   ; hl = & struct sp1_update
   ;  c = bit 6 set if last col
   ; stack = row

   jp NCrejoinaddit

NCremoveit:

   ; need to remove this spr char from update list

   ; de = & next struct sp1_cs in sprite
   ; hl = & struct sp1_cs.update
   ; stack = & struct sp1_update, row

   push de
   ld (hl),0                 ; this spr char no longer belongs to update struct
   inc hl
   inc hl
   inc hl
   push hl
   inc hl                    ; hl = & struct sp1_cs.attr_mask
   call __sp1_remove_spr_char
   pop hl                    ; hl = & struct sp1_cs.type
   pop de                    ; de = & next struct sp1_cs
   
   ; invalidate so char is redrawn without sprite
   
   pop bc                    ; bc = & struct sp1_update
   push bc

   ld a,(bc)
   bit 7,(hl)                ; is spr char occluding type?
   jp z, NCnotoccluding0
   dec a                     ; number of occluding sprites in update struct --
   ld (bc),a

NCnotoccluding0:

   xor $80                   ; is char already invalidated?
   jp p, NCrejoinremove      ; if so skip invalidation step
   ld (bc),a                 ; mark as invalidated
   
   push bc
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

   jp NCrejoinremove

NCcliprow1:

   ex af,af

NCcliprow0:

   ; skipping an entire row, only need to remove
   ; spr chars from update struct list + invalidate
   ; if they are on-screen

   ex (sp),hl
   exx

NCcliprowlp:

   ; hl = & struct sp1_cs
   ; stack = & struct sp1_update, row
   
   ld d,(hl)
   inc hl
   ld e,(hl)                 ; de = & next struct sp1_cs in sprite
   inc hl
   
   ; is this spr char on the display now?
   
   ld a,(hl)
   or a
   jr nz, NCCRremoveit
   
   ; ok, not on display
   
   inc hl
   inc hl
   inc hl                    ; hl = & struct sp1_cs.type

NCCRrejoinremove:

   ; is this the last col in row?
   
   bit 6,(hl)
   pop hl                    ; hl = & struct sp1_update
   jr nz, NCCRnextrow

   ; this is not the last column in row
   
   ; hl = & struct sp1_update
   ; de = & next struct sp1_cs
   ; stack = row
   
   ld bc,10
   add hl,bc
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs

   jp NCcliprowlp

NCCRnextrow:

   ; this was last column, move to next row

   ; de = & next struct sp1_cs
   ; hl = & struct sp1_update
   ; stack = row

   pop hl

   ld a,d                    ; all done if there is no next sp1_cs
   or a
   jp z, done

   ld bc,10*SP1V_DISPWIDTH
   add hl,bc
   push hl
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs
   exx
   ex (sp),hl

   jp NCrowloop

NCCRremoveit:

   ; need to remove this spr char from update list

   ; de = & next struct sp1_cs in sprite
   ; hl = & struct sp1_cs.update
   ; stack = & struct sp1_update, row

   push de
   ld (hl),0                 ; spr char no longer belongs to update struct
   inc hl
   inc hl
   inc hl
   push hl
   inc hl                    ; hl = & struct sp1_cs.attr_mask
   call __sp1_remove_spr_char
   pop hl                    ; hl = & struct sp1_cs.type
   pop de                    ; de = & next struct sp1_cs
   
   ; invalidate so char is redrawn without sprite
   
   pop bc                    ; bc = & struct sp1_update
   push bc

   ld a,(bc)
   bit 7,(hl)                ; is spr char occluding type?
   jp z, NCCRnotoccluding0
   dec a                     ; number of occluding sprites in update struct --
   ld (bc),a

NCCRnotoccluding0:

   xor $80                   ; is char already invalidated?
   jp p, NCCRrejoinremove    ; if so skip invalidation step
   ld (bc),a                 ; mark as invalidated
   
   push bc
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

   jp NCCRrejoinremove

; -- end of included file

.done

   exx
   ld de,-6
   add hl,de                 ; hl = & last struct sp1_update.ulist in invalidated list
   ld (SP1V_UPDATELISTT),hl
   ret

; changing character coordinate, must remove and place sprite in update struct lists

; /////////////////////////////////////////////////////////////////////////////////
;               MOVE SPRITE, CHANGING CHARACTER COORDINATES
; /////////////////////////////////////////////////////////////////////////////////

.changing0

   ld (ix+0),d             ; write new row coord

.changing1

   ld (ix+1),e             ; write new col coord

   ;  d = new row coord (chars)
   ;  e = new col coord (chars)
   ; ix = & struct sp1_ss
   ; iy = & clipping rectangle
   ; a' = bit 0 = 1 if last row should not draw, bit 1 = 1 if last col should not draw

   ld h,(ix+15)
   ld l,(ix+16)
   push de
   exx
   pop de
   ld hl,(SP1V_UPDATELISTT)
   ld bc,6
   add hl,bc
   push hl
   call asm_sp1_GetUpdateStruct
   ld b,(ix+0)
   pop de
   push hl
   push de

   ; b  = row coord
   ; c  = col coord (in column loop)
   ; hl = struct sp1_update
   ; hl'= & struct sp1_cs
   ; a' = bit 0 = 1 if last row should not draw, bit 1 = 1 if last col should not draw
   ; iy = & clipping rectangle
   ; ix = & struct sp1_ss
   ; stack = & struct sp1_update.ulist (tail of invalidated list), row

;   INCLUDE "temp/sp1/zx/sprites/__sp1_move_c.asm"
; -- include file pasted here, it's the inly instance

CCrowloop:

   ld a,b
   inc b                     ; row++
   
   ; is row in clipping rectangle?
   
   sub (iy+0)
   jp c, CCcliprow0
   sub (iy+3)
   jp nc, CCcliprow0
   
   ; is this the last row?
   
   ; ****************************************************************
   ; **** FIXED BUG HERE MESSED UP REGISTER ALLOCATION, IMPROVE LATER
   ld a,b
   sub (ix+0)
   cp (ix+3)
   jp nz, CCnotlastrow
   ; ****************************************************************
   
   ; this is the last row, should it be drawn?
   
   ex af,af
   bit 0,a
   jp nz, CCcliprow1
   ex af,af
   
CCnotlastrow:

   ld c,(ix+1)               ; c = column

CCcolloop:

   ld a,c
   inc c                     ; column++
   
   ; has this update struct been removed from the display?

   bit 6,(hl)
   ex (sp),hl
   jp nz, CCclipcol0
   
   ; hl = & struct sp1_update.ulist (tail)
   ; stack = & struct sp1_update, row

   ; is column in clipping rectangle?

   sub (iy+1)
   jp c, CCclipcol0
   sub (iy+2)
   jp nc, CCclipcol0
   
   ; is this the last column in row?

   ; ****************************************************************
   ; **** FIXED BUG HERE MESSED UP REGISTER ALLOCATION, IMPROVE LATER
   ld a,c
   sub (ix+1)
   cp (ix+2)
   jp nz, CCnotlastcol       ; z flag set if it is the last column in row
   ; ****************************************************************
   
   ; this is the last column, should it be drawn?
   
   ex af,af
   bit 1,a
   jp nz, CCclipcol1
   ex af,af

CCnotlastcol:

   exx
   inc (ix+19)               ; number of active spr chars++
   
   ; hl = & struct sp1_cs
   ; stack = & struct sp1_update, row

   ld b,(hl)
   inc hl
   ld c,(hl)                 ; bc = & next struct sp1_cs in sprite
   inc hl
   
   ld a,(hl)
   or a
   jp z, CCnoremovenec0
   
   ; first remove spr char from current update struct
   
   push bc
   push hl                   ; stack = sp1_cs.update, next sp1_cs, sp1_update, row
   ld bc,4
   add hl,bc                 ; hl = & struct sp1_cs.attr_mask
   call __sp1_remove_spr_char
   pop de
   pop hl
   ex (sp),hl
   ex de,hl
   
   ; hl = & struct sp1_cs.update
   ; de = & struct sp1_update
   ; stack = & next struct sp1_cs, row
   
   ; change update struct spr char belongs to
   
   ld b,(hl)
   inc hl
   ld c,(hl)                 ; bc = old struct sp1_update
   ld (hl),e
   dec hl
   ld (hl),d                 ; store new struct sp1_update
   
   ; do count for occluding sprites
   
   inc hl
   inc hl
   inc hl                    ; hl = & struct sp1_cs.type
   bit 7,(hl)                ; is this occluding type?
   jp z, CCnotoccl0
   ld a,(bc)
   dec a
   ld (bc),a                 ; decrease num of occl sprites in old update struct
   ld a,(de)
   inc a
   ld (de),a                 ; increase num of occl sprites in new update struct

CCnotoccl0:

   ; invalidate update chars

   ld a,(de)
   xor $80
   jp p, CCnoinvnew          ; new update struct already invalidated so skip
   ld (de),a                 ; mark it as invalidated now

   push de
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

CCnoinvnew:

   ld a,(bc)
   xor $80
   jp p, CCnoinvold          ; old update struct already invalidated so skip
   ld (bc),a                 ; mark it as invalidated now
   
   push bc
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

CCnoinvold:

   ; hl = & struct sp1_cs.type
   ; de = & struct sp1_update
   ; stack = & next struct sp1_cs, row

   ; now add spr char to new update struct it occupies
   
   dec hl
   ld a,(hl)                 ; a = plane
   inc hl
   ld c,(hl)
   push bc                   ; save type
   inc hl
   ld b,h
   ld c,l                    ; bc = & struct sp1_cs.attr_mask
   ld hl,4
   add hl,de                 ; hl = & struct sp1_update.slist
   push de                   ; save sp1_update
   call __sp1_add_spr_char
   pop hl
   pop af
   pop de
   
   ; hl = & struct sp1_update
   ; de = & next struct sp1_cs
   ;  f = z flag set if last col in row
   ; stack = row
   
   jr z, CCnextrow
   
   ld bc,10
   add hl,bc
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs
   exx
   ex (sp),hl
   
   jp CCcolloop
   
CCnextrow:

   ; hl = & struct sp1_update
   ; de = & next struct sp1_cs
   ; stack = row

   pop hl                    ; hl = & struct sp1_update at start of row

   ld a,d                    ; all done if there is no next sp1_cs
   or a
   jp z, done

   ld bc,10*SP1V_DISPWIDTH
   add hl,bc
   push hl
   push hl
   ex de,hl
   exx
   ex (sp),hl
   
   jp CCrowloop

CCnoremovenec0:

   ; hl = & struct sp1_cs.update
   ; bc = & next struct sp1_cs in sprite
   ; stack = & struct sp1_update, row

   pop de                    ; de = & struct sp1_update
   ld (hl),d
   inc hl
   ld (hl),e                 ; store update struct the spr char occupies now
   inc hl
   inc hl                    ; hl = & struct sp1_cs.type
   
   ld a,(de)
   bit 7,(hl)                ; is spr char occluding?
   jp z, CCnotoccl12
   inc a                     ; increase # occluding sprites in update struct
   ld (de),a
   
CCnotoccl12:

   ; invalidate the update struct
   
   xor $80
   jp p, CCalreadyinv33      ; skip if already invalidated
   ld (de),a                 ; mark it as invalidated
   
   push de
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

CCalreadyinv33:

   push bc
   
   ; hl = & struct sp1_cs.type
   ; de = & struct sp1_update
   ; stack = & next struct sp1_cs, row

   jp CCnoinvold             ; add spr char to update list, loop

CCclipcol1:

   ex af,af
   
CCclipcol0:

   exx
   
   ; hl = & struct sp1_cs
   ; stack = & struct sp1_update, row
   
   ld d,(hl)
   inc hl
   ld e,(hl)                 ; de = & next struct sp1_cs in sprite
   inc hl
   
   ; is this spr char on the display now?
   
   ld a,(hl)
   or a
   jr z, CCskipremoveit

   ld b,a
   inc hl
   ld c,(hl)

   ; need to remove this spr char from update list

   ; de = & next struct sp1_cs in sprite
   ; hl = & struct sp1_cs.update + 1
   ; bc = & old struct sp1_update
   ; stack = & struct sp1_update, row

   push bc
   push de
   dec hl
   ld (hl),0                 ; this spr char no longer belongs to update struct
   inc hl
   inc hl
   inc hl
   push hl
   inc hl                    ; hl = & struct sp1_cs.attr_mask
   call __sp1_remove_spr_char
   pop hl                    ; hl = & struct sp1_cs.type
   pop de                    ; de = & next struct sp1_cs
   pop bc                    ; bc = & old struct sp1_update
   
   ; invalidate so char is redrawn without sprite

   ld a,(bc)
   bit 7,(hl)                ; is spr char occluding type?
   jp z, CCnotoccl44
   dec a                     ; number of occluding sprites in old update struct --
   ld (bc),a

CCnotoccl44:

   xor $80                   ; is char already invalidated?
   jp p, CCalreadyinv66      ; if so skip invalidation step
   ld (bc),a                 ; mark as invalidated
   
   push bc
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

CCalreadyinv66:

   ; hl = & struct sp1_cs.type
   ; de = & next struct sp1_cs
   ; stack = & struct sp1_update, row
   
   pop bc
   bit 6,(hl)                ; last column in row?
   jp nz, CCnextrow

   ; this is not the last column
   
   ld hl,10
   add hl,bc
   push hl
   ex de,hl
   exx
   ex (sp),hl
   
   jp CCcolloop

CCskipremoveit:

   ; hl = & struct sp1_cs.update
   ; de = & next struct sp1_cs in sprite
   ; stack = & struct sp1_update, row

   inc hl
   inc hl
   inc hl
   
   jp CCalreadyinv66

CCcliprow1:

   ex af,af

CCcliprow0:

   ; skipping an entire row, only need to remove
   ; spr chars from update struct list + invalidate
   ; if they are on-screen

   ex (sp),hl
   exx

CCcliprowlp:
   
   ; hl = & struct sp1_cs
   ; stack = & struct sp1_update, row

   ld d,(hl)
   inc hl
   ld e,(hl)                 ; de = & next struct sp1_cs in sprite
   inc hl
   
   ; is this spr char on the display now?
   
   ld a,(hl)
   or a
   jr nz, CCCRremoveit
   
   ; ok, not on display
   
   inc hl
   inc hl
   inc hl                    ; hl = & struct sp1_cs.type

CCCRrejoinremove:

   ; is this the last col in row?
   
   bit 6,(hl)
   pop hl                    ; hl = & struct sp1_update
   jr nz, CCCRnextrow

   ; this is not the last column in row
   
   ; hl = & struct sp1_update
   ; de = & next struct sp1_cs
   ; stack = row
   
   ld bc,10
   add hl,bc
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs

   jp CCcliprowlp

CCCRnextrow:

   ; this was last column, move to next row

   ; de = & next struct sp1_cs
   ; hl = & struct sp1_update
   ; stack = row

   pop hl

   ld a,d                    ; all done if there is no next sp1_cs
   or a
   jp z, done

   ld bc,10*SP1V_DISPWIDTH
   add hl,bc
   push hl
   push hl
   ex de,hl                  ; hl = & next struct sp1_cs
   exx
   ex (sp),hl

   jp CCrowloop

CCCRremoveit:

   ; need to remove this spr char from update list

   ld b,a
   inc hl
   ld c,(hl)
   
   ; de = & next struct sp1_cs in sprite
   ; hl = & struct sp1_cs.update + 1
   ; bc = & old struct sp1_update
   ; stack = & struct sp1_update, row

   push bc
   push de
   dec hl
   ld (hl),0                 ; spr char no longer belongs to update struct
   inc hl
   inc hl
   inc hl
   push hl
   inc hl                    ; hl = & struct sp1_cs.attr_mask
   call __sp1_remove_spr_char
   pop hl                    ; hl = & struct sp1_cs.type
   pop de                    ; de = & next struct sp1_cs
   pop bc                    ; bc = & old struct sp1_update
   
   ; invalidate so char is redrawn without sprite

   ld a,(bc)
   bit 7,(hl)                ; is spr char occluding type?
   jp z, CCCRnotoccluding0
   dec a                     ; number of occluding sprites in update struct --
   ld (bc),a

CCCRnotoccluding0:

   xor $80                   ; is char already invalidated?
   jp p, CCCRrejoinremove    ; if so skip invalidation step
   ld (bc),a                 ; mark as invalidated
   
   push bc
   exx
   pop de                    ; de = & struct sp1_update to invalidate
   ld (hl),d                 ; write & struct sp1_update into tail's ptr
   inc hl
   ld (hl),e
   ld hl,6
   add hl,de                 ; hl = & struct sp1_update.ulist
   ld (hl),0                 ; nothing after this one in list
   exx

   jp CCCRrejoinremove

; -- enf of pasted file
   ; jumps to done for exit inside INCLUDE
