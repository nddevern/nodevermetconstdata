lorom

math round off
math pri on

; roadmap/ideas:
; 1.0:
;  - parity with vanilla door transition functionality but with better/faster animation and customizability
;  - fix layer 2 bugs (see green brin fireflea room)
;  - fix dma flickering
;  - figure out a way to make the patch error out or report if the speed is too high
; 1.1:
;  - place doors anywhere on screen a-la "door glitch fix" https://metroidconstruction.com/resource.php?id=44
;  - place door transition tiles as close to the edge of the screen as you want
; 1.2:
;  - customization option to allow an option to NOT align the screen - could push this back to 1.1. this would be useful for rooms with a continuous wall of door transition tiles on the edge - i.e. outdoor rooms
; 1.x:
;  - async music loading a-la https://github.com/tewtal/sm_practice_hack/blob/4d6358f022b5a0d092419dd06a3b60c2bd27927a/src/menu.asm#L283 - look for the quickboot_spc_state stuff

; Nodever2's door transitions
;   By now, several of us have rewritten door transitions - this is my take on it.

; When I'm done i'd like to showcase the following patches side by side: the 3 variations of mine, vanilla, project base, redesign, and the kazuto hex tweaks.
; should test all kinds of doors - big rooms, little rooms, rooms with/without music transitions, misalignments, etc...

; by Nodever2 October 2025
; Works with Asar (written with metconst fork of asar 1.90), won't work with xkas
; Please give credit if you use this patch.

; This patch was also made possible by:
;  * NobodyNada                       - Developer of asynchronous music transfer code
;  * Kejardon, with bugfix from Maddo - Developer of Decompression Optimization
;  * P.JBoy                           - Custodian of the commented Super Metroid bank logs

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !Freespace80           = $80CD8E
    !Freespace80End        = $80FFC0
    !Freespace82           = $82F70F ; keep in mind there is space at $E310 still
    !Freespace82End        = $82FFFF
    !FreespaceAnywhere     = $B88000 ; Anywhere in banks $80-$BF
    !FreespaceAnywhereEnd  = $B8FFFF
    !ScreenFadeDelay       = #$0004  ; Controls how fast the screen fades to/from black. Higher = slower. Vanilla: #$000C
    !TransitionLength      = $002C   ; How long the door transition screen scrolling will take, in frames. Vanilla: 0040h (basically). Should be at least 18h - I get graphical glitches when going any faster for some reason.
                                     ;     Note: We generate a lookup table !TransitionLength entries long, so the larger the number, the more freespace used.
    !TransitionAnimation        = 2  ; Affects how the screen moves when the door is not aligned to the middle of the screen. Both animations accelerate and decelerate smoothly.
                                     ;     1: make the screen move in a straight line toward it's destination (alignment completes when transition is 100% complete).
                                     ;     2: make the screen move in a curve toward it's destination (alignment completes when transition is 50% complete).
                                     ;     2: make the screen move in a curve toward it's destination (alignment completes when transition is 25% complete).
    !ReportFreespaceAndRamUsage = 1  ; Set to 0 to stop this patch from printing it's freespace and RAM usage to the console when assembled.
    !ScreenFadesOut             = 1  ; Set to 0 to make the screen not fade out during door transitions. This was useful for testing this patch, but it looks unpolished, not really suitable for a real hack.
    !VanillaCode                = 0  ; Set to 1 to compile the vanilla door transition code instead of mine. Was useful for debugging.

    ; Constants - don't touch
    !FreespaceAnywhereReportStart := !FreespaceAnywhere
    !Freespace80ReportStart := !Freespace80
    !Freespace82ReportStart := !Freespace82

    ; Vanilla variables
    !RamDoorTransitionFunctionPointer = $099C
    !RamGameState                     = $0998
    !RamDoorTransitionFrameCounter    = $0925 ; for horizontal doors, 0 to !TransitionLength. vertical, 0 to !TransitionLength-1...
    !RamLayer1XPosition               = $0911
    !RamLayer1XSubPosition            = $090F
    !RamLayer1YPosition               = $0915
    !RamLayer1YSubPosition            = $0913
    !RamLayer1XDestination            = $0927
    !RamLayer1YDestination            = $0929
    !RamLayer2XPosition               = $0917
    !RamLayer2YPosition               = $0919
    !RamSamusXPosition                = $0AF6
    !RamSamusYPosition                = $0AFA
    !RamSamusYRadius                  = $0B00
    !RamSamusXSubPosition             = $0AF8
    !RamSamusPrevXPosition            = $0B10
    !RamSamusPrevYPosition            = $0B14
    !RamPreviousLayer1YBlock          = $0901
    !RamPreviousLayer2YBlock          = $0905
    !RamRoomWidthInBlocks             = $07A5
    !RamCurrentBlockIndex             = $0DC4
    !RamDoorBts                       = $078F
    !RamLevelDataArray                = $7F0002 ; 1 word per block. High 4 bits = block type.
    !RamBtsArray                      = $7F6402 ; 1 byte per block
    !RamDoorDirection                 = $0791
    ;{
    ;    0: Right
    ;    1: Left
    ;    2: Down
    ;    3: Up
    ;    +4: Close a door on next screen
    ;}

    ; new variables - can repoint the ram that these use
    !RamBank                                      = $7F0000
    !RamStart                                    #= $FB46+!RamBank
    !CurRamAddr                                  := !RamStart
    
    !RamLayer1XStartPos                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamLayer2XStartPos                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraXTableIndex                        := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamLayer2XDestination                       := !CurRamAddr : !CurRamAddr := !CurRamAddr+2

    !RamLayer1YStartPos                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamLayer2YStartPos                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraYTableIndex                        := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamLayer2YDestination                       := !CurRamAddr : !CurRamAddr := !CurRamAddr+2

    !RamHDoorTopBlockYPosition                   := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    

    !RamEnd                                      := !CurRamAddr
    undef "CurRamAddr"
}

; ====================================
; ============== NOTES  ==============
; ====================================
{
    ; Door transition code is in $82
    ; H Door transition starts at 94:93B8 (collision with door BTS) and starts with:
    ;  !RamGameState = 9 (E169 - door transition - delay)
    ;  !RamDoorTransitionFunctionPointer = E17D HandleElevator

    ; PJ had a comment indicating that this might help in some way but so far I haven't seen a consequence for it.
    ;org $80A44E : LDX #$0000

    ; more notes on scrolling routine
    ; $08F7 - layer 1 X block
    ; $0990 - blocks to update X block - this is the X coordinate of the column in layer 1 RAM we'll update. Basically just layer 1 X block, but if we're scrolling right, add 10h to it.
    ; $0907 - BG1 X block. Current X coordinate in BG1, in blocks. Apparently this can just keep increasing. The actual X coordinate in the tilemap viewer is this % 20h in normal gameplay.
    ; $0994 - Blocks to update X block. Basically just BG1 X block, but if we're scrolling right, it's BG1 X block + 10h.

    ; Y blocks work the same way. BG1 Y block % 10h unlike BG1 X block which is % 20h.

    ; it looks like BG1 X block got incremented while Layer1XBlock did not within a frame
    ; This is because BG1XScroll and Layer1XPosition are out of sync by 1 pixel
    ; $B1   - BG1 X Scroll (pixels)
    ; $0911 - Layer 1 X position (pixels)

    ; so we recalculate BG1 X scroll based on layer 1 X pos every time we call the scrolling routine ($80A37B)
    ; HOWEVER, the offset between the two ($091D) somehow ended up with a 1 in it
}

; ====================================
; ============== MACROS ==============
; ====================================
{
    ; The ultimate cheat code: Making the assembler do all the work.
    ; Generate lookup table for bezier curve from 0 to 100, with !TransitionLength entries.
    ;   Got the formula from here: https://stackoverflow.com/questions/13462001/ease-in-and-ease-out-animation-formula
    ;   Which is: return (t^2)*(3-2t); // Takes in t from 0 to 1, returns a value from 0 to 1
    ;   To make it return a value from 0 to 100h, multiply the result by 100h (100h is how many pixels the screen has to move in a door transition)
    ;   To make it take in t from 0 to !TransitionLength, divide all instances of t by !TransitionLength
    ;   Thus: return 100h*((t/!TransitionLength)^2)*(3-2(t/!TransitionLength))
    macro generateLookupTableEntry(t)
        db $100*((<t>/!TransitionLength)**2)*(3-2*(<t>/!TransitionLength))
    endmacro
}

; =======================================
; ============== GAME INIT ==============
; =======================================
{
    ; We need to initialize these ram values we are using on game start, as the game does not do this by default.
    org $808432
        JSR InitRamOnBoot

    ORG $80A085
        JSR InitRamOnGameStart

    ORG !Freespace80
    InitRamOnGameStart:
        STZ $07E9 ; instruction replaced by hijack
    InitRam:
        PHP : REP #$30
        PHA : PHX : LDA #$0000
        LDX #!RamStart
    -   STA !RamBank,x
        INX : INX
        CPX #!RamEnd : BMI -
        PLX : PLA : PLP : RTS
    InitRamOnBoot:
        LDA #$0000 : TCD : PHK : PLB : SEP #$30 ; instruction replaced by hijack
        BRA InitRam
        .freespace
    !Freespace80 := InitRamOnBoot_freespace
    warnpc !Freespace80End
}

; =======================================================
; ============== SCREEN FADE TO/FROM BLACK ==============
; =======================================================
{
    if !ScreenFadesOut == 0
        org $82E2DB : LDA #$E2F7 : STA !RamDoorTransitionFunctionPointer : JMP $E2F7
    endif

    org $82D961 : LDA !ScreenFadeDelay
}

if !VanillaCode == 0
; ===================================================
; ============== DOOR TRANSITION SETUP ==============
; ===================================================
{
    ; skip door transition function scroll screen to alignment phase - we now align screen during main scrolling
    org $82E30F
    DoorTransitionFunctionScrollScreenToAlignment: {
        ; we still need to calculate BG scrolls because fucking earthquakes.
        ; why this is needed:
        ; earthquakes oscillate the BG1 X/Y scroll values
        ; then in vanilla the screen scroll to alignment phase of door transitions is more than likely clearing out whatever offset it had from earthquakes
        ; then when we recalculate scroll offset it's all good

        ; but since I skipped the scroll to aligment phase...
        ; when we recalculate offset between layer 1 pos and bg1 scroll ($80AE29), it has an extra 1 in there from earthquakes
        ; which basically just fucks everything up, as if these are desynced we will get graphical glitches constantly
        ; from loading in the wrong tiles...
            JSR $A34E ; Calculate BG scrolls
            LDA #$E353 : STA $099C : JMP $E353
        .freespace
    }
    warnpc $82E353

    org $80ADFB : DEC !RamPreviousLayer1YBlock : DEC !RamPreviousLayer2YBlock ; This was necessary for vertical doors moving upwards to render the top row of tiles. For some reason.

    ; Mod the vanilla main vertical scrolling routines, so that all they do is draw the top row of tiles and return - now they are just used once each for setup
    org $80AF06 : NOP #2          ; Down
    org $80AF42 : PLX : CLC : RTS : VanillaDownScrollingRoutineEnd:
    org $80AF8D : NOP #2          ; Up
    org $80AFC9 : PLX : CLC : RTS : VanillaUpScrollingRoutineEnd:

    org $80AD1D
    DrawTopRowOfScreenForUpwardsTransition: {
            STZ !RamDoorTransitionFrameCounter
            JSR $AF89 ; Vanlla door transition scrolling - up
            RTL
    }
    DrawTopRowOfScreenForDownwardsTransition: {
            STZ !RamDoorTransitionFrameCounter
            JSR $AF02 ; Vanilla door transition scrolling - down
            RTL
    }
    warnpc $80AD30

    org $80AD30
    DoorTransitionScrollingSetup: {
            REP #$30
            JSR InitializeLayer2Destinations ; This overwrites layer 1 positions but those will be corrected immediately after this
            LDA !RamDoorDirection : AND #$0003 : ASL : TAX
            JSR ($AE08,x) : RTL
    }
    warnpc $80AD4A

    org $80AD4A : JSR DoorTransitionScrollingHorizontalSetup ;) Right
    org $80AD70 : JSR SetupScrolling                         ;/

    org $80AD74 : JSR DoorTransitionScrollingHorizontalSetup ;) Left
    org $80AD9A : JSR SetupScrolling                         ;/

    org $80AD9E : JSR DoorTransitionScrollingVerticalSetup   ;) Down
    org $80ADC4 : JSR SetupScrolling                         ;/

    org $80ADC8 : JSR DoorTransitionScrollingVerticalSetup   ;) Up
    org $80AE04 : JSR SetupScrolling                         ;/

    org VanillaDownScrollingRoutineEnd ; newly free space
    DoorTransitionScrollingHorizontalSetup: {
            LDA !RamLayer1XDestination : STA !RamLayer1XPosition ; This is what vanilla does - we will later offset this after returning

            LDA !RamLayer1YPosition : AND #$00FF : CLC : ADC !RamLayer1YDestination : PHA
            LDA !RamLayer1YPosition-1 : BIT #$FF00 : BPL +
            LDA $01,s : SEC : SBC #$0100 : STA $01,s
        +   PLA : STA !RamLayer1YPosition
            JSR $A2F9 ; Instruction replaced by hijack
            RTS
        .freespace
    }
    warnpc $80AF89

    org VanillaUpScrollingRoutineEnd ; newly free space
    DoorTransitionScrollingVerticalSetup: {
            LDA !RamLayer1YDestination : STA !RamLayer1YPosition ; This is what vanilla does - we will later offset this after returning

            LDA !RamLayer1XPosition : AND #$00FF : CLC : ADC !RamLayer1XDestination : PHA
            LDA !RamLayer1XPosition-1 : BIT #$FF00 : BPL +
            LDA $01,s : SEC : SBC #$0100 : STA $01,s
        +   PLA : STA !RamLayer1XPosition
            JSR $A2F9 ; Instruction replaced by hijack
            RTS
    }
    
    SetupScrolling: {
            PHP : REP #$30
            LDA !RamLayer1XPosition : STA !RamLayer1XStartPos
            LDA !RamLayer1YPosition : STA !RamLayer1YStartPos
            LDA !RamLayer2XPosition : STA !RamLayer2XStartPos
            LDA !RamLayer2YPosition : STA !RamLayer2YStartPos
            LDA #$0000
            STA !RamCameraXTableIndex
            STA !RamCameraYTableIndex
            JSR MainScrollingRoutine ; Instruction replaced by hijack (effectively) - Run main scrolling routine once
            PLP : RTS
        .freespace
    }
    warnpc $80B032

    org !Freespace80
    InitializeLayer2Destinations: {
            LDA !RamLayer1XPosition : PHA
            LDA !RamLayer1YPosition : PHA
            LDA !RamLayer1XDestination : STA !RamLayer1XPosition
            LDA !RamLayer1YDestination : STA !RamLayer1YPosition
            LDA !RamDoorDirection : AND #$0003 : CMP #$0003 : BNE +
            LDA $80ADEF+1 : CLC : ADC !RamLayer1YPosition : STA !RamLayer1YPosition ; I hate vertical doors
        +   JSR CalculateLayer2Position
            LDA !RamLayer2XPosition : STA !RamLayer2XDestination
            LDA !RamLayer2YPosition : STA !RamLayer2YDestination
            PLA : STA !RamLayer1YPosition
            PLA : STA !RamLayer1XPosition
            RTS
        .freespace
    }
    !Freespace80 := InitializeLayer2Destinations_freespace
    warnpc !Freespace80End
    
}

; =======================================================
; ============== DOOR TRANSITION SCROLLING ==============
; =======================================================
{
    org $80A3A0 : CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling:
    org $80AE5C : JSR MainScrollingRoutine
    org $80AE7E
    ; Called every frame during main scrolling. Returns carry set when done.
    MainScrollingRoutine: {
            LDA !RamDoorTransitionFrameCounter

            BNE +
            LDA !RamDoorDirection : AND #$0003 : CMP #$0002 : BNE +
            ; Seemingly, if we run this, we need to return and wait for next frame to actually scroll.
            ; Seems like the engine can only DMA 1 horizontal row of tiles onto the screen per frame.
            ; $0968 was getting overwritten when I tried to continue after this call. $808DAC executes the DMA.
            JSL DrawTopRowOfScreenForDownwardsTransition : INC !RamDoorTransitionFrameCounter : CLC : RTS
        +

            JSL ScrollCameraX : PHP
            JSL ScrollCameraY : PHP

            JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
            INC !RamDoorTransitionFrameCounter
            PLP : BCC +
            PLP : BCC ++
            JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling ; ; why do we call this twice? didn't really observe any effects from commenting this out (yet)
            SEC : RTS
        +   PLP : ++ : CLC : RTS
    }

    CalculateLayer2Position: {
            JSR $A2F9 ; X
            JSR $A33A ; Y
            RTS
    }
    warnpc $80AF02

    org !FreespaceAnywhere
    ; forgive me father for I have sinned
    ; Put all variables that ScrollCamera uses on the stack, so we can reuse the code for X and Y.
    ; Since all of this is being done in an interrupt, we don't want to use misc RAM because that could
    ;  disrupt other code.
    ScrollCameraX: {
            LDA !RamLayer2XStartPos : PHA
            LDA #$0000 : PHA : LDA !RamDoorDirection : BIT #$0002 : BNE + : PLA : INC : PHA ; tPrimaryDirectionFlag
        +   LDA !RamCameraXTableIndex : PHA
            LDA !RamLayer2XDestination : PHA
            LDA !RamLayer2XPosition : PHA
            LDA #$0000 : PHA : LDA !RamLayer1XDestination : SEC : SBC !RamLayer1XStartPos : BPL + : PLA : INC : PHA ; tInvertDirectionFlag
        +   LDA !RamLayer1XDestination : PHA
            LDA !RamLayer1XPosition : PHA
            LDA !RamLayer1XStartPos : PHA
            JSR ScrollCamera ; Need to maintain the carry bit after this subroutine
            PLA ;: STA !RamLayer1XStartPos; no need to write back
            PLA : STA !RamLayer1XPosition
            PLA ;: STA !RamLayer1XDestination
            PLA ; tInvertDirectionFlag
            PLA : STA !RamLayer2XPosition
            PLA ; !RamLayer2XDestination
            PLA : STA !RamCameraXTableIndex
            PLA ; tPrimaryDirectionFlag
            PLA ; !RamLayer2XStartPos
            RTL
    }
    
    ScrollCameraY: {
            LDA !RamLayer2YStartPos : PHA
            LDA #$0000 : PHA : LDA !RamDoorDirection : BIT #$0002 : BEQ + : PLA : INC : PHA ; tPrimaryDirectionFlag
        +   LDA !RamCameraYTableIndex : PHA
            LDA !RamLayer2YDestination : PHA
            LDA !RamLayer2YPosition : PHA
            LDA #$0000 : PHA : LDA !RamLayer1YDestination : SEC : SBC !RamLayer1YStartPos : BPL + : PLA : INC : PHA ; tInvertDirectionFlag
        +   LDA !RamLayer1YDestination : PHA
            LDA !RamLayer1YPosition : PHA
            LDA !RamLayer1YStartPos : PHA
            JSR ScrollCamera ; Need to maintain the carry bit after this subroutine
            PLA ;: STA !RamLayer1YStartPos; no need to write back
            PLA : STA !RamLayer1YPosition
            PLA ;: STA !RamLayer1YDestination
            PLA ; tInvertDirectionFlag
            PLA : STA !RamLayer2YPosition
            PLA ; !RamLayer2YDestination
            PLA : STA !RamCameraYTableIndex
            PLA ; tPrimaryDirectionFlag
            PLA ; !RamLayer2YStartPos
            RTL
    }

    EightBitMultiplication: ; stolen from https://www.nesdev.org/wiki/8-bit_Multiply and hacked into inefficiency by yours truly
    ;;
    ; Multiplies two 8-bit factors to produce a 16-bit product
    ; @param A one factor
    ; @param Y another factor
    ; @return 16 bit result in A
    ; Y gets clobbered
    !prodlo  = $26
    !factor2 = $27
        PHP
        REP #$30
        PHA
        LDA !prodlo : PHA : LDA $03,s
        SEP #$30
        ; Factor 1 is stored in the lower bits of prodlo; the low byte of
        ; the product is stored in the upper bits.
        LSR  ; prime the carry bit for the loop
        STA !prodlo
        STY !factor2
        LDA #0
        LDY #8
    .loop:
        ; At the start of the loop, one bit of prodlo has already been
        ; shifted out into the carry.
        BCC .noadd
        CLC
        ADC !factor2
    .noadd:
        ROR
        ROR !prodlo  ; pull another bit out for the next iteration
        DEY         ; inc/dec don't modify carry; only shifts and adds do
        BNE .loop
        STA !factor2
        REP #$30
        LDA !prodlo
        PLY : STY !prodlo
        PLY
        PLP
        RTS
    .endproc

    ScrollCamera: {
        ; Scrolls the screen. This function is expected to be called every frame until this function returns carry set
        ; Assumes REP#$30 before calling
        ; Parameters listed below:

        ; These defines account for the return addr on the stack, as well as PHP : PHX : PHA
        !tBaseStackOffset #= 1+2+1+2+2+2+1 ; stack is always 1, +2 for return addr, +1 for php, +2 for phx, +2 for pha, +2 for phy, +1 for phb
        !tStackOffset := !tBaseStackOffset
        !tLayer1StartPos                          = !tStackOffset+0,s
        !tLayer1Position                          = !tStackOffset+2,s
        !tLayer1Destination                       = !tStackOffset+4,s
        !tInvertDirectionFlag                     = !tStackOffset+6,s
        !tLayer2Position                          = !tStackOffset+8,s
        !tLayer2Destination                       = !tStackOffset+10,s
        !tCameraTableIndex                        = !tStackOffset+12,s
        !tPrimaryDirectionFlag                    = !tStackOffset+14,s
        !tLayer2StartPos                          = !tStackOffset+16,s

            PHP : PHX : PHY : PHA : PHB
            REP #$30
            
            LDA !tLayer1Destination : SEC : SBC !tLayer1StartPos : BPL + : EOR #$FFFF : INC : +
            TAY ; Y contains distance between start and end of transition
            
            LDA !tLayer1Position : CMP !tLayer1Destination : BEQ .finish
            LDA !tCameraTableIndex : CMP #!TransitionLength-1 : BMI .continue
        .finish
            LDA !tLayer1Destination : STA !tLayer1Position
            LDA !tLayer2Destination : STA !tLayer2Position
            PLB : PLA : PLY : PLX : PLP : SEC : RTS ; done
        .continue
            PHK : PLB ; DB = current bank
            LDA !tCameraTableIndex : TAX
            LDA .lookupTable,x : AND #$00FF : BNE + : INC : +
            PHA : !tStackOffset := !tBaseStackOffset+2
            
            ; $01,s contains the distance from the table
            ; check if we need to convert it to a %
            TYA : CMP #$0100 : BEQ +
            
            ; convert to a %
            ; the offset we need in the end (respecting order of operations):
            ;     layer 1 x pos = layer 1 x start pos + $01,s * (distance between start and end of transition) / 100h
            LDA $01,s : JSR EightBitMultiplication
            LSR #8
            STA $01,s
        +   
            LDA !tInvertDirectionFlag : BNE .invert
            LDA !tLayer1StartPos : CLC : ADC $01,s : STA !tLayer1Position
            LDA !tLayer2StartPos : CLC : ADC $01,s : STA !tLayer2Position
            BRA +
        .invert
            LDA !tLayer1StartPos : SEC : SBC $01,s : STA !tLayer1Position
            LDA !tLayer2StartPos : SEC : SBC $01,s : STA !tLayer2Position
        +   PLA : !tStackOffset := !tBaseStackOffset

            LDA !tCameraTableIndex : INC : STA !tCameraTableIndex
            if !TransitionAnimation == 2 || !TransitionAnimation == 3
                LDA !tPrimaryDirectionFlag : BNE +
                ; we are in the secondary direction, increment counter again to animate faster
                LDA !tCameraTableIndex
                INC
                if !TransitionAnimation == 3 : INC : endif
                STA !tCameraTableIndex
            +
            endif
        .return
            PLB : PLA : PLY : PLX : PLP : CLC : RTS ; return, not complete

        .lookupTable:
        !tCounter = 0
        while !tCounter < !TransitionLength
            %generateLookupTableEntry(!tCounter)
            !tCounter #= !tCounter+1
        endwhile

        .freespace
    }
    !FreespaceAnywhere := ScrollCamera_freespace
    warnpc !FreespaceAnywhereEnd
}

; =============================================================
; ============== SUPER METROID SCROLLING ROUTINE ==============
; =============================================================
{
    ; Need to patch $80A3DF to handle horizontal scrolling when the screen is at a negative Y pos.
    ; (this took a ton of digging to figure out that this was the problem and solution... heh...)

    ; layer 1
    org $80A407
        LDY $0909 : LDA $08F9 : JSR SetLayerYBlockHandleNegative
        JSR $A9DB : BRA +
    warnpc $80A416
    org $80A416 : +
    
    ; layer 2
    org $80A43F
        LDY $090D : LDA $08FD : JSR SetLayerYBlockHandleNegative
        JSR $A9D6 : BRA +
    warnpc $80A44E
    org $80A44E : +
    
    org DoorTransitionScrollingHorizontalSetup_freespace ; newly free space
    ; A: Layer 1/2 Y block
    ; Y: BG1/2 Y block
    ; PSR.N flag: Set based on A
    SetLayerYBlockHandleNegative: {
            BPL +
            LDA #$0000 : STA $0992 : STA $0996 : RTS
        +   STA $0992 : TYA : STA $0996 : RTS
        .freespace
    }
    warnpc $80AF89
}

; ======================================================================
; ============== DOOR TRANSITION LOADING - POSITION SAMUS ==============
; ======================================================================
{
    ;org $82E4C5 : JSL PositionSamus
    org $82E3CF : JSL PositionSamus : BRA SkipPlacingSamus
    org $82E3E2
        SkipPlacingSamus:

    org !FreespaceAnywhere
    PositionSamus: {
            ; move Samus to door cap position for now while I'm testing this. Actually I might just stick with this.
            PHX : PHP : PHB
            REP #$30

            ; first set Samus to correct screen
            LDA !RamLayer1XDestination : AND #$FF00 : PHA : LDA !RamSamusXPosition : AND #$00FF : ORA $01,s : STA !RamSamusXPosition : PLA
            LDA !RamLayer1YDestination : AND #$FF00 : PHA : LDA !RamSamusYPosition : AND #$00FF : ORA $01,s : STA !RamSamusYPosition : PLA

            ; then set her position on the screen
            LDA $0791   ;\
            ASL A       ;|
            CLC         ;|
            ADC #$E68A  ;) A = [$E68A + [door direction] * 2] (PLM ID)
            TAX         ;|
            LDA $0000,x ;/
            BNE .doorcap ; If door has door cap, use it's X and Y positions to set Samus
            ; else... make some assumptions.
        .nodoorcap
            LDA !RamDoorDirection : BIT #$0002 : BNE ..verticalTransition
        ..horizontalTransition
            LDA !RamLayer1XDestination : STA !RamSamusXPosition
            LDA !RamDoorDirection : BIT #$0001 : BEQ ...samusMovingRight
        ...samusMovingLeft
            LDA !RamSamusXPosition : CLC : ADC #$0100-$30 : STA !RamSamusXPosition
            BRA ..continue
        ...samusMovingRight
            LDA !RamSamusXPosition : CLC : ADC #$0030 : STA !RamSamusXPosition
            BRA ..continue
        ..verticalTransition
            LDA !RamLayer1YDestination : STA !RamSamusYPosition
            LDA !RamDoorDirection : BIT #$0001 : BEQ ...samusMovingDown
        ...samusMovingUp
            LDA !RamSamusYPosition : CLC : ADC #$0100-$1C : STA !RamSamusYPosition
            BRA ..continue
        ...samusMovingDown
            LDA !RamSamusYPosition : CLC : ADC #$0040 : STA !RamSamusYPosition
        ..continue
            BRA .finish

        .doorcap
            LDX $078D : LDA $830004,x : TAX ; X = [$83:0000 + [door pointer] + 4] (X and Y positions)
            LDA !RamDoorDirection : AND #$0003 : BIT #$0002 : BNE ..verticalTransition
        ..horizontalTransition
            LDA !RamLayer1XDestination : STA !RamSamusXPosition
            TXA : AND #$000F : ASL #4 : ORA !RamSamusXPosition : STA !RamSamusXPosition
            BRA .finish
        ..verticalTransition
            LDA !RamLayer1YDestination : STA !RamSamusYPosition
            TXA : XBA : AND #$000F : ASL #4 : ORA !RamSamusYPosition : STA !RamSamusYPosition
            LDA !RamDoorDirection : BIT #$0001 : BEQ ...samusMovingDown
        ...samusMovingUp
            LDA !RamSamusYPosition : SEC : SBC #$0038 : STA !RamSamusYPosition
            BRA .finish
        ...samusMovingDown
            LDA !RamSamusYPosition : CLC : ADC #$0010 : STA !RamSamusYPosition
        .finish
            LDA !RamSamusXPosition : STA !RamSamusPrevXPosition
            LDA !RamSamusYPosition : STA !RamSamusPrevYPosition
            ;JSL $89AB82 ; instruction replaced by hijack - Load FX header
            PLB : PLP : PLX : RTL
        .freespace
    }
    !FreespaceAnywhere := PositionSamus_freespace
    warnpc !FreespaceAnywhereEnd
}

; ==================================================================
; ============== DOOR TRANSITION VRAM UPDATE POSITION ==============
; ==================================================================
{   ; This section is to address the black flickering during the door transition - position it so that it never overlaps the door tube, under any circumstances.
    ; When Samus collides with a door tile, find the top door tile of the door that has been collided with:
    org $9493A7
        JSL FindTopOfDoor

    org !FreespaceAnywhere
    FindTopOfDoor: {
            PHY : PHX
            LDA !RamCurrentBlockIndex : PHA
            LDY #$0004 ; max # of blocks to check
        .loop
            LDA !RamCurrentBlockIndex : ASL : TAX
            LDA !RamLevelDataArray,x : AND #$F000 : CMP #$9000 : BNE .done ; If the block type is different, stop
            LDA !RamCurrentBlockIndex : TAX
            LDA !RamBtsArray,x : AND #$00FF : CMP !RamDoorBts : BNE .done  ; If the BTS is different, stop
        .found
            TXA : STA !RamHDoorTopBlockYPosition
            SEC : SBC !RamRoomWidthInBlocks : STA !RamCurrentBlockIndex
            DEY : BNE .loop
        .done
            ; RamHDoorTopBlockYPosition holds block index instead of the Y position. Convert it to Y pixel coordinate for later use.
            LDA !RamHDoorTopBlockYPosition                             ;\
            LDX #$FFFF                                                 ;) X = Y position of top of door tube, in blocks. (!RamHDoorTopBlockYPosition / !RoomWidthInBlocks)
        -   INX : SEC : SBC !RamRoomWidthInBlocks : BPL -              ;/
            TXA : ASL #4 : AND #$00FF : STA !RamHDoorTopBlockYPosition ; !RamHDoorTopBlockYPosition = Y position of door in pixels relative to the screen

            PLA : STA !RamCurrentBlockIndex
            PLX : PLY
            LDA $8F0000,x : RTL ; instruction replaced by hijack
        .freespace
    }
    !FreespaceAnywhere := FindTopOfDoor_freespace
    warnpc !FreespaceAnywhereEnd
    
    ; Low v-counter targets (high ones are at the end of HUD so no need to adjust them). Vanilla: A0h
    org $8097A2 : LDY #$00A0 ; vertical
    org $809803 : LDY #$00A0 ; horizontal

    org $809793
        JSR CheckIfVramUpdateNeeded_vertical_topOfScreen

    org $8097B4
        JSR CheckIfVramUpdateNeeded_vertical_bottomOfScreen

    org $8097FC
        JSR CheckIfVramUpdateNeeded_horizontal_topOfScreen
        NOP

    org $80980F
        JSR CheckIfVramUpdateNeeded_horizontal_bottomOfScreen
    
    org !Freespace80
    CheckIfVramUpdateNeeded: {
        .vertical
        ..topOfScreen
            LDA !RamLayer1YPosition : BMI + : AND #$00FF : + : CMP #$0090 : BPL +
            JSR $9632 ; Door tube is low - execute VRAM update now. (Caller already checked if it's needed.)
        +   RTS
        ..bottomOfScreen
            PHA ; need to preserve A here due to the routine we hijacked
            LDA !RamLayer1YPosition : BMI + : AND #$00FF : + : CMP #$0090 : BMI +
            ; Door tube is high - execute VRAM update now if needed.
            LDX $05BC : BPL + : JSR $9632
        +   PLA
            LDY #$0000 ; instruction replaced by hijack
            RTS

        .horizontal
        ..topOfScreen
            JSR ..compareYPosition : BMI +
            ; Door is low - move down if needed.
            LDX $05BC : BPL + : JSR $9632
        +   JSL $80AE4E ; instruction replaced by hijack - Door transition scrolling function
            RTS
        ..bottomOfScreen
            JSR ..compareYPosition : BPL +
            JSR $9632 ; Door is high - execute VRAM update now. (Caller already checked if it's needed.)
        +   RTS

        ..compareYPosition
            LDA !RamLayer1YPosition : SEC : SBC !RamLayer1YDestination
            PHA : LDA !RamHDoorTopBlockYPosition : SEC : SBC $01,s : PLX : CMP #$0060
            RTS

        .freespace
    }
    !Freespace80 := CheckIfVramUpdateNeeded_freespace
    warnpc !Freespace80End
}

; ========================================================
; ============== REPORT RAM/FREESPACE USAGE ==============
; ========================================================
{
    if !ReportFreespaceAndRamUsage == 1
        print "RAM usage:"
        org !RamStart         : print "  First used byte of RAM:              $", pc
        org !RamEnd           : print "  First free RAM byte after RAM Usage: $", pc
        org !RamEnd-!RamStart : print "  RAM bytes used:                     0x", pc
        print "Freespace usage:"
        print "  Bank $80:"
        org !Freespace80ReportStart              : print "    First used byte:             $", pc
        org !Freespace80                         : print "    First free byte after usage: $", pc
        org !Freespace80-!Freespace80ReportStart : print "    Bytes used:                 0x", pc
        print "  Bank $82:"
        org !Freespace82ReportStart              : print "    First used byte:             $", pc
        org !Freespace82                         : print "    First free byte after usage: $", pc
        org !Freespace82-!Freespace82ReportStart : print "    Bytes used:                 0x", pc
        print "  Any Bank $80-$BF:"
        org !FreespaceAnywhereReportStart                    : print "    First used byte:             $", pc
        org !FreespaceAnywhere                               : print "    First free byte after usage: $", pc
        org !FreespaceAnywhere-!FreespaceAnywhereReportStart : print "    Bytes used:                 0x", pc
    endif
}
endif
; For years, I've feared the door transitions.
; Now, door transitions fear me.
