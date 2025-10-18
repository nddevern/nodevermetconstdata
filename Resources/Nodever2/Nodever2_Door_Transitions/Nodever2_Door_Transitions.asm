lorom

; todo: dont call the vanilla up scroll routine blindly lol
; fix bg2 position ?
; obv fix vertical door gap

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
    !FreespaceAnywhere = $B88000
    !FreespaceAnywhereEnd = $B8FFFF
    !Freespace80 = $80CD8E
    !Freespace80End = $80FFC0
    !ScreenFadeSpeed = #$0004 ; Higher = slower
    !CameraAcceleration = #$0001
    !CameraSubAcceleration = #$0000
    !CameraMaxSpeed = #$000F ; Should be 000F or less.

    ; Vanilla variables
    !RamDoorTransitionFunctionPointer = $099C
    !RamGameState = $0998
    !RamDoorTransitionFrameCounter = $0925 ; for horizontal doors, 0 to !TransitionLength. vertical, 0 to !TransitionLength-1...
    !RamLayer1XPosition = $0911
    !RamLayer1XSubPosition = $090F
    !RamLayer1YPosition = $0915
    !RamLayer1YSubPosition = $0913
    !RamLayer1XDestination = $0927
    !RamLayer1YDestination = $0929
    !RamLayer2XPosition = $0917
    !RamLayer2YPosition = $0919
    !RamSamusXPosition = $0AF6
    !RamSamusYPosition = $0AFA
    !RamSamusXSubPosition = $0AF8
    !RamSamusPrevXPosition = $0B10
    !RamSamusPrevYPosition = $0B14
    !RamDoorDirection = $0791
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
    !CurrentRamAddress                           := !RamStart

    !RamLayer1XStartPos                          := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraXSpeed                             := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraXSubSpeed                          := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraXState                             := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraXDistanceTraveledWhileAccelerating := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2

    !RamLayer1YStartPos                          := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraYSpeed                             := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraYSubSpeed                          := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraYState                             := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2
    !RamCameraYDistanceTraveledWhileAccelerating := !CurrentRamAddress : !CurrentRamAddress := !CurrentRamAddress+2

    !RamEnd                                      := !CurrentRamAddress

    org !RamStart         : print "First used byte of RAM:              $", pc
    org !RamEnd           : print "First free RAM byte after RAM Usage: $", pc
    org !RamEnd-!RamStart : print "RAM bytes used:                     0x", pc
    undef "CurrentRamAddress"
}

; ====================================
; ============== NOTES  ==============
; ====================================
; Door transition code is in $82
; H Door transition starts at 94:93B8 (collision with door BTS) and starts with:
;  !RamGameState = 9 (E169 - door transition - delay)
;  !RamDoorTransitionFunctionPointer = E17D HandleElevator

org $82D961 : LDA !ScreenFadeSpeed 

; skip door transition function scroll screen to alignment phase
org $82E309 : LDA #$E353

; PJ had a comment indicating that this might help in some way but so far I haven't seen a consequence for it.
;org $80A44E : LDX #$0000

; door transiton scrolling setup
;org $80AD38 : NOP #6
org $80AD30
DoorTransitionScrollingSetup:
    REP #$30
    LDA !RamDoorDirection : AND #$0003 : ASL : TAX
    JSR ($AE08,x) : RTL
warnpc $80AD4A

org $80AD4A : JSR DoorTransitionScrollingHorizontalSetup
org $80AD74 : JSR DoorTransitionScrollingHorizontalSetup
org $80AD9E : JSR DoorTransitionScrollingVerticalSetup
org $80ADC8 : JSR DoorTransitionScrollingVerticalSetup

org $80AD70 : JSR SetupScrolling ; right
org $80AD9A : JSR SetupScrolling ; left
org $80ADC4 : JSR SetupScrolling ; down
org $80AE04 : JSR SetupScrolling ; up

org $82E915 : JSL SpawnDoorCap

; ==============================================
; ============== DOOR TRANSITIONS ==============
; ==============================================
{
    org $80AE5C : JSR Scrolling
    org $80AE7E
    Scrolling:
        LDX $0925 : PHX
        ;LDA #$0000 : STA !RamSamusXSubPosition
        ;LDA !RamLayer1XPosition : CLC : ADC #$0040 : STA !RamSamusXPosition : STA !RamSamusPrevXPosition

        JSR UpdateX : PHP
        JSR UpdateY : PHP

        JSR CalculateLayer2Position
        JSL $80A3A0
        LDA $02,s : TAX : INX : STX !RamDoorTransitionFrameCounter
        PLP : BCC +
        PLP : BCC ++
        JSL $80A3A0
        PLX : SEC : RTS
    +   PLP : ++ : PLX : CLC : RTS
    CalculateLayer2Position:
        JSR $A2F9 ; X
        JSR $A33A ; Y
        RTS
    warnpc $80AF02


    org !Freespace80
    SetupScrolling:
        PHP : REP #$30
        LDA !RamLayer1XPosition : STA !RamLayer1XStartPos
        LDA !RamLayer1YPosition : STA !RamLayer1YStartPos
        LDA #$0000
        STA !RamCameraXSpeed : STA !RamCameraXSubSpeed : STA !RamCameraXState : STA !RamLayer1XSubPosition
        STA !RamCameraYSpeed : STA !RamCameraYSubSpeed : STA !RamCameraYState : STA !RamLayer1YSubPosition
        JSR Scrolling ; Instruction replaced by hijack (effectively)
        PLP : RTS
    
    UpdateX:
        ; forgive me father for I have sinned
        LDA !RamCameraXState : CMP #$0003 : BNE +
        SEC : RTS

    +   LDA #$0000 : PHA ; tInvertDirectionFlag
        LDA !RamLayer1XDestination : SEC : SBC !RamLayer1XPosition : BPL +
        PLA : INC : PHA
    +   LDA !RamLayer1XDestination : PHA
        LDA !RamLayer1XPosition : PHA
        LDA !RamCameraXDistanceTraveledWhileAccelerating : PHA
        LDA !RamLayer1XSubPosition : PHA
        LDA !RamCameraXState : PHA
        LDA !RamCameraXSubSpeed : PHA
        LDA !RamCameraXSpeed : PHA
        LDA !RamLayer1XStartPos : PHA
        JSL Update
        PLA ;: STA !RamLayer1XStartPos; no need to write back
        PLA : STA !RamCameraXSpeed
        PLA : STA !RamCameraXSubSpeed
        PLA : STA !RamCameraXState
        PLA : STA !RamLayer1XSubPosition
        PLA : STA !RamCameraXDistanceTraveledWhileAccelerating
        PLA : STA !RamLayer1XPosition
        PLA : STA !RamLayer1XDestination
        PLA ; tInvertDirectionFlag
        RTS
    
    UpdateY:
        LDA !RamCameraYState : CMP #$0003 : BNE +
        SEC : RTS

    +   LDA #$0000 : PHA ; tInvertDirectionFlag
        LDA !RamLayer1YDestination : SEC : SBC !RamLayer1YPosition : BPL +
        PLA : INC : PHA
    +   LDA !RamLayer1YDestination : PHA
        LDA !RamLayer1YPosition : PHA
        LDA !RamCameraYDistanceTraveledWhileAccelerating : PHA
        LDA !RamLayer1YSubPosition : PHA
        LDA !RamCameraYState : PHA
        LDA !RamCameraYSubSpeed : PHA
        LDA !RamCameraYSpeed : PHA
        LDA !RamLayer1YStartPos : PHA
        JSL Update
        PLA ;: STA !RamLayer1YStartPos; no need to write back
        PLA : STA !RamCameraYSpeed
        PLA : STA !RamCameraYSubSpeed
        PLA : STA !RamCameraYState
        PLA : STA !RamLayer1YSubPosition
        PLA : STA !RamCameraYDistanceTraveledWhileAccelerating
        PLA : STA !RamLayer1YPosition
        PLA : STA !RamLayer1YDestination
        PLA ; tInvertDirectionFlag
        BNE + : BCS +
        PHP : JSL $80AD1D : PLP ; This fixes a graphical glitch for horizontal doors where the camera also needs to move down.
        +
        RTS

    DoorTransitionScrollingHorizontalSetup:
        LDA !RamLayer1XDestination : STA !RamLayer1XPosition ; This is what vanilla does

        LDA !RamLayer1YPosition : AND #$00FF : CLC : ADC !RamLayer1YDestination : PHA
        LDA !RamLayer1YPosition-1 : BIT #$FF00 : BPL +
        LDA $01,s : SEC : SBC #$0100 : STA $01,s
    +   PLA : STA !RamLayer1YPosition
        JSR $A2F9 ; Instruction replaced by hijack
        RTS

    DoorTransitionScrollingVerticalSetup:
        LDA !RamLayer1YDestination : STA !RamLayer1YPosition ; This is what vanilla does

        LDA !RamLayer1XPosition : AND #$00FF : CLC : ADC !RamLayer1XDestination : PHA
        LDA !RamLayer1XPosition-1 : BIT #$FF00 : BPL +
        LDA $01,s : SEC : SBC #$0100 : STA $01,s
    +   PLA : STA !RamLayer1XPosition
        JSR $A2F9 ; Instruction replaced by hijack
        RTS

    warnpc !Freespace80End

    org !FreespaceAnywhere
    ; Scrolls the screen. This function is expected to be called every frame until this function returns carry set
    ; Parameters: Assumes REP#$30 before calling
    
    ; $01,s: tLayer1StartPos
    ; $03,s: tCameraSpeed
    ; $05,s: tCameraSubSpeed
    ; $07,s: tCameraState
    ; $09,s: tLayer1SubPosition
    ; $0B,s: tCameraDistanceTraveledWhileAccelerating
    ; $0D,s: tLayer1Position
    ; $0F,s: tLayer1Destination
    ; $11,s: tInvertDirectionFlag ; 0 for door moving right or down, nonzero for door moving left or up

    !tLayer1StartPos = $09,s : !tLayer1StartPosAfterPha = $0B,s
    !tCameraSpeed = $0B,s
    !tCameraSubSpeed = $0D,s
    !tCameraState = $0F,s
    !tLayer1SubPosition = $11,s
    !tCameraDistanceTraveledWhileAccelerating = $13,s
    !tLayer1Position = $15,s : !tLayer1PositionAfterPha = $17,s
    !tLayer1Destination = $17,s
    !tInvertDirectionFlag = $19,s

    Update:
        PHP : PHX : PHA
        REP #$30

        LDA !tCameraState : ASL : TAX : JMP (CameraStateHandlers,x)
    CameraStateHandlers:
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
        PLA : PLX : PLP : CLC : RTL
    .stop
        LDA #$0003 : STA !tCameraState ; camera state = stop
        LDA !tLayer1Destination : STA !tLayer1Position
        PLA : PLX : PLP : SEC : RTL
    
    SpawnDoorCap: ; move Samus to door cap position for now while I'm testing this. Actually I might just stick with this.
        LDA !RamDoorDirection : AND #$0003 : BIT #$0002 : BNE .verticalTransition
    .horizontalTransition
        LDA $14 : AND #$00FF : ASL #4 : STA !RamSamusXPosition : STA !RamSamusPrevXPosition
        BRA .finish
    .verticalTransition
        LDA $15 : AND #$00FF : ASL #4 : STA !RamSamusYPosition
        LDA !RamDoorDirection : BIT #$0001 : BEQ ..samusMovingDown
    ..samusMovingUp
        LDA !RamSamusYPosition : SEC : SBC #$001C : STA !RamSamusYPosition : STA !RamSamusPrevYPosition
        BRA .finish
    ..samusMovingDown
        LDA !RamSamusYPosition : CLC : ADC #$0020 : STA !RamSamusYPosition : STA !RamSamusPrevYPosition
    .finish
        JSL $84846A ; instruction replaced by hijack
        RTL

    warnpc !FreespaceAnywhereEnd
}

org $80AD1D
    STZ $0925 ; Door transition frame counter = 0
    
    ; these are the important bit?
    JSR $A4BB ; Calculate BG and layer position blocks
    JSR $AE10 ; Update previous layer blocks
    
    INC $0901 ; Increment previous layer 1 Y block
    INC $0905 ; Increment previous layer 2 Y block
    JSR $AF89 ; Door transition scrolling - up
    ; TODO - THIS IS STILL CALLING INTO THE UP DOOR SCROLLING ROUTINE (!!!)
    RTL



; For years, I've feared the door transitions.
; Now, door transitions fear me.


