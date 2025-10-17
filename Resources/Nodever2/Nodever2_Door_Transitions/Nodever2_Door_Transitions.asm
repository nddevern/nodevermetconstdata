lorom

; Nodever2's door transitions
;   By now, several of us have rewritten door transitions - this is my take on it.

; So far, only transitions with Samus moving from left to right and right to left are modified. And only the speed of the scrolling is changed.
; There are a lot more edits I'd like to do... Namely - Figure out a way to load music in the background(?) and start doing so while the door is scrolling(?), align the screen during the fadeout.
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
    !RamLayer1XDestination = $0927
    !RamLayer2XPosition = $0917
    !RamSamusXPosition = $0AF6
    !RamSamusYPosition = $0AFA
    !RamSamusXSubPosition = $0AF8
    !RamSamusPrevXPosition = $0B10
    !RamDoorDirection = $0791
    ;{
    ;    0: Right
    ;    1: Left
    ;    2: Down
    ;    3: Up
    ;    +4: Close a door on next screen
    ;}

    ; new variables - can repoint the ram that these use
    !RamBank                  = $7F0000
    !RamStart                #= $FB46+!RamBank
    !RamLayer1StartPos       #= !RamStart+2
    !RamLayer2StartPos       #= !RamLayer1StartPos+2
    !RamSubtractFlag         #= !RamLayer2StartPos+2 ; 0000 = add, 8000 = subtract
    !RamCameraSpeed          #= !RamSubtractFlag+2
    !RamCameraSubSpeed       #= !RamCameraSpeed+2
    !RamCameraState          #= !RamCameraSubSpeed+2 ; 0 = accelerating, 1 = moving at full speed, 2 = decelerating
    !RamLayer1XSubPosition   #= !RamCameraState+2
    !RamLayer2XSubPosition   #= !RamLayer1XSubPosition+2
    !RamCameraDistanceTraveledWhileAccelerating #= !RamLayer2XSubPosition+2

    !RamEnd                   = !RamCameraDistanceTraveledWhileAccelerating

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
        JSL Update
        PHP
        JSL $80A3A0
        LDA $02,s : TAX : INX : STX !RamDoorTransitionFrameCounter
        PLP : BCC +
        JSL $80A3A0
        PLX : SEC : RTS
    +   PLX : CLC : RTS
    CalculateLayer2Position:
        JSR $A2F9 ; X
        JSR $A33A ; Y
        RTL
    warnpc $80AEC2


    org !Freespace80
    SetupScrolling:
        PHP : REP #$30
        LDA !RamLayer1XPosition : STA !RamLayer1StartPos
        LDA !RamLayer2XPosition : STA !RamLayer2StartPos
        LDA #$0000 : STA !RamCameraSpeed : STA !RamCameraSubSpeed : STA !RamCameraState : STA !RamLayer1XSubPosition
        JSR Scrolling ; Instruction replaced by hijack (effectively)
        PLP : RTS
    warnpc !Freespace80End

    org !FreespaceAnywhere
    ; Scrolls the screen. This function is expected to be called every frame until this function returns carry set
    Update:
        PHP : PHX : PHA
        REP #$30

        LDA !RamCameraState : ASL : TAX : JMP (CameraStateHandlers,x)
    CameraStateHandlers:
        dw .accelerate, .move, .decelerate

        ; update speed then layer1 pos
        ; first check if camera needs to be accelerated
    .accelerate
        LDA !RamCameraSpeed : CMP !CameraMaxSpeed : BPL .stopAccelerating
        LDA !RamLayer1XDestination : SEC : SBC !RamLayer1StartPos : BPL +++ : EOR #$FFFF : INC : +++
        LSR : PHA : LDA !RamLayer1XPosition : SEC : SBC !RamLayer1StartPos : BPL +++ : EOR #$FFFF : INC : +++
        CMP $01,s : BPL .stopAcceleratingWithPull : PLA ; stop accelerating if we're over halfway
        LDA !CameraSubAcceleration : CLC : ADC !RamCameraSubSpeed : STA !RamCameraSubSpeed ; continue accelerating
        LDA !CameraAcceleration : ADC !RamCameraSpeed : STA !RamCameraSpeed
        BRA .setPosition
    .stopAcceleratingWithPull
        PLA
    .stopAccelerating
        LDA !RamCameraState : INC : STA !RamCameraState
        LDA !RamLayer1XPosition : SEC : SBC !RamLayer1StartPos : BPL +++ : EOR #$FFFF : INC : +++
        STA !RamCameraDistanceTraveledWhileAccelerating
    .move
        ; first, check if we need to start declerating
        LDA !RamLayer1XDestination : SEC : SBC !RamLayer1XPosition : BPL +++ : EOR #$FFFF : INC : +++
        CMP !RamCameraDistanceTraveledWhileAccelerating
        BEQ + : BPL .setPosition
        ; start decelerating
    +   LDA !RamCameraState : INC : STA !RamCameraState
        ;BRA .setPosition ; start decelerating next frame
    .decelerate
        LDA !RamCameraSubSpeed : SEC : SBC !CameraSubAcceleration : STA !RamCameraSubSpeed
        LDA !RamCameraSpeed : SBC !CameraAcceleration : STA !RamCameraSpeed
    .setPosition
        LDA !RamDoorDirection : BIT #$0001 : BNE ..invert
        LDA !RamLayer1XSubPosition : CLC : ADC !RamCameraSubSpeed : STA !RamLayer1XSubPosition
        LDA !RamLayer1XPosition : ADC !RamCameraSpeed : STA !RamLayer1XPosition
        BRA +
    ..invert
        LDA !RamLayer1XSubPosition : SEC : SBC !RamCameraSubSpeed : STA !RamLayer1XSubPosition
        LDA !RamLayer1XPosition : SBC !RamCameraSpeed : STA !RamLayer1XPosition
    +   JSL CalculateLayer2Position
    .checkStop
        ; check if we need to stop
        LDA !RamDoorDirection : BIT #$0001 : BNE ..invert
        LDA !RamLayer1XPosition : CMP !RamLayer1XDestination : BPL .stop : BRA +
    ..invert
        LDA !RamLayer1XDestination : CMP !RamLayer1XPosition : BPL .stop
    +   LDA !RamCameraSpeed : BMI .stop
        PLA : PLX : PLP : CLC : RTL
    .stop
        LDA !RamLayer1XDestination : STA !RamLayer1XPosition
        JSL CalculateLayer2Position
        PLA : PLX : PLP : SEC : RTL
    
    SpawnDoorCap: ; move Samus to door cap position for now while I'm testing this. Actually I might just stick with this.
        LDA $14 : AND #$00FF : ASL #4 : STA !RamSamusXPosition : STA !RamSamusPrevXPosition
        ;LDA $15 : AND #$00FF : ASL #4 : STA !RamSamusYPosition
        JSL $84846A ; instruction replaced by hijack
        RTL

    warnpc !FreespaceAnywhereEnd
}