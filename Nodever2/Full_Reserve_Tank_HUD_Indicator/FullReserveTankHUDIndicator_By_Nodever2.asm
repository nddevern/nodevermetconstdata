;By Nodever2, april 2022. No freespace used.
;This code adds a new feature to the game where when reserve tanks are full on auto mode, the HUD icon
;turns pink (or more accurately, to the same color as full etanks).

;Warning, the Auto Reserve tilemap at $80998B is now unused and replaced with some custom code.
;The Empty Auto Reserve one has also been repointed (See "Data").

;Thanks to PJBoy's bank logs as always. Also tilemap format is as follows:
;tilemap format is yxpPPPtttttttttt
;where PPP are the palette bits

lorom

org $809B51
	DEC : BNE BRANCH_NOT_AUTO_RESERVES;small optimization of vanilla code

;First things first, check if reserves are Full, Empty, or neither.
;The way this works is that we are storing a value in $14 that will later be XOR'ed with the reserve tilemap
;value loaded from ROM. We are doing this to manipulate the tiles' palette bits at runtime.

	LDA $09D6 : BNE NotEmpty
	TDC : BRA Plus ;(Same as LDA #$0000 : BRA +) Reserves are empty, display blue icon
	
;Shoving the Empty Auto Reserve tilemap data here because I have no other place to put it, sorry.
;Using no freespace sometimes involves sacrificing organization (we needed the BEQ here anyway).
Data:
	DW $2C33, $2C46
	DW $2C47, $2C48
	DW $AC33, $AC46
	
NotEmpty:
	CMP $09D4 : BEQ Full
	LDA #$1000 : BRA Plus;Reserves are not empty nor full, display yellow icon.

Full:
	LDA #$0400;Reserves are full, display pink icon.
Plus:
	STA $14 : TDC : TAY : TAX

	;Y is index into reserve tilemap in ROM to transfer
	;X is index into reserve tilemap destination in RAM
	JSR TransferNextVal					;stores to 7EC618
	JSR TransferNextVal					;stores to 7EC61A
	JSR NextRowX : JSR TransferNextVal	;stores to 7EC658
	JSR TransferNextVal					;stores to 7EC65A
	JSR NextRowX : JSR TransferNextVal	;stores to 7EC698
	JSR TransferNextVal					;stores to 7EC69A
	
;vanilla code optimization to save space in these curly brackets below:
{
BRANCH_NOT_AUTO_RESERVES:
	LDA $09C2 : CMP $0A06 : BEQ BRANCH_HEALTH_END
	STA $0A06
	STA $4204
	SEP #$20
	LDA #$64 : STA $4206
	PHA : PLA : PHA : PLA : REP #$20
	LDA $4214 : STA $14
	LDA $4216 : STA $12
	LDA $09C4 : STA $4204
	SEP #$20
	LDA #$64 : STA $4206
	PHA : PLA : PHA : PLA : REP #$30
	TDC : TAY : LDA $4214 : INC : STA $16
	
LOOP_ETANKS:
	DEC $16
	BEQ BRANCH_ETANKS_END
	LDA #$3430
	DEC $14
	BMI +
	LDA #$2831
	
+	LDX $9CCE,y
	STA $7EC608,x
	INY : INY
	CPY #$001C
	BMI LOOP_ETANKS
	
BRANCH_ETANKS_END:	;warning, this code takes up the exact amount of space needed
					;for this label to line up with where it is in vanilla.
}
	
;print "main routine overwrite end", pc
warnpc $809BEF

org $809BFB;vanilla branch destination
BRANCH_HEALTH_END:

org $80998B;overwrite now-unused vanilla reserve HUD tilemaps
;Transfers one word from ROM,y to RAM,x.
;This is where the XOR operation happens.
TransferNextVal:;Also increments X and Y
	LDA Data,y : EOR $14 : STA $7EC618,x
	INY : INY : INX : INX : RTS
	
;Adjust X (register) for writing to next vertical line on HUD
NextRowX:
	TXA : CLC : ADC #$003C : TAX : RTS
	
;print "auto reserve tilemap overwrite end", pc
warnpc $8099A4



