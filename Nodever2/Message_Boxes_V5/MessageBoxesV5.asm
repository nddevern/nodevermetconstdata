;==VERSION HISTORY==
;* V1 by Kejardon
;
;* V2 by JAM:
; - Add ability to add big message boxes.
; - Add ability to set location of buttons inside messages.
; - New comments added.
;
;* V3 by JAM:
; - Constants added for easy usage.
; - Message coding is changed to newbie-friendly format.
;
;* V3.1 by JAM:
; - Button array is fixed by shifting the words.
; - Message constants added to simplify message defining.
;
;* V4 by JAM: 
; - Numbers are added to constants.
; - More message constants added.
; - Extra coded written to allow any button (not just Shot and Run) in big message boxes and also create empty big message box.
; - Fix1C1F subroutine relocated to space that was previously used by button array.
;
;* V4.1 by Nodever2:
; - More comments
;
;* V5 by Nodever2:
; - Allow repointing this patch using a new define to be able to write the new data anywhere in $85 freespace instead of being hardcoded at $859643 (it still writes there by default though)
; - Made MessageConstants reference their respective labels instead of having hardcoded addresses
; - Replaced Fix1C1F with FixMessageDefOffset, which unlike Fix1C1F allows the new message box locations to be at any location in $85, using the aforementioned new define in it's calculation instead of a hardcoded number.
; - Simplified comments and defines a little
; - Simplified patch release to just include the asm file, and included all other information in this description page.

!Freespace85 = $859643

;K: Kejardon
;J: JAM
;N: Nodever2

;K: A hack to add new message boxes. Based on an item in Insanity, stripped of spoily stuff and commented for public use.
;K: This hasn't been extensively bugtested yet, but at the moment I don't know of any bugs from it.
;J: I've tested it. Looks like, you can use big and small messages with or without highlighted buttons.
;J: Lines below are used to set letter and color numbers for using in this patch.

;N: YOU SHOULD DEFINITELY READ THIS WHOLE DOCUMENT BEFORE USING IT.
;N: Everything in a line after a semicolon (like this line here) is COMMENTED OUT. It is NOT CODE, but rather notes to help you understand what's going on here. You're going to need them.
;N: Troubleshooting problems? Maybe this will help: http://forum.metroidconstruction.com/index.php/topic,3612.msg47748.html
;N: and this: http://forum.metroidconstruction.com/index.php/topic,4449.msg60545.html#msg60545
;N: and this: http://forum.metroidconstruction.com/index.php/topic,735.0.html

;N: Quick summarry of how to add a new message box:
; 1) Add a new Message Box Definition. Vanilla message boxes are IDs 01h-1Ch, so the new ones start at 1Dh and increase from there. Every new Message Box Definition you add to the end of the list uses the next ID.
; 2) Add the Message Box Data, making sure that the last entry in the Message Box Definition has the same label as the label you put before the Message Box Data.
;      Note: You can add the new Message Box Data anywhere in the Message Box Data section, as long as it is a contiguous block somewhere in there with the correct label in front,
;            it doesn't matter where exactly. Messages are always indexed by the order of the Message Box Definitions, regardless of where the data they point to is.
; 3) Add a new entry into the Button Array for the position of the button icon to draw in your new message box, or add $0000 if you are using !EmptySmall or !EmptyBig

lorom

;Letters
!A = $E0
!B = $E1
!C = $E2
!D = $E3
!E = $E4
!F = $E5
!G = $E6
!H = $E7
!I = $E8
!J = $E9
!K = $EA
!L = $EB
!M = $EC
!N = $ED
!O = $EE
!P = $EF
!Q = $F0
!R = $F1
!S = $F2
!T = $F3
!U = $F4
!V = $F5
!W = $F6
!X = $F7
!Y = $F8
!Z = $F9

;Numbers
!n1 = $00 ; 1
!n2 = $01 ; 2
!n3 = $02 ; 3
!n4 = $03 ; 4
!n5 = $04 ; 5
!n6 = $05 ; 6
!n7 = $06 ; 7
!n8 = $07 ; 8
!n9 = $08 ; 9
!n0 = $09 ; 0

;Symbols
!dot         = $FA ; .
!comma       = $FB ; ,
!quote       = $FC ; '
!question    = $FE ; ?
!exclamation = $FF ; !
!Dash        = $CF ; -
!percent     = $0A ; %
!_           = $4E ; empty space

;Colors
!red    = $28
!yellow = $3C
!green  = $38
!blue   = $2C

;MessageConstants
!EmptySmall = #EmptySmall
!EmptyBig   = #EmptyBig
!Shot       = #Shot
!Run        = #Run
!Jump       = #Jump
!ItemCancel = #ItemCancel
!ItemSelect = #ItemSelect
!AimDown    = #AimDown
!AimUp      = #AimUp

!Big        = #TilemapBig
!Small      = #TilemapSmall




org !Freespace85

;===================================================================
;===================== MESSAGE BOX DEFINITIONS =====================
;===================================================================


;K: Somewhere in your bank 84 you should have a PLM using a message box, change the index to 1D or higher.
;K: See PLM_Details.txt for how to do that.
;J: You can create new item or use Messenger patch (see patch section) for this purpose.

;	DW $88F3 : DW $0040 : DB $1D	;For example, this is the instruction used by a new item in Insanity.

;K: Here is where you can put in new message box definitions and tiles. All definitions must be consecutive; do not put tiles in between definitions.

;K: Example message box definitions. They start at the first new slot, 1D.
;K: The first two DW's are for the message box setup and size.
;J: The only thing I don't know is how to get 3 line text messages, such as "Energy recharge completed."

;K: Each new definition simply needs a new message box label for the last entry of the DW.
;J: For the big messages, use any of these constants, depending on button you need for the first entry of the DW: !Shot, !Run, !Jump, !ItemCancel, !ItemSelect, !AimDown, !AimUp. Use !EmptyBig for none.
;J: Second DW entry should be !Big for a big messages.

;J: For the small messages, use !EmptySmall for the first DW and !Small for the second one.

;N: Below this line are examples. You can either uncomment one or copy one and make your own. These correspond to the example message boxes below (which are also currently commented out). See below for more details.

;	DW !Shot, !Big, BigMessageBoxShotExample
;	DW !Run,  !Big, BigMessageBoxDashExample
;	DW !EmptySmall, !Small, SmallMessageBoxExample

;J: Don't touch this line.
;N: The list of message box definitions must be terminated by dummy data for a small message box. That's what this is.
	DW !EmptySmall, !Small, ButtonArray

;===================================================================
;======================== MESSAGE BOX DATA =========================
;===================================================================

;K: Small message box tiles. Start with the message box label from its definition.
;K&J: The first and last lines are blank tiles for past the left and right edge of the message box. These must be in every message box, and you probably don't want to change them.
;K&J: The lines starting with DB you'll probably want to edit. 
;J: In each line starting with DB there should be a letter and a color after that. Don't place 2 letters or 2 colors in one line!
;J: Change "_" symbol after sign "!" to get the letter you want. 
;J: Change color after sign "!" to change color. Available colors are: red, yellow, green and blue.
;K&J: Each small message box requires 32 words, so don't add or delete any lines, just change them.

;N: Below this line is an example. You can either uncomment it or copy it and make your own. MAKE SURE the title of this (for this example, it's "SmallMessageBoxExample") also has a corresponding line above (for this example, it's line 120: DW !EmptySmall, !Small, SmallMessageBoxExample)

;SmallMessageBoxExample:
;	DW $000E, $000E, $000E, $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !H, !red
;	DB !E, !red
;	DB !L, !red
;	DB !L, !red
;	DB !O, !red
;	DB !_, !red
;	DB !W, !red
;	DB !O, !red
;	DB !R, !red
;	DB !L, !red
;	DB !D, !red
;	DB !exclamation, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E, $000E, $000E, $000E, $000E

; ==================================================================

;J: Big message box tiles. Start with the message box name from its definition.
;K&J: The first and last lines in each group are blank tiles for past the left and right edge of the message box. These must be in every message box, and you probably don't want to change them.
;N:   Each message box will have 4 "groups" i.e. four rows.
;K&J: The lines starting with DB you'll probably want to edit. 
;J: In each line starting with DB there should be a letter and a color after that. Don't place 2 letters or 2 colors in one line!
;J: Change "_" symbol after sign "!" to get the letter you want. 
;J: Change color after sign "!" to change color. Available colors are: red, yellow, green and blue.
;K&J: Each big message box requires 128 words (4 groups of 32 words), so don't add or delete any lines, just change them.

;N: Below this line are two examples. It works pretty much the same as the small ones, but it's big. Remember that each big message box is 4 rows of tiles long
;   (you can tell when one ends and the next starts by where the name for the next message box is; in these examples, BigMessageBoxShot ends where BigMessageBoxDash begins).


;BigMessageBoxShotExample:
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E
;
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n2, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E
;
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n3, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E
;
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n4, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E

; ---------------------------------

;BigMessageBoxDashExample:
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n1, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E
;
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n2, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E
;
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n3, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E
;
;	DW $000E, $000E, $000E
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !T, !red
;	DB !E, !red
;	DB !S, !red
;	DB !T, !red
;	DB !n4, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DB !_, !red
;	DW $000E, $000E, $000E

; ---------------------------------

;J: Strict order like "small messages first" isn't necessary. 

;===================================================================
;========================== BUTTON ARRAY ===========================
;===================================================================

;J: There is a relocated button array for big messages with text "press certain button". 
;J: Meaning of this array is if you change default control settings and shot will use Y button instead of X, then in the default text (press the X button) letter X will be rewritten with Y. 
;J: Actually, there are a different button written by default in each message, but this doesn't matter.

;J: Each word is a position of correct letter. 
;J: When adding a new message, don't forget to add a word to this array. 

;J: In short messages such as "Energy Tank" the value must be $0000.

;J: In big messages the value is the position of tile that will be rewritten.
;J: Add 2 to move the button right, subtract 2 to move the button left.
;J: Add 40 to move the button down, subtract 40 to move the button up.
;J: To create big message without rewriting a tile, use value $0020 and !EmptyBig constant as a first DW when defining certain message box.
;J: Note that you can overwrite empty tiles in top and border lines of each message.


ButtonArray:
	DW $0000, $012A, $012A, $012C, $012C, $012C, $0000, $0000, $0000, $0000, $0000, $0000, $0120, $0000, $0000
;Above: Messages 01-0F (Don't touch)
;N: When adding new messages, you'll have to add an entry to the below line (or make a third DW for all your new ones; doesn't matter). See above for details.
	DW $0000, $0000, $0000, $012A, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000
;Above: Messages 10-1C





;K: The rest is code to make the game use the free space above for new message boxes. No touching.
;J: FixSize subroutine is replaced. It has a limitation for using only small messages. I've tweaked it a bit, but got another limitation: last message must be small. So, I got rid of it and added a bunch of pointers to unexisting message (see above).
;J: Fix1C1F subroutine is relocated to use space previously used by button array.
;N: Fix1C1F is replaced with FixMessageDefOffset to allow for !Freespace85 to be any value, not only a multiple of 6 after 8749.


org $85824B : JSR FixMessageDefOffset

org $8582ED : JSR FixMessageDefOffset

org $858413 : DW ButtonArray


;dest offset = 869B + (!Freespace85 - 869B)
org $858749
FixMessageDefOffset:
    CLC : ADC $34
    CMP.w #$1C*6 : BMI + ; if we are reading from before the end of message box 1C data, return
    STA $34 : LDA #$1C*6*-1+!Freespace85-$869B : CLC : ADC $34 ; the value being LDA'd here is: difference of (end of vanilla message box definitions location) and (new message box definitions location)
+   RTS

;J: Extra code, allowing to use all buttons, not only used Run and Fire used by game for creating messages like "press A to jump" (and get correct button, of course) or short instructions of how to use Wall Jump or Space Jump techniques. You can also make a short player-friendly guide for each button and display these messages in the first few rooms, like it was done in Metroid Prime series.


Jump:
	REP #30
	LDA $09B4
	BRA Goto83D1
ItemCancel:
	REP #30
	LDA $09B8
	BRA Goto83D1
ItemSelect:
	REP #30
	LDA $09BA
	BRA Goto83D1
AimDown:
	REP #30
	LDA $09BC
	BRA Goto83D1
AimUp:
	REP #30
	LDA $09BE
Goto83D1:
	JMP $83D1
	
;print pc, " - END OF DATA AT 858749" ; debug
warnpc $858780

org $8583C5
Shot:

org $8583CC
Run:

org $858436
EmptySmall:

org $858441
EmptyBig:

org $85825A
TilemapBig:

org $858289
TilemapSmall:

	