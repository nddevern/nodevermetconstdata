lorom

; So far, only transitions with Samus moving from left to right are modified. And only the speed of the scrolling is changed.
; There are a lot more edits I'd like to do... Namely - Figure out a way to load music in the background(?) and start doing so while the door is scrolling(?), align the screen during the fadeout.
; When I release this, release two preset: vanilla, faster (my preferred settings), fastest (as fast as it can go).

; When I'm done i'd like to showcase the following patches side by side: the 3 variations of mine, vanilla, project base, redesign, and the kazuto hex tweaks.
; should test all kinds of doors - big rooms, little rooms, rooms with/without music transitions, etc...

math round off
math pri on

; by Nodever2 October 2025
; Please give credit if you use this patch.
; Works with Asar (written with metconst fork of asar 1.90), not xkas.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !FreespaceAnywhere = $B88000
    !FreespaceAnywhereEnd = $B8FFFF
    !TransitionLength = $0040 ; How long the door transition screen scrolling will take, in frames. Vanilla: 0040h (basically). Should be at least 18h - I get graphical glitches when going any faster for some reason.
                              ; Note: We generate a lookup table !TransitionLength entries long, so the larger the number, the more freespace used.
    !ScreenFadeSpeed = #$0004 ; Higher = slower

    ; Vanilla variables
    !RamDoorTransitionFunctionPointer = $099C
    !RamGameState = $0998
    !RamDoorTransitionFrameCounter = $0925 ; for horizontal doors, 0 to !TransitionLength. vertical, 0 to !TransitionLength-1...
    !RamLayer1XPosition = $0911
    !RamLayer2XPosition = $0917
    !RamSamusXPosition = $0AF6
    !RamSamusXSubPosition = $0AF8
    !RamSamusPrevXPosition = $0B10

    ; new variables - can repoint the ram that these use
    !RamBank                  = $7F0000
    !RamStart                #= $FB46+!RamBank
    !RamLayer1StartPos       #= !RamStart+2
    !RamLayer2StartPos       #= !RamLayer1StartPos+2
    !RamSubtractFlag         #= !RamLayer2StartPos+2 ; 0000 = add, 8000 = subtract
    !RamEnd                   = !RamSubtractFlag

    org !RamStart         : print "First used byte of RAM:              $", pc
    org !RamEnd           : print "First free RAM byte after RAM Usage: $", pc
    org !RamEnd-!RamStart : print "RAM bytes used:                     0x", pc
}

; ====================================
; ============== NOTES  ==============
; ====================================
; Door transition code is in $82
; H Door transition starts at 94:93B8 (collision with door BTS) and starts with:
;  !RamGameState = 9 (E169 - door transition - delay)
;  !RamDoorTransitionFunctionPointer = E17D HandleElevator

org $82D961 : LDA !ScreenFadeSpeed  

org $80AD5A : JSL SetupScrolling

org $80AEB5 : CPX #!TransitionLength

; ==============================================
; ============== DOOR TRANSITIONS ==============
; ==============================================
{
    ; Scrolling right
    org $80AE7E
        LDX $0925 : PHX
        LDA #$0000 : STA !RamSamusXSubPosition
        LDA !RamLayer1XPosition : CLC : ADC #$0040 : STA !RamSamusXPosition : STA !RamSamusPrevXPosition
        JSL BezierTest
        BRA Continue
    warnpc $80AEAC
    org $80AEAC
        Continue:

    org !FreespaceAnywhere
    SetupScrolling:
        SEC : SBC #$0100 : STA !RamLayer1XPosition : PHA ; Instructions replaced by hijack
        PHP : REP #$30
        LDA $0791 : AND #$0003 : BNE +
        ; If scrolling right: Setup my custom vars
        LDA !RamLayer1XPosition : STA !RamLayer1StartPos
        LDA !RamLayer2XPosition : STA !RamLayer2StartPos

    +   PLP : PLA : RTL

    ; Scrolls the screen. This function is expected to be called every frame until this function returns carry set
    BezierTest:
        PHP : PHA
        REP #$30
        LDA !RamDoorTransitionFrameCounter : CMP #!TransitionLength-1 : BMI .continue
        LDA !RamLayer1StartPos : CLC : ADC #$0100 : STA !RamLayer1XPosition
        LDA !RamLayer2StartPos : CLC : ADC #$0100 : STA !RamLayer2XPosition
        PLA : PLP : RTL
    .continue
        PHX : PHB
        PHK : PLB ; DB = current bank
        LDX !RamDoorTransitionFrameCounter
        LDA .lookupTable,x : AND #$00FF : BNE + : INC : + : PHA
        CLC : ADC !RamLayer1StartPos : STA !RamLayer1XPosition
        PLA
        CLC : ADC !RamLayer2StartPos : STA !RamLayer2XPosition


        PLB : PLX
        PLA : PLP : RTL

    ; The ultimate cheat code: Making the assembler do all the work.
    ; Generate lookup table for bezier curve from 0 to 100, with !TransitionLength entries.
    ;   Got the formula from here: https://stackoverflow.com/questions/13462001/ease-in-and-ease-out-animation-formula
    ;   Which is: return (t^2)*(3-2t); // Takes in t from 0 to 1, returns a value from 0 to 1
    ;   To make it return a value from 0 to 100h, multiply the result by 100h (100h is how many pixels the screen has to move in a door transition)
    ;   To make it take in t from 0 to !TransitionLength, divide all instances of t by !TransitionLength
    ;   Thus: return 100h*((t/!TransitionLength)^2)*(3-2(t/!TransitionLength))
    .lookupTable:
    macro generateLookupTableEntry(t)
        db $100*((<t>/!TransitionLength)**2)*(3-2*(<t>/!TransitionLength))
    endmacro
    print "BezierTest_lookupTable: ", pc
    !tCounter = 0
    while !tCounter < !TransitionLength
        %generateLookupTableEntry(!tCounter)
        !tCounter #= !tCounter+1
    endwhile

    ;SixteenBitDivison:
    ;    ; Divides 16-bit X by 16-bit A
    ;    ; Result in $12 with remainder in X
    ;    PHY
    ;    STZ $12
    ;    LDY #$0001
;
    ;-   ASL
    ;    BCS +
    ;    INY
    ;    CPY #$0011
    ;    BNE -
;
    ;+   ROR
;
    ;-   PHA
    ;    TXA
    ;    SEC
    ;    SBC $01,s
    ;    BCC +
    ;    TAX
;
    ;+   ROL $12
    ;    PLA
    ;    LSR
    ;    DEY
    ;    BNE -
;
    ;    PLY : RTS
    ;    ;P.JBoy — 5/22/2025 3:19 PM
    ;    ;I ripped that one off from the "Programming the 65816" book

    
}