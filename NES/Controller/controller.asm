  .inesprg 1   ; 1x 16KB PRG code
  .ineschr 1   ; 1x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;
;; DECLARE SOME VARIABLES HERE
  .rsset $0000  ;;start variables at ram location 0
buttons1   .rs 1  ; player 1 gamepad buttons, one bit per button
bulletIsActive .rs 1 ; is bullet active?

CONTROLLER_A      = %10000000
CONTROLLER_B      = %01000000
CONTROLLER_SELECT = %00100000
CONTROLLER_START  = %00010000
CONTROLLER_UP     = %00001000
CONTROLLER_DOWN   = %00000100
CONTROLLER_LEFT   = %00000010
CONTROLLER_RIGHT  = %00000001
    
  .bank 0
  .org $C000 
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down



LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$1C              ; Compare X to hex $20, decimal 32
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
              
              

  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000

  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop
  
 

NMI:
  LDA #$00
  STA $2003       ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014       ; set the high byte (02) of the RAM address, start the transfer

  ;Update enemy movement
EnemyMove:
  LDA $0214
  CLC
  ADC #1
  STA $0214
  
  LDA $0218
  CLC
  ADC #1
  STA $0218

UpdateBullet:
  LDA bulletIsActive
  BEQ UpdateBulletDone
  
  ; Update bullet position
  LDA $0210
  SEC
  SBC #1
  STA $0210
  
  ; Check if bullet is off top of screen
  BCS .BulletNotOffTop
  LDA #0
  STA bulletIsActive
  JMP UpdateBulletDone
.BulletNotOffTop
  
  ; Check collision
ColCheck1 .macro
  LDA $0210 ; bullet Y
  SEC
  SBC \1 ; enemy y
  CLC
  ADC #4
  BMI .ColDone\@ ; Branch if bulletY - enemyY + 4 < 0
  SEC
  SBC #8
  BPL .ColDone\@ ; branch if bulletY - enemyY - 4 > 0
  
  LDA $0213 ; bullet X
  SEC
  SBC \1 + 3 ; enemy X
  CLC
  ADC #4
  BMI .ColDone\@ ; Branch if bulletX - enemyX + 4 < 0
  SEC
  SBC #8
  BPL .ColDone\@ ; branch if bulletX - enemyX - 4 > 0
  
  LDA #0
  STA bulletIsActive ; kill the bullet
  STA $0210
  ;STA $0211
 ; STA $0212
  STA $0213
  STA \1 
  ;STA \1 + 1
  ;STA \1 + 2
  STA \1 + 3
.ColDone\@: 
  .endm
  ColCheck1 $0214
  ColCheck1 $0218
UpdateBulletDone:


  JSR ReadController1

ReadLeft: 
  LDA buttons1       ; player 1 - A
  AND #CONTROLLER_LEFT  ; only look at bit 0
  BEQ .Done   ; branch to ReadADone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
  LDX #0
.Loop:
  LDA $0203, x    ; load sprite X position
  SEC             ; make sure the carry flag is clear
  SBC #$01        ; A = A + 1
  STA $0203, x    ; save sprite X position
  INX
  INX
  INX
  INX
  CPX #$10
  BNE .Loop       ; Stop looping after 4 sprites (X = 4*4 = 16)
  
 
.Done:        ; handling this button is done
  

ReadRight: 
  LDA buttons1       ; player 1 - B
  AND #CONTROLLER_RIGHT  ; only look at bit 0
  BEQ .Done   ; branch to ReadBDone if button is NOT pressed (0)
                  ; add instructions here to do something when button IS pressed (1)
  LDX #0
.Loop:
  LDA $0203, x    ; load sprite X position
  CLC             ; make sure the carry flag is clear
  ADC #$01        ; A = A + 1
  STA $0203, x    ; save sprite X position
  INX
  INX
  INX
  INX
  CPX #$10
  BNE .Loop
.Done:        ; handling this button is done

ReadA:
  LDA buttons1
  AND #CONTROLLER_A
  BEQ .Done
  
  LDA bulletIsActive
  BNE .Done
  ;spawn enemy
  LDA #$0		;vert
  STA $0218
  LDA #$38		;tile
  LDA #0		;atr
  LDA #$80		;horiz
  STA $021C
  
  
  
  ; Fire bullet
  LDA $0200  ; Vertical
  STA $0210
  LDA #$64   ; Tile
  STA $0211
  LDA #0     ; Attributes
  STA $0212
  LDA $0203  ; Horizontal
  CLC
  ADC #4
  STA $0213
  
  LDA #1
  STA bulletIsActive
  
.Done:
  
  RTI             ; return from interrupt
 
 
ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
  
ReadController1Loop:
  LDA $4016
  LSR A            ; bit0 -> Carry
  ROL buttons1     ; bit0 <- Carry
  DEX
  BNE ReadController1Loop
  RTS

;;;;;;;;;;;;;;  
  
  
  
  .bank 1
  .org $E000
palette:
  .db $0F,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$31,$02,$38,$3C,$0F,$1C,$15,$14,$31,$02,$38,$3C
;4 bytes each sprite for LDA so 200 204 208 20C 210 + Hexdiecil
sprites:
     ;vert tile attr horiz
  .db $80, $32, $00, $80   ;sprite 0
  .db $80, $33, $00, $88   ;sprite 1
  .db $88, $34, $00, $80   ;sprite 2
  .db $88, $35, $00, $88   ;sprite 3
  .db $00, $00, $00, $00   ;bullet
  .db $10, $38, $00, $45   ;enemy
  .db $5, $37, $00, $80   ;enemy2
  

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
  
  
;;;;;;;;;;;;;;  
  
  
  .bank 2
  .org $0000
  .incbin "mario.chr"   ;includes 8KB graphics file from SMB1