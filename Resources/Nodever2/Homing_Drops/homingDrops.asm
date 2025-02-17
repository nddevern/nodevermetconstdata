lorom
;Original inspiration by Black Falcon based on Prime tractor beam,
;But I (Nodever2) completely rewrote this and added some maths
;to make it smoother and cooler.

;TODO: optimize this a lot, better macros, make a new subroutine for all the copied code at the end, etc)

;Originally I wanted to write this so that the pickups sped up as they
;get closer and were slow as they were farther away.
;However upon writing this I found that it was really satisfying for them to move
;quickly when far and slow down as they get close. So I returned it for that.

;It is possible to change it back to the previous functionality but doing so
;makes it feel much less cool and not much of an improvement over the old tractor beam.

;Parameters:	A: val1
;				Y: val2
;Returns:		A: (val1-val2)
macro getDiff()
{
	PHY : SEC : SBC $01,s : PLY
}
endmacro

;Parameters:	A: val
;Returns:		A: |val|
macro getAbs()
{
	INC : DEC : BPL $04 : EOR #$FFFF : INC
}
endmacro

;Parameters:	A: val
;Returns:		A: |val|
macro getAbsEightBit()
{
	INC : DEC : BPL $03 : EOR #$FF : INC
}
endmacro

;defines:
!pbxpos = $0CE2
!pbypos = $0CE4
!samusxpos = $0AF6
!samusypos = $0AFA
!dropxpos = $1A4B
!dropypos = $1A93
!dropLifetimeRemaining = $1B23

!dp_maxSpeed = $00
!dp_maxRange = $02
!dp_X = $20
!dp_Y = $22
!dp_xdist = $04
!dp_ydist = $06
!dp_manhattan = $08
!dp_xproportion = $0A
!dp_yproportion = $0C
!dp_speedFactor = $0E

!tractordelay = $0050 ; 80 frames. How long the pickups wait before being attracted to their target. Recommend values between 0 and 0140.

!maxchargetractorspeed = #$0010	;how fast (px/frame) pickups are drawn to samus (recommend values between 0 and 00FF)
!maxpbtractorspeed = #$0040		;how fast (px/frame) pickups are drwan to powerbombs (recommend values between 0 and 00FF) - you have to uncomment a line of code below to activate this feature


;These are max manhattan distances allowed (limiting to 8bit because snes can only do 8bit multiplication)
!maxchargetractorrange = #$00FF	;range (pixels) pickups are drawn to samus (recommend values between 0 and 00FF)
!maxpbtractorrange = #$00FF		;range (pixels) pickups are drawn to powerbombs (recommend values between 0 and 00FF) - you have to uncomment a line of code below to activate this feature

;hex tweaks:
;org $90B860	: DB $3C						;how long charge beam must be held down to fire a beam (default 3C)	
;org $91D756	: DB $3C						;charge beam timer check for samus palette to change (should be equal to above value, default 3C)

;asm:
org $86F057 : JSL CHECKTRACTOR 				;hijack point (item drop)

org $83AD66;free space, any bank below $C0
CHECKTRACTOR:	
	PHY : PHX
    
;Compute InputVars
; $20 = samus or PB x pos, $22 = samus or PB y pos
; $00 = maxSpeed, $02 = maxRange
;	LDA $0592 : BMI ++	;if PB is going off, branch
;	LDA $0B62 : BNE +	;if samus is charging, branch
    LDA !dropLifetimeRemaining,x : CMP #$0190-!tractordelay  : BCC + ; timer starts at 0190h. Wait 80 frames.
    JMP .GTFO			;return
+	LDA !samusxpos : STA !dp_X
	LDA !samusypos : STA !dp_Y
	LDA !maxchargetractorspeed : LDY !maxchargetractorrange
	BRA +
++	LDA !pbxpos : STA !dp_X
	LDA !pbypos : STA !dp_Y
	LDA !maxpbtractorspeed : LDY !maxpbtractorrange
+	STA !dp_maxSpeed : STY !dp_maxRange

;Compute xdist, ydist
	LDA !dropxpos,x : TAY : LDA !dp_X : %getDiff() : STA !dp_xdist
	%getAbs() : STA !dp_manhattan
	STA !dp_xproportion;temp
	LDA !dropypos,x : TAY : LDA !dp_Y : %getDiff() : STA !dp_ydist
	%getAbs()
	STA !dp_yproportion;temp

;Compute manhattandist
	CLC : ADC !dp_manhattan : STA !dp_manhattan
	CMP !dp_maxRange : BEQ + : BMI +
	JMP .GTFO
+	
;Compute yproportion, xproportion
;INVERT(swap) THEM BECAUSE LATER WE DO ANOTHER INVERSION IN THE SPEED CALCULATION
;	LDA !dp_manhattan : AND #$00FF : TAY : LDA !dp_yproportion : JSR Divide
;	LDA $4216 : STA !dp_xproportion : PHA
;	LDA !dp_manhattan : SEC : SBC $01,s : STA !dp_yproportion : PLA

;alternate implementation (yes the division is unnecessary lol):
;	LDA !dp_xdist : %getAbs() : STA !dp_yproportion
;	LDA !dp_ydist : %getAbs() : STA !dp_xproportion
	LDA !dp_xdist : %getAbs() : STA !dp_xproportion
	LDA !dp_ydist : %getAbs() : STA !dp_yproportion
	
;Compute speedFactor
	SEP #$30
	LDA !dp_manhattan : LDY !dp_maxSpeed : JSR Multiply;A,Y in 8 bit mode
	REP #$20
	LDA $4216 : LDY !dp_maxRange : JSR Divide;Y in 8 bit mode
	REP #$30
	LDA $4214 : STA !dp_speedFactor
	
;Finally, move enemy drop
;Xpos = xpos+(|xproportion|*speedfactor/manhattandist)*xsign
	;multiply by speedfactor
	SEP #$30
	LDA !dp_xproportion : %getAbsEightBit() : LDY !dp_speedFactor : JSR Multiply
	REP #$20
	LDA $4216 : LDY !dp_manhattan : JSR Divide
	;roundoff issue is here, we are cutting off what could be subpixel values by not using remainder.
	REP #$30
	TDC : TAY
	LDA !dp_X : PHA
	LDA $4214;desired displacement, unsigned
	PHA; : LDA !dp_maxSpeed : SEC : SBC $01,s : STA $01,s;invert speed
	;dp_xdist = samuspos-droppos -> if negative, samus is left of drop. drop needs to move left.
	LDA !dp_xdist : BPL +;move in opposite direction of distance
	PLA : INY : EOR #$FFFF : INC : BRA $01
+	PLA : CLC : ADC !dropxpos,x : DEY : BEQ +++
	CMP $01,s : BMI ++ : LDA $01,s : BRA ++
+++	CMP $01,s : BPL ++ : LDA $01,s
++	STA !dropxpos,x : PLA

;Ypos = ypos+(|yproportion|*speedfactor/manhattandist)*ysign
	SEP #$30
	LDA !dp_yproportion : %getAbsEightBit() : LDY !dp_speedFactor : JSR Multiply
	REP #$20
	LDA $4216 : LDY !dp_manhattan : JSR Divide
	REP #$30
	TDC : TAY
	LDA !dp_Y : PHA
	LDA $4214;desired displacement, unsigned
	PHA; : LDA !dp_maxSpeed : SEC : SBC $01,s : STA $01,s
	LDA !dp_ydist : BPL +;move in opposite direction of distance
	PLA : INY : EOR #$FFFF : INC : BRA $01
+	PLA : CLC : ADC !dropypos,x : DEY : BEQ +++
	CMP $01,s : BMI ++ : LDA $01,s : BRA ++
+++	CMP $01,s : BPL ++ : LDA $01,s
++	STA !dropypos,x : PLA

.GTFO
	PLX : PLY : LDA !samusxpos : SEC : RTL

;Parameters:	A: dividend (16 bit)
;				Y: divisor (8 bit)
;Returns:		results of A/Y in division registers
Divide:
	PHP
	STA $4204
	SEP #$30
	STY $4206
	NOP : NOP;4/13 cycles
	PLP;4/13 cycles
	RTS;6/13 cycles
	
;Parameters:	A: factor1 (8 bit)
;				Y: factor2 (8 bit)
;	ASSUMES 8-BIT MODE
;Returns:		results of A/Y in division registers
Multiply:
	STA $4202
	STY $4203
	RTS


;(I think) The correct math for this kind of thing would be:
;(ALSO DP ALLOCATION IN PARENTHESES)
;($00, $02) input vars: maxSpeed, maxRange
;($20) samus/PB X
;($22) samus/PB Y
;($01,s) enemy index

;($04) xdist = (SamusX - DropX), xsign = 1 if DropX < SamusX, else -1
;($06) ydist = (SamusY - DropY), ysign = 1 if DropY < SamusY, else -1

;($08) manhattandist = |xdist|+|ydist|

;($0A) xproportion = xdist/manhattandist
;($0C) yproportion = 1 - xproportion

;($0E) speedFactor = (manhattandist/maxRange)*maxSpeed

;displacement vector should be <xproportion*xsign, yproportion*ysign>*speedFactor
;displacement should only occur if manhattandist <= maxRange

;