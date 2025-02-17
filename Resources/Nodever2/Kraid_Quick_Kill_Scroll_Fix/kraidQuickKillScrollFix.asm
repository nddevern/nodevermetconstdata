;If kraid gets killed b4 rising up, this code will make sure the camera isn't locked to the first screen.
;Also bg removal if you're into not having a background for bossez, & a change in screen shakez.

;Modified by Nodever2 on 12-21-19. Changed the hijack point to make it so the screen can scroll immediately, as
;the original patch had an issue where if you went through Kraid's right door as soon as he died, you could misalign
;the scrolling.
;Also removed changed bg and screen shake because why was it there in the first place.
lorom

org $A7C416
	JSR kscroll

org $A7C59B
	JMP kceiling

org $A792B5	;//[unused foot hitbox]
kscroll:
	LDA #$0202 : STA $7ECD20 : LDA #$0101 : STA $7ECD22 ;//[scroll]
	LDX #$0000;original code that was replaced by hijack
	RTS
kceiling:
	JSR $C168;spawn PLM that vaporizes the ceiling
	JMP $AD9A;original code that was replaced by hijack
	