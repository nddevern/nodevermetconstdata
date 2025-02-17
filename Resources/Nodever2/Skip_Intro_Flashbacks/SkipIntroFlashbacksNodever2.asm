lorom

;Patch by Nodever2, 2-12-22. Like all my asm patches, credit to PJ's bank logs, his hard work goes a long way towards making these patches easier to make.
;By default, this patch skips all flashbacks between intro text pages. You can choose which flashbacks to skip using the instructions below.
;This patch uses some freespace. Tested, works with all combinations of intro flashbacks. Works with Japanese text. Works with Kej's quick intro text.
;HOW TO USE: 
;	To keep a cutscene, comment out one of the four lines of asm below that skips it.

org $8BAF0A : JSR $AF1E : STZ $1A57 : STZ $1A49 : LDA #$B336 : STA $1F51 : JMP ClearText;SKIP MOTHER BRAIN CUTSCENE

org $8BAF7B : LDA #$B33E : STA $1F51 : JMP ClearText;SKIP BABY METROID CUTSCENE

org $8BB100 : LDA #$B346 : STA $1F51 : JMP ClearText;SKIP SAMUS GIVING METROID TO SCIENTISTS

org $8BB131 : LDA #$B34E : STA $1F51 : JMP ClearText;SKIP SCIENTIST RESEARCH CUTSCENE

;==============================================================================================

;YOU CAN REPOINT THE BELOW ORG TO ANY FREE OR UNUSED SPACE IN $8B.
;We are storing needed helper functons here.
org $8BCC63;Can be repointed to any free or unused space in $8B. I am overwriting unused spritemaps.
	dw $9438;in case this actually gets read as an instruction list for some reason
	
;Function: Clears the english and japanese text from the screen.
ClearText:
	LDX #$0100 : LDA #$002F	;\
-	STA $7E3000,x			;|
	INX : INX				;} Clear English text region
	CPX #$0600				;|
	BMI -					;/
	JSR $A86A				; Blank out Japanese text tiles
	RTS

;Function: Clears the palette for the intro text screen if we are fading back in from a different cutscene.
ClearPalette:
	LDA $1A49 : CMP #$FFFF : BNE +
	JMP $8C5E;clear the expected palette
+	LDX #$0020 : LDY #$0010 : JSR $8C5E;clear bg palette 1 instead (for compatability with Kej quick intro patch)
	LDX #$0040 : LDY #$0010 : JSR $8C5E;clear bg palette 2 for same reason
	LDX #$00E0 : LDY #$0010 : JSR $8C5E;clear bg palette 7 for same reason
	RTS

;Function: Composes the palette for the intro text screen if we are fading back in from a different cutscene.
;	This entire function exists because of a small graphical bug when using this patch with Kej's quick intro patch with Japanese text enabled under certain conditions >:(
ComposePalette:
	LDA $1A4B : BEQ +
	JMP $8CEA;compose the expected palette
+	RTS

warnpc $8BCCAC;if you repoint this asm, you may want to change this too.

;==============================================================================================

;DO NOT REPOINT THESE BELOW.
;Adding checks to see if we should clear the palette:
org $8BB3CE : JSR ClearPalette;this call blacks out the text palette (pal line 0h)
org $8BB3D7 : JSR ClearPalette;this call blacks out the samus bg (pal line 3h)
org $8BB3E0 : JSR ClearPalette;blacks out colors for the blinking text sprite it seems
org $8BB43B : JSR ComposePalette;Fix JPN text turning black on page 2 if you end page 1 with Kej's quick intro patch after you let go of A.



