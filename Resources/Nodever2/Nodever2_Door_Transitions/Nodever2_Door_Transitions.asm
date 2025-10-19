lorom

; todo: dont call the vanilla up scroll routine blindly lol
; fix bg2 position ?
; obv fix vertical door gap
; test doors on screen edges / etc - basically "door glitch fix" patch should either be compatible with mine or my code should also have that bug fixed
; can still have bugs esp if you enter a door too high - see transition from above into pre status hallway room (the one with missile pirates)
; also I think that maxspeed isn't strictly obeyed and the game can *technically* exceed it as it continues to accelerate for 1 frame past it. if you have high accel values this is a problem right?

; Nodever2's door transitions
;   By now, several of us have rewritten door transitions - this is my take on it.

; So far, only transitions with Samus moving from left to right and right to left are modified. And only the speed of the scrolling is changed.
; There are a lot more edits I'd like to do... Namely - Figure out a way to load music in the background(?) and start doing so while the door is scrolling(?), align the screen during the fadeout, remove any 1 frame delays between door state machine states.
; When I release this, release presets: same speed as vanilla, and faster (my preferred settings)

; When I'm done i'd like to showcase the following patches side by side: the 3 variations of mine, vanilla, project base, redesign, and the kazuto hex tweaks.
; should test all kinds of doors - big rooms, little rooms, rooms with/without music transitions, misalignments, etc...

; by Nodever2 October 2025
; Please give credit if you use this patch.
; Works with Asar (written with metconst fork of asar 1.90), probably won't work with xkas

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !FreespaceAnywhere     = $B88000 ; Anywhere in banks $80-$BF
    !FreespaceAnywhereEnd  = $B8FFFF
    !Freespace80           = $80CD8E
    !Freespace80End        = $80FFC0
    !ScreenFadeDelay       = #$0004  ; Controls how fast the screen fades to/from black. Higher = slower. Vanilla: #$000C
    !CameraAcceleration    = #$0001
    !CameraSubAcceleration = #$0000
    !CameraMaxSpeed        = #$000F  ; Should be 000F or less.
    !ReportFreespaceAndRamUsage = 1  ; Set to 0 to stop this patch from printing it's freespace and RAM usage to the console when assembled.
    !ScreenFadesOut             = 1  ; Set to 0 to make the screen not fade out during door transitions. This was useful for testing this patch, but it looks unpolished, not really suitable for a real hack.

    ; Vanilla-like settings:
    ; When these settings are used, the door transition takes almost exactly as long as vanilla.
    ; !ScreenFadeDelay       = #$000C
    ; !CameraAcceleration    = #$0000
    ; !CameraSubAcceleration = #$3000
    ; !CameraMaxSpeed        = #$000F

    ; My preferred settings:
    ; !ScreenFadeDelay       = #$0004
    ; !CameraAcceleration    = #$0001
    ; !CameraSubAcceleration = #$0000
    ; !CameraMaxSpeed        = #$000F

    ; Constants - don't touch
    !FreespaceAnywhereReportStart := !FreespaceAnywhere
    !Freespace80ReportStart       := !Freespace80

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
    !RamSamusXSubPosition             = $0AF8
    !RamSamusPrevXPosition            = $0B10
    !RamSamusPrevYPosition            = $0B14
    !RamPreviousLayer1YBlock          = $0901
    !RamPreviousLayer2YBlock          = $0905
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
    !RamCameraXSpeed                             := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraXSubSpeed                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraXState                             := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraXDistanceTraveledWhileAccelerating := !CurRamAddr : !CurRamAddr := !CurRamAddr+2

    !RamLayer1YStartPos                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraYSpeed                             := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraYSubSpeed                          := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraYState                             := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamCameraYDistanceTraveledWhileAccelerating := !CurRamAddr : !CurRamAddr := !CurRamAddr+2

    !RamEnd                                      := !CurRamAddr
    undef "CurRamAddr"
}

; ====================================
; ============== NOTES  ==============
; ====================================
; Door transition code is in $82
; H Door transition starts at 94:93B8 (collision with door BTS) and starts with:
;  !RamGameState = 9 (E169 - door transition - delay)
;  !RamDoorTransitionFunctionPointer = E17D HandleElevator

; PJ had a comment indicating that this might help in some way but so far I haven't seen a consequence for it.
;org $80A44E : LDX #$0000

; =======================================================
; ============== SCREEN FADE TO/FROM BLACK ==============
; =======================================================
{
    if !ScreenFadesOut == 0
        org $82E2DB : LDA #$E2F7 : STA !RamDoorTransitionFunctionPointer : JMP $E2F7
    endif

    org $82D961 : LDA !ScreenFadeDelay
}

; ===================================================
; ============== DOOR TRANSITION SETUP ==============
; ===================================================
{
    org $82E309 : LDA #$E353 ; skip door transition function scroll screen to alignment phase - we now align screen during main scrolling

    org $80AD30
    DoorTransitionScrollingSetup: {
            REP #$30
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

    org !Freespace80
    DoorTransitionScrollingHorizontalSetup: {
            LDA !RamLayer1XDestination : STA !RamLayer1XPosition ; This is what vanilla does

            LDA !RamLayer1YPosition : AND #$00FF : CLC : ADC !RamLayer1YDestination : PHA
            LDA !RamLayer1YPosition-1 : BIT #$FF00 : BPL +
            LDA $01,s : SEC : SBC #$0100 : STA $01,s
        +   PLA : STA !RamLayer1YPosition
            JSR $A2F9 ; Instruction replaced by hijack
            RTS
    }

    DoorTransitionScrollingVerticalSetup: {
            LDA !RamLayer1YDestination : STA !RamLayer1YPosition ; This is what vanilla does

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
            LDA #$0000
            STA !RamCameraXSpeed : STA !RamCameraXSubSpeed : STA !RamCameraXState : STA !RamLayer1XSubPosition
            STA !RamCameraYSpeed : STA !RamCameraYSubSpeed : STA !RamCameraYState : STA !RamLayer1YSubPosition
            JSR MainScrollingRoutine ; Instruction replaced by hijack (effectively)
            PLP : RTS
        .freespace
    }
    !Freespace80 := SetupScrolling_freespace
    warnpc !Freespace80End
}

; patching $80A3DF to handle horizontal scrolling when the screen is at a negative Y pos. (this took a ton of digging to figure out that this was the problem and solution... heh...)
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

org !Freespace80
; A: Layer 1/2 Y block
; Y: BG1/2 Y block
; PSR.N flag: Set based on A
SetLayerYBlockHandleNegative: {
        BPL +
        LDA #$0000 : STA $0992 : STA $0996 : RTS
    +   STA $0992 : TYA : STA $0996 : RTS
    .freespace
}

    !Freespace80 := SetLayerYBlockHandleNegative_freespace
    warnpc !Freespace80End


; This was necessary for vertical doors moving upwards to render the top row of tiles. For some reason.
org $80ADFB : DEC !RamPreviousLayer1YBlock : DEC !RamPreviousLayer2YBlock ; up

; =======================================================
; ============== DOOR TRANSITION SCROLLING ==============
; =======================================================
{
    org $80A3A0 : CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling:
    org $80AE5C : JSR MainScrollingRoutine
    org $80AE7E
    ; Called every frame during main scrolling.
    MainScrollingRoutine: {
            LDX !RamDoorTransitionFrameCounter : PHX

            BNE +
            LDA !RamDoorDirection : AND #$0003 : CMP #$0002 : BNE +
            JSR CalculateLayer2Position
            ; Seemingly, if we run this, we need to return and wait for next frame to actually scroll.
            ; Seems like the engine can only DMA 1 horizontal row of tiles onto the screen per frame.
            ; $0968 was getting overwritten when I tried to continue after this call. $808DAC executes the DMA.
            JSL DrawTopRowOfScreenForDownwardsTransition : PLX : INX : STX !RamDoorTransitionFrameCounter : CLC : RTS
        +

            JSL ScrollCameraX : PHP
            JSL ScrollCameraY : PHP

            JSR CalculateLayer2Position
            JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
            LDA $02,s : TAX : INX : STX !RamDoorTransitionFrameCounter
            PLP : BCC +
            PLP : BCC ++
            JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling ; ; why do we call this twice? didn't really observe any effects from commenting this out (yet)
            PLX : SEC : RTS
        +   PLP : ++ : PLX : CLC : RTS
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
            LDA !RamCameraXState : CMP #$0003 : BNE +
            SEC : RTL

        +   LDA #$0000 : PHA ; tInvertDirectionFlag = right
            LDA !RamLayer1XDestination : SEC : SBC !RamLayer1XPosition : BPL +
            PLA : INC : PHA ; left
        +   LDA !RamLayer1XDestination : PHA
            LDA !RamLayer1XPosition : PHA
            LDA !RamCameraXDistanceTraveledWhileAccelerating : PHA
            LDA !RamLayer1XSubPosition : PHA
            LDA !RamCameraXState : PHA
            LDA !RamCameraXSubSpeed : PHA
            LDA !RamCameraXSpeed : PHA
            LDA !RamLayer1XStartPos : PHA
            JSR ScrollCamera
            PLA ;: STA !RamLayer1XStartPos; no need to write back
            PLA : STA !RamCameraXSpeed
            PLA : STA !RamCameraXSubSpeed
            PLA : STA !RamCameraXState
            PLA : STA !RamLayer1XSubPosition
            PLA : STA !RamCameraXDistanceTraveledWhileAccelerating
            PLA : STA !RamLayer1XPosition
            PLA : STA !RamLayer1XDestination
            PLA ; tInvertDirectionFlag
            RTL
    }
    
    ScrollCameraY: {
            LDA !RamCameraYState : CMP #$0003 : BNE +
            SEC : RTL

        +   LDA #$0000 : PHA ; tInvertDirectionFlag = down
            LDA !RamLayer1YDestination : SEC : SBC !RamLayer1YPosition : BPL +
            PLA : INC : PHA ; up
        +   LDA !RamLayer1YDestination : PHA
            LDA !RamLayer1YPosition : PHA
            LDA !RamCameraYDistanceTraveledWhileAccelerating : PHA
            LDA !RamLayer1YSubPosition : PHA
            LDA !RamCameraYState : PHA
            LDA !RamCameraYSubSpeed : PHA
            LDA !RamCameraYSpeed : PHA
            LDA !RamLayer1YStartPos : PHA
            JSR ScrollCamera
            PLA ;: STA !RamLayer1YStartPos; no need to write back
            PLA : STA !RamCameraYSpeed
            PLA : STA !RamCameraYSubSpeed
            PLA : STA !RamCameraYState
            PLA : STA !RamLayer1YSubPosition
            PLA : STA !RamCameraYDistanceTraveledWhileAccelerating
            PLA : STA !RamLayer1YPosition
            PLA : STA !RamLayer1YDestination
            PLA ; tInvertDirectionFlag
            RTL
    }

    ScrollCamera: {
        ; Scrolls the screen. This function is expected to be called every frame until this function returns carry set
        ; Assumes REP#$30 before calling
        ; Parameters (before JSR return addr is pushed to stack):
        ; $01,s: tLayer1StartPos
        ; $03,s: tCameraSpeed
        ; $05,s: tCameraSubSpeed
        ; $07,s: tCameraState
        ; $09,s: tLayer1SubPosition
        ; $0B,s: tCameraDistanceTraveledWhileAccelerating
        ; $0D,s: tLayer1Position
        ; $0F,s: tLayer1Destination
        ; $11,s: tInvertDirectionFlag ; 0 for door moving right or down, nonzero for door moving left or up

        ; These defines account for the return addr on the stack, as well as PHP : PHX : PHA
        !tBaseStackOffset #= 1+2+1+2+2 ; stack is always 1, +2 for return addr, +1 for php, +2 for phx, +2 for pha
        !tLayer1StartPos                          = !tBaseStackOffset+0,s : !tLayer1StartPosAfterPha = !tBaseStackOffset+2,s
        !tCameraSpeed                             = !tBaseStackOffset+2,s
        !tCameraSubSpeed                          = !tBaseStackOffset+4,s
        !tCameraState                             = !tBaseStackOffset+6,s
        !tLayer1SubPosition                       = !tBaseStackOffset+8,s
        !tCameraDistanceTraveledWhileAccelerating = !tBaseStackOffset+10,s
        !tLayer1Position                          = !tBaseStackOffset+12,s : !tLayer1PositionAfterPha = !tBaseStackOffset+14,s
        !tLayer1Destination                       = !tBaseStackOffset+14,s
        !tInvertDirectionFlag                     = !tBaseStackOffset+16,s

            PHP : PHX : PHA
            REP #$30

            LDA !tCameraState : ASL : TAX : JMP (.cameraStateHandlers,x)
        .cameraStateHandlers:
            dw .accelerate, .move, .decelerate, .stop

            ; update speed then layer1 pos
            ; first check if camera needs to be accelerated
        .accelerate
            LDA !tCameraSpeed : CMP !CameraMaxSpeed : BPL ..stopAccelerating
            LDA !tLayer1Destination : SEC : SBC !tLayer1StartPos : BPL +++ : EOR #$FFFF : INC : +++
            LSR : PHA : LDA !tLayer1PositionAfterPha : SEC : SBC !tLayer1StartPosAfterPha : BPL +++ : EOR #$FFFF : INC : +++
            CMP $01,s : BPL ..stopAcceleratingWithPull : PLA ; stop accelerating if we're over halfway
            LDA !CameraSubAcceleration : CLC : ADC !tCameraSubSpeed : STA !tCameraSubSpeed ; continue accelerating
            LDA !CameraAcceleration : ADC !tCameraSpeed : STA !tCameraSpeed
            BRA .setPosition
        ..stopAcceleratingWithPull
            PLA
        ..stopAccelerating
            LDA !tCameraState : INC : STA !tCameraState
            LDA !tLayer1Position : SEC : SBC !tLayer1StartPos : BPL +++ : EOR #$FFFF : INC : +++
            STA !tCameraDistanceTraveledWhileAccelerating
        .move
            ; first, check if we need to start declerating
            LDA !tLayer1Destination : SEC : SBC !tLayer1Position : BPL +++ : EOR #$FFFF : INC : +++
            CMP !tCameraDistanceTraveledWhileAccelerating
            BEQ + : BPL .setPosition
            ; start decelerating
        +   LDA !tCameraState : INC : STA !tCameraState
            ;BRA .setPosition ; start decelerating next frame
        .decelerate
            LDA !tCameraSubSpeed : SEC : SBC !CameraSubAcceleration : STA !tCameraSubSpeed
            LDA !tCameraSpeed : SBC !CameraAcceleration : STA !tCameraSpeed
        .setPosition
            LDA !tInvertDirectionFlag : BNE ..invert
            LDA !tLayer1SubPosition : CLC : ADC !tCameraSubSpeed : STA !tLayer1SubPosition
            LDA !tLayer1Position : ADC !tCameraSpeed : STA !tLayer1Position
            BRA +
        ..invert
            LDA !tLayer1SubPosition : SEC : SBC !tCameraSubSpeed : STA !tLayer1SubPosition
            LDA !tLayer1Position : SBC !tCameraSpeed : STA !tLayer1Position
        +   
        .checkStop
            ; check if we need to stop
            LDA !tInvertDirectionFlag : BNE ..invert
            LDA !tLayer1Position : CMP !tLayer1Destination : BPL .stop : BRA +
        ..invert
            LDA !tLayer1Destination : CMP !tLayer1Position : BPL .stop
        +   LDA !tCameraSpeed : BMI .stop
            PLA : PLX : PLP : CLC : RTS
        .stop
            LDA #$0003 : STA !tCameraState ; camera state = stop
            LDA !tLayer1Destination : STA !tLayer1Position
            PLA : PLX : PLP : SEC : RTS
        .freespace
    }
    !FreespaceAnywhere := ScrollCamera_freespace
    warnpc !FreespaceAnywhereEnd

    ; Mod the vanilla vertical scrolling routines, so that all they do is draw the top layer and return
    org $80AF06 : NOP #2    ;) Down
    org $80AF42 : PLX : CLC : RTS ;/
    org $80AF8D : NOP #2    ;) Up
    org $80AFC9 : PLX : CLC : RTS ;/


    org $80AD1D
    DrawTopRowOfScreenForUpwardsTransition: {
            JSR $AF89 ; Door transition scrolling - up
            RTL
    }
    DrawTopRowOfScreenForDownwardsTransition: {
            JSR $AF02 ; Door transition scrolling - down
            RTL
    }
    warnpc $80AD30
}

; ======================================================================
; ============== DOOR TRANSITION LOADING - POSITION SAMUS ==============
; ======================================================================
{
    org $82E4C5 : JSL PositionSamus
    org $82E3CF : BRA SkipPlacingSamus
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
            JSL $89AB82 ; instruction replaced by hijack - Load FX header
            PLB : PLP : PLX : RTL
        .freespace
    }
    !FreespaceAnywhere := PositionSamus_freespace
    warnpc !FreespaceAnywhereEnd
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
        print "  Anywhere:"
        org !FreespaceAnywhereReportStart                    : print "    First used byte:             $", pc
        org !FreespaceAnywhere                               : print "    First free byte after usage: $", pc
        org !FreespaceAnywhere-!FreespaceAnywhereReportStart : print "    Bytes used:                 0x", pc
    endif
}

; For years, I've feared the door transitions.
; Now, door transitions fear me.
