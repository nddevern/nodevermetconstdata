lorom

;This code makes bombs break tiles close to the bomb if the bomb is on the edge of two tiles - it will break both of them instead of just 1.
;Uses freespace in $94. Code by Benox50.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Bombs block reaction ;;; Credits to Nodever2, Crashtour, P.JBoy
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;{
;Hijacks
org $94A642
    JSR BombRad
org $949CEE
    JSR BombRad


;Blocks to break around samus
org $949CF4
;Center left
BombRad_Break_L:
    LDX $16
    DEX #2 : JSR $A052
    RTS
;Center right
BombRad_Break_R:     
    LDX $16
    INX #2 
    JSR $A052
    RTS
;Above
BombRad_Break_U:
    LDA $16
    SEC : SBC $07A5 : SBC $07A5 ;2 times cause its a *2 index I guess
    TAX : JSR $A052
    RTS
;Above left
BombRad_Break_UL:    
    LDA $16
    SEC : SBC $07A5 : SBC $07A5 : DEC #2
    TAX : JSR $A052
    RTS
;Above right
BombRad_Break_UR:
    LDA $16
    SEC : SBC $07A5 : SBC $07A5 : INC #2
    TAX : JSR $A052
    RTS 
;Under
BombRad_Break_D:
    LDA $16
    CLC : ADC $07A5 : ADC $07A5
    TAX : JSR $A052  
    RTS
;Under left 
BombRad_Break_DL:    
    LDA $16
    CLC : ADC $07A5 : ADC $07A5 : DEC #2
    TAX : JSR $A052  
    RTS
;}




; FREESPACE ;
org $94B210
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Bombs block reaction ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;{
BombRad:
    TXY
    LDA $0C7C,x : BNE BombRad_End ;Do routine only when bomb exploding
;Projectile -> Normal bomb has exploded already?
    LDA $0C18,x : BIT #$0001 : BNE BombRad_End
    ORA #$0001 : STA $0C18,x
;
print " BombRad ", pc 
    ;LDA $0DC4 : INC : BEQ BombRad_End ;Ignore if current nth block of room #$FFFF
    ;TDC : TAY ;0 in Y for reasons?
    LDA $0DC4 : ASL : STA $16 ;Save dis for later
;Decide what type of bombing to use depending of bomb position in block area    
;X pos     
    LDA $0B64,x : AND #$000F ;Index is proj index but with offset of Ah, so we load -Ah behind 
    CMP #$0003 : BMI BombRad_XL ;X pos, left from block center (x left)
    CMP #$000D : BPL BombRad_XR ;X pos, right from block center (x right)
;Y pos    
    LDA $0B78,x : AND #$000F
    CMP #$0003 : BMI BombRad_YU ;Y pos, above block center (y up)
    CMP #$000D : BPL BombRad_YD ;Y pos, under block center (y down)

;Bomb centered on block, normal 
    JMP BombRad_Center

BombRad_End:    
    RTS

;Bomb on block vertical edge, on horizontal edge too ?
BombRad_XL:
    LDX #$0000 : BRA BombRad_XR2 
BombRad_XR:
    LDX #$0001
BombRad_XR2:
    LDA $0B78,y : AND #$000F
    CMP #$0003 : BMI BombRad_XYU 
    CMP #$000D : BPL BombRad_XYD 

;Bomb on vertical edge
    JMP BombRad_EdgeV
    
;Bomb in a corner     
BombRad_XYU:
    LDY #$0000 : BRA BombRad_XYD2 
BombRad_XYD:
    LDY #$0001
BombRad_XYD2:
    JMP BombRad_Corner
    
;Bomb on horizontal edge
BombRad_YU:
    LDY #$0000 : BRA BombRad_YD2
BombRad_YD:
    LDY #$0001
BombRad_YD2:
;
;;; Break Methods ;;;

;Trig break horizontal edge
BombRad_EdgeH:
print " BombRad EdgeH ", pc
    LDX $16 : JSR $A052 ;Center
;Left and right
    JSR BombRad_Break_L
    JSR BombRad_Break_R
;Up or Down?
    DEY : BEQ +
    JSR BombRad_Break_U
    JSR BombRad_Break_UL
    JSR BombRad_Break_UR
    RTS
+
    JSR BombRad_Break_D
    JSR BombRad_Break_DL 
    JSR BombRad_Break_DR
    RTS

;Trig break center
BombRad_Center:
;Do center block (current block where the bomb is)
print " BombRad Center ", pc        
    LDX $16 : JSR $A052 ;Center
    JSR BombRad_Break_L
    JSR BombRad_Break_R
    JSR BombRad_Break_U 
    JSR BombRad_Break_D
    RTS
    
;Trig break vertical edge
BombRad_EdgeV:
print " BombRad EdgeV ", pc
    PHX
    LDX $16 : JSR $A052 ;Center
;Up and down    
    JSR BombRad_Break_U
    JSR BombRad_Break_D
;Left or right?
    PLX
    DEX : BEQ +
    JSR BombRad_Break_L
    JSR BombRad_Break_UL
    JSR BombRad_Break_DL
    RTS
+    
    JSR BombRad_Break_R
    JSR BombRad_Break_UR
    JSR BombRad_Break_DR
    RTS

;Trig break corner
BombRad_Corner:
print " BombRad Corner ", pc
    PHX
    LDX $16 : JSR $A052 ;Center
;Branch to one of the block corner cadrans
    PLX
    DEX : BEQ BombRad_Corner_R
    DEY : BEQ BombRad_Corner_DL
BombRad_Corner_UL:
    JSR BombRad_Break_U
    JSR BombRad_Break_L
    JSR BombRad_Break_UL
    RTS
BombRad_Corner_R:
    DEY : BEQ BombRad_Corner_DR
BombRad_Corner_UR:
    JSR BombRad_Break_U
    JSR BombRad_Break_R
    JSR BombRad_Break_UR
    RTS
BombRad_Corner_DR:
    JSR BombRad_Break_D 
    JSR BombRad_Break_R 
    JSR BombRad_Break_DR
    RTS
BombRad_Corner_DL:
    JSR BombRad_Break_D
    JSR BombRad_Break_L
    JSR BombRad_Break_DL
    RTS


;Moar block breaking choices :d
;Under right 
BombRad_Break_DR:    
    LDA $16
    CLC : ADC $07A5 : ADC $07A5 : INC #2
    TAX : JSR $A052  
    RTS
;}
	print " End of BombRad Stuff ", pc 