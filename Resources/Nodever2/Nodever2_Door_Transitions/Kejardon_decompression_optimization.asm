lorom
org $80B0FF
Decompress:
{
; Kej's decompression w/ fixes from Maddo
LDA $02, S
STA $45
LDA $01, S
STA $44
CLC
ADC #$0003
STA $01, S
LDY #$0001
LDA [$44], Y
STA $4C
INY
LDA [$44], Y
STA $4D

PHP
PHB
SEP #$20
REP #$10
LDA $49
PHA
PLB
STZ $50
LDY #$0000
BRA .NextByte

.End
PLB
PLP
RTL

.NextByte
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
STA $4A
CMP #$FF
BEQ .End
CMP #$E0
BCC ++
ASL A
ASL A
ASL A
AND #$E0
PHA
LDA $4A
AND #$03
XBA
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
BRA +++

++
AND #$E0
PHA
TDC
LDA $4A
AND #$1F

+++
TAX
INX
PLA
BMI .Option4567
BEQ .Option0
CMP #$20
BEQ .BRANCH_THETA
CMP #$40
BEQ .BRANCH_IOTA
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
-
STA [$4C], Y
INC A
INY
DEX
BNE -
JMP .NextByte

.Option0
-
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
STA [$4C], Y
INY
DEX
BNE -
JMP .NextByte

.BRANCH_THETA
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
-
STA [$4C], Y
INY
DEX
BNE -
JMP .NextByte

.BRANCH_IOTA
REP #$20 : TXA : LSR : TAX : SEP #$20 ; PJ: X /= 2 and set carry if X was odd

LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
XBA
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
XBA
INX
DEX
BEQ ++
REP #$20

-
STA [$4C], Y
INY
INY
DEX
BNE -

SEP #$20

++
BCC + : STA [$4C], Y : INY : + ; PJ: If carry was set, store that last byte

JMP .NextByte

.Option4567
CMP #$C0
AND #$20
STA $4F
BCS +++
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
XBA
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
XBA
REP #$21
ADC $4C
STY $44
SEC

--
SBC $44
STA $44
SEP #$20
LDA $4E
BCS +
DEC

+
STA $46
LDA $4F
BNE +

-
LDA [$44], Y
STA [$4C], Y
INY
DEX
BNE -
JMP .NextByte

+
-
LDA [$44], Y
EOR #$FF
STA [$4C], Y
INY
DEX
BNE -
JMP .NextByte

+++
TDC
LDA ($47)
INC $47
BNE +
JSR .IncrementBank2

+
REP #$20
STA $44
LDA $4C
BRA --


.IncrementBank2
INC $48
BNE +
PHA
PHB
PLA
INC A
PHA
PLB
LDA #$80
STA $48
PLA

+
RTS
}
