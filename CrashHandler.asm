
; ---------------------------
; Super Metroid Crash Handler
; ---------------------------

lorom

; Configure stuff here

!EXTRA_PAGES = 0 ; Set to 1 if you plan on customizing the extra pages

!CRASHDUMP = $7FFC00 ; at least 40h bytes
!ram_tilemap_buffer = $7E5800 ; 800h bytes


; Macros

macro a8() ; A = 8-bit
    SEP #$20
endmacro

macro a16() ; A = 16-bit
    REP #$20
endmacro

macro i8() ; X/Y = 8-bit
    SEP #$10
endmacro

macro i16() ; X/Y = 16-bit
    REP #$10
endmacro

macro ai8() ; A + X/Y = 8-bit
    SEP #$30
endmacro

macro ai16() ; A + X/Y = 16-bit
    REP #$30
endmacro


; These bridge routines must live in bank $85
org $85FFF0
print pc, " crash bank85 start"
wait_for_lag_frame_long:
    JSR $8136
    RTL

initialize_ppu_long:
    JSR $8143
    RTL

restore_ppu_long:
    JSR $861A
    RTL

play_music_long:
    JSR $8574
    RTL

print pc, " crash bank85 end"


; Hijack generic crash handler
org $008573
    JML CrashHandler

; Hijack native BRK vector
org $00FFE6
    dw BRKHandler

; Hijack emulation IRQ/BRK vector
org $00FFFE
    dw BRKHandler


org $80E000
print pc, " crash handler bank80 start"
CrashHandler:
{
    PHP : PHB
    PHB : PLB
    %ai16()

    ; store CPU registers
    STA !CRASHDUMP+$00        ; A
    TXA : STA !CRASHDUMP+$02  ; X
    TYA : STA !CRASHDUMP+$04  ; Y
    PLA : STA !CRASHDUMP+$06  ; DB + P
    TSC : STA !CRASHDUMP+$08  ; SP

    ; loop: stack -> SRAM
    INC : TAY : LDX #$0000
  .loopStack
    LDA $0000,Y : STA !CRASHDUMP+$10,X
    INX #2 : CPX #$0030 : BPL .maxStack ; max 30h bytes
    INY #2 : CPY #$2000 : BMI .loopStack
    BRA .stackSize

  .maxStack
    ; we only saved 30h bytes, so inc until we
    ; know the total number of bytes on the stack
    INY : INX : CPY #$2000 : BMI .maxStack

  .stackSize
    ; check if we copied an extra byte
    CPY #$2000 : BEQ +
    DEX ; don't count it
+   TXA : STA !CRASHDUMP+$0A

    ; launch crashdump viewer
    LDA #$0004 : STA $AB ; set IRQ to HUD drawing
    JSL CrashViewer

  .crash
    JML .crash
}

BRKHandler:
{
    JML .setBank
  .setBank
    PHP : PHB
    PHK : PLB
    %ai16()

    ; store CPU registers
    STA !CRASHDUMP+$00        ; A
    TXA : STA !CRASHDUMP+$02  ; X
    TYA : STA !CRASHDUMP+$04  ; Y
    PLA : STA !CRASHDUMP+$06  ; DB + P
    TSC : STA !CRASHDUMP+$08  ; SP

    ; prep for .loopStack
    INC : TAY : LDX #$0000

    ; store crash type, 1 = BRK
    LDA #$0001 : STA !CRASHDUMP+$0C

    JMP CrashHandler_loopStack
}

crash_cgram_transfer_long:
{
    PHP
    %a16() : %i8()
    JSR $933A ; bank $80
    PLP
    RTL
}

EndofBank80:

print pc, " crash handler bank80 end"


; The rest of this can live anywhere
; but it should probably stay together
org EndofBank80
print pc, " crash dump viewer start"
CrashViewer:
{
    ; setup to draw crashdump on layer 3
    PHK : PLB
    %a8()
    STZ $420C
    LDA #$80 : STA $2100
    LDA #$A1 : STA $4200
    LDA #$09 : STA $2105
    LDA #$0F : STA $2100
    %a16()

    LDA #$0000
    STA $8F : STA $8B
    STA $C9 : STA $CB

    JSL initialize_ppu_long   ; Initialise PPU for message boxes

    JSL crash_cgram_transfer
    JSL crash_tileset_transfer
    JSL play_music_long ; Play 2 lag frames of music and sound effects

    JSL CrashLoop
}

CrashLoop:
{
    %ai16()
 	; Clear out !ram_tilemap_buffer
    LDA #$000E : LDX #$07FE
-   STA !ram_tilemap_buffer,X : DEX #2 : BPL -

if !EXTRA_PAGES
    ; Determine which page to draw
    LDA $C9 : ASL : TAX
    JSR (CrashDumpPageTable,X)
else
    JSR CrashMainPage
endif

    ; -- Transfer to VRAM --
    JSL crash_tilemap_transfer

    ; handle input loop stuff
    JSL wait_for_lag_frame_long ; Wait for lag frame
    JSL $808F0C ; Music queue
    JSL $8289EF ; Sound fx queue
    JSL $809459 ; Read controller input

    ; new inputs in X, to be copied back to A later
    LDA $8F : TAX : BEQ CrashLoop

    ; check for soft reset shortcut (Select+Start+L+R)
    LDA $8B : AND #$3030 : CMP #$3030 : BNE .check_inputs
    AND $8F : BNE .reset

  .check_inputs
if !EXTRA_PAGES
    TXA : AND #$5190 : BNE .next       ; A + Y + Right + Start
    TXA : AND #$A260 : BNE .previous   ; B + X + Left + Select
endif
    TXA : AND #$0810 : BNE .incPalette ; Up + R
    TXA : AND #$0420 : BNE .decPalette ; Down + L
    JMP CrashLoop

if !EXTRA_PAGES
  .previous
    LDA $C9 : BNE +
    LDA #$0003 : STA $C9 ; total pages
+   DEC $C9
    JMP CrashLoop

  .next
    LDA $C9 : CMP #$0002 : BMI +
    LDA #$FFFF : STA $C9
+   INC $C9
    JMP CrashLoop
endif

  .decPalette
    LDA $CB : BNE +
    LDA #$0004 : STA $CB ; total palettes
+   DEC $CB
    JSL crash_cgram_transfer
    JMP CrashLoop

  .incPalette
    LDA $CB : CMP #$0003 : BMI +
    LDA #$FFFF : STA $CB
+   INC $CB
    JSL crash_cgram_transfer
    JMP CrashLoop

  .reset
    STZ $05F5   ; Enable sounds
    JML $808462 ; Soft Reset
}

if !EXTRA_PAGES
CrashDumpPageTable:
    dw CrashMainPage
    dw CrashMainPage2
    dw CrashMainPage3
endif

CrashMainPage:
{
    ; $00[0x3] = Table Address (Long)
    ; $C1[0x2] = Value to be Drawn
    ; $C3[0x2] = Line Loop Counter
    ; $C5[0x2] = Stack Bytes Written
    ; $C7[0x2] = Stack Bytes to be Written
    ; $C9[0x2] = Page Index
    ; $CB[0x2] = Palette Index

    ; -- Draw header --
    LDA.l #CrashTextHeader : STA $00
    LDA.l #CrashTextHeader>>16 : STA $02
    LDX #$0086 : JSR crash_draw_text

    ; -- Draw footer message --
    LDA.l #CrashTextFooter1 : STA $00
    LDA.l #CrashTextFooter1>>16 : STA $02
    LDX #$0646 : JSR crash_draw_text

    LDA.l #CrashTextFooter2 : STA $00
    LDA.l #CrashTextFooter2>>16 : STA $02
    LDX #$0686 : JSR crash_draw_text

    ; -- Draw register labels --
    LDA #$2800 : STA !ram_tilemap_buffer+$14A  ; A
    LDA #$2817 : STA !ram_tilemap_buffer+$154  ; X
    LDA #$2818 : STA !ram_tilemap_buffer+$15E  ; Y
    LDA #$2803 : STA !ram_tilemap_buffer+$166  ; D
    LDA #$2801 : STA !ram_tilemap_buffer+$168  ; B
    LDA #$284F : STA !ram_tilemap_buffer+$16A  ; +
    LDA #$280F : STA !ram_tilemap_buffer+$16C  ; P
    LDA #$2812 : STA !ram_tilemap_buffer+$172  ; S
    LDA #$280F : STA !ram_tilemap_buffer+$174  ; P

    ; -- Draw stack label --
    LDA.l #CrashTextStack1 : STA $00
    LDA.l #CrashTextStack1>>16 : STA $02
    LDX #$0246 : JSR crash_draw_text

    ; -- Draw stack text --
    LDA.l #CrashTextStack2 : STA $00
    LDA.l #CrashTextStack2>>16 : STA $02
    LDX #$0286 : JSR crash_draw_text

    ; -- Draw register values --
    LDA !CRASHDUMP : STA $C1 : LDX #$0188
    JSR crash_draw4  ; A
    LDA !CRASHDUMP+$02 : STA $C1 : LDX #$0192
    JSR crash_draw4  ; X
    LDA !CRASHDUMP+$04 : STA $C1 : LDX #$019C
    JSR crash_draw4  ; Y
    LDA !CRASHDUMP+$06 : XBA : STA $C1 : LDX #$01A6
    JSR crash_draw4  ; DB+P
    LDA !CRASHDUMP+$08 : STA $C1 : LDX #$01B0
    JSR crash_draw4  ; SP

    ; -- Draw starting position of stack dump
    INC $C1 : LDX #$02A8
    JSR crash_draw4

    ; -- Draw stack bytes written --
    LDA !CRASHDUMP+$0A
    STA $C1 : STA $C5 : STA $C7
    LDX #$025E
    JSR crash_draw4

    ; -- Detect and Draw BRK --
    LDA !CRASHDUMP+$0C : BEQ +
    %a8()
    LDA !CRASHDUMP+$10 : STA $C1
    LDX #$031C : JSR crash_draw2 ; P

    LDA !CRASHDUMP+$13 : STA $C1
    LDX #$0324 : JSR crash_draw2 ; bank

    %a16()
    LDA !CRASHDUMP+$11 : DEC #2 : STA $C1
    LDX #$0328 : JSR crash_draw4 ; addr

    LDA #$2C51 : STA !ram_tilemap_buffer+$310 ; B
    LDA #$2C61 : STA !ram_tilemap_buffer+$312 ; R
    LDA #$2C5A : STA !ram_tilemap_buffer+$314 ; K
    LDA #$2C4A : STA !ram_tilemap_buffer+$316 ; :
    LDA #$2C4E : STA !ram_tilemap_buffer+$322 ; $

    ; -- Draw Stack Values --
    ; start by setting up tilemap position
+   %ai16()
    LDX #$0388
    LDA #$0000 : STA $C3

    ; determine starting offset
-   LDA $C5 : AND #$0007 : BEQ +
    TXA : CLC : ADC #$0006 : TAX
    INC $C5 : INC $C3 : BRA -

+   %a8()
    LDA #$00 : STA $C5

  .drawStack
    ; draw a byte
    PHX : %i8()
    LDA $C5 : TAX
    LDA !CRASHDUMP+$10,X : STA $C1
    %i16() : PLX
    JSR crash_draw2

    ; inc tilemap position
    INX #6 : INC $C3
    LDA $C3 : AND #$08 : BEQ +

    ; start a new line
    LDA #$00 : STA $C3
    %a16()
    TXA : CLC : ADC #$0050 : TAX
    CPX #$05B4 : BPL .done
    %a8()

    ; inc bytes drawn
+   LDA $C5 : INC : STA $C5
    CMP $C7 : BNE .drawStack

  .done
    %ai16()
    RTS
}

if !EXTRA_PAGES
CrashMainPage2:
; test dummies
{
    ; -- Draw header --
    LDA.l #CrashTextHeader : STA $00
    LDA.l #CrashTextHeader>>16 : STA $02
    LDX #$00C6 : JSR crash_draw_text

    LDA.l #CrashTextPlaceholder1 : STA $00
    LDA.l #CrashTextPlaceholder1>>16 : STA $02
    LDX #$0388 : JSR crash_draw_text

    ; -- Draw footer message --
    LDA.l #CrashTextFooter1 : STA $00
    LDA.l #CrashTextFooter1>>16 : STA $02
    LDX #$0606 : JSR crash_draw_text

    LDA.l #CrashTextFooter2 : STA $00
    LDA.l #CrashTextFooter2>>16 : STA $02
    LDX #$0646 : JSR crash_draw_text

    RTS
}

CrashMainPage3:
; test dummies
{
    ; -- Draw header --
    LDA.l #CrashTextHeader : STA $00
    LDA.l #CrashTextHeader>>16 : STA $02
    LDX #$00C6 : JSR crash_draw_text

    LDA.l #CrashTextPlaceholder2 : STA $00
    LDA.l #CrashTextPlaceholder2>>16 : STA $02
    LDX #$0388 : JSR crash_draw_text

    ; -- Draw footer message --
    LDA.l #CrashTextFooter3 : STA $00
    LDA.l #CrashTextFooter3>>16 : STA $02
    LDX #$0606 : JSR crash_draw_text

    LDA.l #CrashTextFooter4 : STA $00
    LDA.l #CrashTextFooter4>>16 : STA $02
    LDX #$0646 : JSR crash_draw_text

    RTS
}
endif

crash_draw_text:
{
    ; X = pointer to tilemap area (position on screen)
    ; $00[0x3] = long address of text
    %a8()
    LDY #$0000
    ; terminator
    LDA [$00],Y : INY : CMP #$FF : BEQ .end
    ; palette
    STA $0E

  .loop
    LDA [$00],Y : CMP #$FF : BEQ .end           ; terminator
    STA !ram_tilemap_buffer,X : INX             ; tile
    LDA $0E : STA !ram_tilemap_buffer,X : INX   ; palette
    INY : BRA .loop

  .end
    %a16()
    RTS
}

crash_draw4:
{
    ; (X000)
    LDA $C1 : AND #$F000 : XBA : LSR #3 : TAY
    LDA.w CrashHexTable,Y : STA !ram_tilemap_buffer,X
    ; (0X00)
    LDA $C1 : AND #$0F00 : XBA : ASL : TAY
    LDA.w CrashHexTable,Y : STA !ram_tilemap_buffer+2,X
    ; (00X0)
    LDA $C1 : AND #$00F0 : LSR #3 : TAY
    LDA.w CrashHexTable,Y : STA !ram_tilemap_buffer+4,X
    ; (000X)
    LDA $C1 : AND #$000F : ASL : TAY
    LDA.w CrashHexTable,Y : STA !ram_tilemap_buffer+6,X
    RTS
}

crash_draw2:
{
    PHP : %a16()
    ; (00X0)
    LDA $C1 : AND #$00F0 : LSR #3 : TAY
    LDA.w CrashHexTable,Y : STA !ram_tilemap_buffer,X
    ; (000X)
    LDA $C1 : AND #$000F : ASL : TAY
    LDA.w CrashHexTable,Y : STA !ram_tilemap_buffer+2,X
    PLP
    RTS
}

CrashHexTable:
    dw $2C70, $2C71, $2C72, $2C73, $2C74, $2C75, $2C76, $2C77
    dw $2C78, $2C79, $2C50, $2C51, $2C52, $2C53, $2C54, $2C55

crash_tilemap_transfer:
{
    JSL wait_for_lag_frame_long ; Wait for lag frame

    %a16()
    LDA #$5800 : STA $2116
    LDA #$1801 : STA $4310
    LDA.w #!ram_tilemap_buffer : STA $4312
    LDA.w #!ram_tilemap_buffer>>16 : STA $4314
    LDA #$0800 : STA $4315
    STZ $4317 : STZ $4319
    %a8()
    LDA #$80 : STA $2115
    LDA #$02 : STA $420B
    JSL $808F0C ; Handle music queue
    JSL $8289EF ; Handle sounds
    %a16()
    RTL
}

crash_cgram_transfer:
{
    PHP : %a16()

    LDA $CB : BEQ .white
    DEC : BEQ .grey
    DEC : BEQ .green
    DEC : BEQ .blue

  .white
    LDA #$44E5 : STA $7EC012 ; outline
    LDA #$7FFF : STA $7EC014 ; text
    BRA .transfer

  .grey
    LDA #$1CE7 : STA $7EC012 ; outline
    LDA #$3DEF : STA $7EC014 ; text/numbers
    BRA .transfer

  .green
    LDA #$000E : STA $7EC012 ; outline
    LDA #$0A20 : STA $7EC014 ; text
    BRA .transfer

  .blue
    LDA #$7FFF : STA $7EC012 ; outline
    LDA #$7A02 : STA $7EC014 ; text

  .transfer
    LDA $7EC012 : STA $7EC01A
    LDA $7EC014 : STA $7EC01C

    JSL crash_cgram_transfer_long
    PLP
    PHK : PLB
    RTL
}

crash_tileset_transfer:
{
    ; Load custom tileset into vram
    PHP : %a8()
    LDA #$04 : STA $210C
    LDA #$80 : STA $2115 ; word-access, incr by 1
    LDX #$4000 : STX $2116 ; VRAM address (8000 in vram)
    LDX #crash_gfx_table : STX $4302 ; Source offset
    LDA #crash_gfx_table>>16 : STA $4304 ; Source bank
    LDX #$1000 : STX $4305 ; Size (0x10 = 1 tile)
    LDA #$01 : STA $4300 ; word, normal increment (DMA MODE)
    LDA #$18 : STA $4301 ; destination (VRAM write)
    LDA #$01 : STA $420B ; initiate DMA (channel 1)
    PLP
    RTL
}


; ------------
; Text Strings
; ------------

CrashTextHeader:
    table resources/header.tbl
    db #$28, "SM SHOT ITSELF IN THE FOOT", #$FF
    table resources/normal.tbl

CrashTextStack1:
    db #$28, "    STACK:       Bytes", #$FF

CrashTextStack2:
    db #$28, "   (starting at $    )", #$FF

CrashTextFooter1:
; Navigate pages with <>LRAB
    db #$28, "Navigate pages with ", #$81, #$80, #$8D, #$8C, #$8F, #$87, #$FF

CrashTextFooter2:
; Cycle palettes with ^ or v
    db #$28, "Cycle palettes with ", #$83, " or ", #$82, #$FF

if !EXTRA_PAGES
CrashTextFooter3:
    db #$28, "Super Metroid has crashed!", #$FF

CrashTextFooter4:
    db #$28, "Report this to HACK_AUTHOR", #$FF

CrashTextPlaceholder1:
    table resources/header.tbl
    db #$28, "Page 2: 404 Page not found", #$FF
    table resources/normal.tbl

CrashTextPlaceholder2:
; Page 3: LRSlSt Soft Reset
    db #$28, "Page 3: ", #$8D, #$8E, #$85, #$84, " Soft Reset", #$FF
endif

print pc, " crash dump viewer end"


; --------
; Graphics
; --------

; 1000h bytes of 2bpp graphics (same as HUD)
; Can be placed anywhere in the rom
org $DEF000
print pc, " Crash graphics start"
crash_gfx_table:
    ; 1000h bytes
    incbin resources/crash_gfx.bin
print pc, " Crash graphics end"

