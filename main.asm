.segment "STARTUP"
.segment "INIT"
.segment "ONCE"
.segment "CODE"
jmp start

.data
sines: .incbin "sines.bin"

.code
;-*-*-*-*-*-*-*-*-*-*-*-;
;  A R I T H M E T I C  ;
;         A N D         ;
;T R I G O N O M E T R Y;
;*-*-*-*-*-*-*-*-*-*-*-*;
sintbl = (sines)            ;Trig tables. 256 degrees in a circle.
costbl = (sines + 64)
acc0 = $4                   ;Zeropage accumulator for higher bit arithmetic
acc1 = $5
acc2 = $6
acc3 = $7

;Stores sine of theta in A
.macro sinx theta
    ldx theta
    lda sintbl, x
.endmacro

;Stores cosine of theta in A
.macro cosx theta
    ldx theta
    lda costbl, x
.endmacro

;Adds X to A
;Stores the 16bit result in acc0~1
.macro add_8_16
    clc
    stx acc0
    adc acc0
    sta acc0
    lda #$00
    adc #$00
    sta acc1
.endmacro

;Adds AX to acc0~1
;Stores the 24bit result in acc0~2
;INPUTS:
;A - lo byte
;X - hi byte
.macro add_16_24 
    clc
    adc acc0
    sta acc0
    txa
    adc acc1
    sta acc1
    lda #$00
    adc #$00
    sta acc2
.endmacro

;-*-*-*-*-*-*-*-;
;V E R A V E R A;
;R E G I S T E R;
;    F I L E    ;
;*-*-*-*-*-*-*-*;
vera_l   = $9f20
vera_m   = $9f21
vera_h   = $9f22
vera_d0  = $9f23
vera_d1  = $9f24
vera_ctl = $9f25
vera_ien = $9f26
vera_isr = $9f27
vera_lin = $9f28
;When DCSEL = 0
vera_vcl = $9f29
vera_hsc = $9f2a
vera_vsc = $9f2b
vera_brd = $9f2c
;When DCSEL = 1
vera_scx = $9f29
vera_scw = $9f2a
vera_scy = $9f2b
vera_sch = $9f2c
vera_lc0 = $9f2d
vera_lm0 = $9f2e
vera_lt0 = $9f2f
vera_l0_h0 = $9f30
vera_l0_h1 = $9f31
vera_l0_v0 = $9f32
vera_l0_v1 = $9f33
;Vera zeropage state
vera_fb_lo    = $03
vera_fb_hi    = $04

;Loads the framebuffer address into Vera
.proc vera_framebuffer_load
    lda vera_fb_lo
    sta vera_l
    lda vera_fb_hi
    sta vera_m
    lda #$10
    sta vera_h
    rts
.endproc

;Creates an 8bit 320x192 framebuffer,
;which will be centered in the screen's centre
;and letter boxed since Vera runs in 4:3.
;The framebuffer may be double buffered.
.proc vera_320x192_8bpp
    lda #%10000000              ;Initialise the vera chip
    sta vera_ctl
    lda #0                      ;Finagle video control
    ora #%00010000              ;layer 0 will be bitmaped
    ora #%00000001              ;VGA only for now...
    sta vera_vcl
    lda #64                     ;Set vera up for 320x240 mode
    sta vera_hsc                ;This gives us square pixels
    sta vera_vsc
    sta vera_brd
    lda #%00000010              ;Center the 320x192 framebuffer
    sta vera_ctl                ;This results in 24px of letter boxing
    lda #24
    sta vera_scy
    lda #215
    sta vera_sch
    lda #%00000111              ;Configure layer0 for bitmap mode
    sta vera_lc0
    lda #%01111000              ;layer0 points to high buffer
    sta vera_lt0
    jsr vera_framebuffer_clear  ;Clear the low buffer
    lda #$f0                    ;Load the high buffer address
    jsr vera_framebuffer_load   
    jsr vera_framebuffer_clear  ;Clear the high buffer
    lda #$00                    ;Reload low buffer address
    jsr vera_framebuffer_load
    sei                         ;Enable vsync interrupts
    lda #%00000001
    sta vera_ien
    cli
    rts
.endproc

;Clears the framebuffer with the colour stored in A
.proc vera_framebuffer_clear
    pha
    jsr vera_framebuffer_load   ;Reload the framebuffer address
    pla
    ldy #0                      ;Initialise column counter
Column:
    ldx #0                      ;Initialise row counter
Row:
    sta vera_d0                 ;Write four pixels at a time
    sta vera_d0                 ;To reduce loop count
    sta vera_d0                 ;to fit within
    sta vera_d0                 ;an 8 bit register
    inx                     
    cpx #80                     ;Have 320 writes been done?
    bne Row                     ;If not, continue writing
    iny                     
    cpy #192                    ;Have 192 rows been done?
    bne Column                  ;If not, write a new row
    rts
.endproc

;Notifies vera that the backbuffer is ready for presentation
;Blocks until vsync flag is set in vera_isr
.proc vera_framebuffer_swap
    sei                         ;Disable interrupt services
Wait:                           ;This ensures atomicity
    lda vera_isr                ;Poll the vera_isr register
    and #$01                    ;for the vsync bit to be set
    beq Wait                    ;i.e.: this is a spin lock
Check:
    lda vera_fb_hi              ;Swap the buffers depending
    cmp #$00                    ;on the value of the high byte
    beq High                    ;if it's zero, swap to the high buffer
Low:                            ;Otherwise, swap to the low buffer
    lda #$00                    
    sta vera_fb_hi              ;Vera writes to low buffer
    lda #%01111000              
    sta vera_lt0                ;Bitmap display high buffer
    jmp Done
High:
    lda #$f0
    sta vera_fb_hi              ;Vera writes to high buffer
    lda #$00
    sta vera_lt0                ;Bitmap displays low buffer
Done:
    cli                         ;Reenable interrupt services
    rts
.endproc

.proc start
    jsr vera_320x192_8bpp
    lda #0
    sta $42
Loop:
    lda $42
    inc
    sta $42
    lsr
    adc #(256 - 32 - 5)
    jsr vera_framebuffer_clear
    jsr vera_framebuffer_swap
    jmp Loop
    rts
.endproc
