lorom

;This code makes bombs break a 3x3 radius instead of a cross-shape.
;Original code was by Nodever2, but this code is by Benox50 and uses no freespace doing the same thing.
;Credits: crashtour for the idea, P.JBoy for his precious bank logs as always.

;;;;;;;;;;;;;;;;;
;;; 3x3 bombs ;;; Credits to Nodever2
;;;;;;;;;;;;;;;;;
org $949CF4
{
    LDA $0C7C,x : BNE + ;Do routine only when bomb exploding
;Projectile -> normal bomb is exploding
    LDA $0C18,x : BIT #$0001 : BNE +
    ORA #$0001 : STA $0C18,x
;
    LDA $0DC4 : INC : BEQ + ;Ignore if current nth block of room #$FFFF
    TDC : TAY ;0 in Y for reasons?
;Do center block (current block where the bomb is)
print " 3x3 bombs ", pc    
    LDA $0DC4 : ASL : TAX ;Get currently processed nth block of room (Good thing its where bomb is)
    PHX ;Save center
    JSR $A052 ;Trig block bombed reaction
;Center, left block 
    DEX #2 : JSR $A052
;Center, right block     
    INX #4 : JSR $A052
;Do block above bomb
    LDA $01,s ;Get center back to A for some math (no stack pull)
    SEC : SBC $07A5 : SBC $07A5 ;2 times cause its a *2 index I guess
    TAX : JSR $A052
;Above bomb, left block
    DEX #2 : JSR $A052
;Above bomb, right block
    INX #4 : JSR $A052
;Do right block under bomb
    PLA ;Get center back to A for some math 
    SEC : ADC $07A5 : ADC $07A5 : INC ;(Ye we add an additional +1 to ADC with SEC :p)
    TAX : JSR $A052 
;Under bomb, center
    DEX #2 : JSR $A052
;Under bomb, left block
    DEX #2 : JSR $A052 
+    
    RTS 
}
