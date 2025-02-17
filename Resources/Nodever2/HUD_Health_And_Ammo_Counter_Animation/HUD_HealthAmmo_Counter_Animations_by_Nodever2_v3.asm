lorom

; Patch written by Nodever2 on March 26, 2023.
; This is a simple patch which makes the HUD health and ammo counters animate when increasing or decreasing
; instead of instantly changing. In its default configuration,
; health animates at a rate of 2 health per frame, while all ammo counters animate at 1 ammo every 4 frames.

;UPDATE v2 March 30, 2023: Gave the health counter some special coding to scale it's animation speed based on how far behind Samus' actual health value is. It is much more responsive now.
;UPDATE v3 April 1, 2023: Sorry for update spam, but this should be the last update. I kinda went back and forth on whether the ammo counters should use the updated health counter logic (which is a tiny bit more complex) for performance reasons, but in the end I decided it is better. In an isolated test I didn't experience any lag frames while all four counters were increasing using this logic, so it should be fine.

!80Freespace = $80D080 ; Repoint this if you need.

!SamusPrevHealth   = $0A06
!SamusCurHealth    = $09C2
!SamusPrevMissiles = $0A08
!SamusCurMissiles  = $09C6
!SamusPrevSupers   = $0A0A
!SamusCurSupers    = $09CA
!SamusPrevPBs      = $0A0C
!SamusCurPBs       = $09CE
!FrameCounter      = $05B6

; HIJACKS
org $809B93 : JSR UpdateSamusPrevHealth : NOP #3
org $809C0D : JSR UpdateSamusPrevMissiles
org $809C23 : JSR UpdateSamusPrevSupers
org $809C4C : JSR UpdateSamusPrevPBs

; FREESPACE

; UpdateSamusPrevValue: Generates asm to update one of the counters on the HUD's "previous value"s.
; Arguments:
;   Val: Value to update. Valid options are Health, Missiles, Supers, PBs.
;   S: Inverse of update speed. Should be an immediate value. Valid options are 0, 1, 3, 7, F, ...
;      Higher is slower. Speed decreases exponentially.
macro UpdateSamusPrevValue(Val, S)
UpdateSamusPrev<Val>:
	LDA <S> : STA $08
	LDA !SamusPrev<Val>
	JSR CheckFrameCounter : BCC + ; does not overwrite A
	STA $04
	LDA !SamusCur<Val>  : STA $06
	JSR UpdateCountersScaled
	STA !SamusPrev<Val>
+	RTS                           ; Need to return updated !SamusPrev<Val> in A
endmacro

org !80Freespace
%UpdateSamusPrevValue(Health, #$0000)
%UpdateSamusPrevValue(Missiles, #$0003)
%UpdateSamusPrevValue(Supers, #$0003)
%UpdateSamusPrevValue(PBs, #$0003)


;[$04] = counter value to animate
;[$06] = counter destination value
;[$08] = speed setting bitmask, should be 0, 1, 3, 7, F, ... ; higher means counter updates slower
	
; Return carry set 1 out of every ([$08] + 1) frames.
CheckFrameCounter:
	PHA
	LDA !FrameCounter : AND $08 : BEQ +
	PLA : CLC : RTS
+	PLA : SEC : RTS

; Still make sure A holds updated [$04] when returning.
UpdateCountersScaled:
	LDA $04 : SEC : SBC $06 : BEQ + ; [A] = [$04] - [$06]
	                          BPL ++
	; [$04] < [$06]
	EOR #$FFFF : INC              ; [A] = [A] * -1 (make [A] positive)
	LSR : LSR : BNE +++           ; [A] = [A] / 4
	LDA $04 : INC : STA $04 : RTS ; If [A] == 0: [$04] = [$04] + 1,   return
+++ CLC : ADC $04 : STA $04 : RTS ; Else:        [$04] = [$04] + [A], return
+	LDA $04 : RTS
	
++	; [$04] > [$06]
	LSR : LSR : BNE +++           ; [A] = [A] / 4
	LDA $04 : DEC : STA $04 : RTS ; If [A] == 0: [$04] = [$04] - 1,   return
+++	EOR #$FFFF : INC              ; ) Else:      [$04] = [$04] - [A], return
	CLC : ADC $04 : STA $04 : RTS ; /
	LDA $04 : RTS

;;THIS IS NOW DEPRECATED, uncomment if you want to use. I decided the below routine didn't take up too much processing time after all.
;{
;; Also, make sure A holds updated [$04] when returning.
;UpdateCounters:
;	LDA $04 : CMP $06 : BEQ +
;	                    BPL ++
;	
;	; [$04] < [$06]
;	INC : STA $04
;+	RTS
;	
;++	; [$04] > [$06]
;	DEC : STA $04
;	RTS
;}

;; UNCOMMENT ALL OF THE BELOW CODE TO REMOVE THE ANIMATION UPON LOADING THE GAME WHERE ALL OF YOUR COUNTERS COUNT UP FROM ZERO AS SAMUS APPEARS.
;
;;INITIALIZE HUD
;org $809AE4
;	LDA !SamusCurMissiles : INC : STA !SamusPrevMissiles
;	LDA !SamusCurHealth : INC : NOP
;org $90A8EF
;	; jumped to by the above routine, though this one is actually completely useless.
;	; So we just replace it with this code and then return afterwards.
;	STA !SamusPrevHealth
;	LDA !SamusCurSupers : INC : STA !SamusPrevSupers 
;	LDA !SamusCurPBs : INC : STA !SamusPrevPBs
;	RTL
	
	
