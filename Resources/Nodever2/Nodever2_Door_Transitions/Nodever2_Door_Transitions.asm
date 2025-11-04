lorom

; todo:
; test doors on screen edges and doors not touching any screen border / etc - basically "door glitch fix" patch should either be compatible with mine or my code should also have that bug fixed
; also I think that maxspeed isn't strictly obeyed and the game can *technically* exceed it as it continues to accelerate for 1 frame past it. if you have high accel values this is a problem right?
; doors can still snap into place on any speed value when aligning - state 7 is an example
; testing - ceres broke when leaving ridleys room and running through the hallway after
; testing - also broke the screen when leaving early supers room in much the same way.
; I'd also like to see if there's anything I can do about the black lines that show when the door is moving... most prevalent in vertical doors
; there is still a bug with layer 2 - see green brin fireflea room

; Nodever2's door transitions
;   By now, several of us have rewritten door transitions - this is my take on it.

; There are a lot more edits I'd like to do... Namely - Figure out a way to load music in the background(?) and start doing so while the door is scrolling(?), remove any 1 frame delays between door state machine states.
; When I release this, release presets: same speed as vanilla, and faster (my preferred settings)

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
    !CameraAcceleration    = #$0001
    !CameraSubAcceleration = #$0000
    !CameraMaxSpeed        = #$000F  ; Should be 000F or less.
    !ReportFreespaceAndRamUsage = 1  ; Set to 0 to stop this patch from printing it's freespace and RAM usage to the console when assembled.
    !ScreenFadesOut             = 1  ; Set to 0 to make the screen not fade out during door transitions. This was useful for testing this patch, but it looks unpolished, not really suitable for a real hack.
    !VanillaCode                = 0  ; Set to 0 to compile the vanilla door transition code instead of mine. Was useful for debugging.

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
    !Freespace80ReportStart := !Freespace80
    !Freespace82ReportStart := !Freespace82

    ; Vanilla variables
    !RamUploadingToApuFlag            = $0617 ; I am going to set to 0001 if an async upload is in progress.
    !RamDisableSoundsFlag             = $05F5
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
    !RamLayer2XDestination                       := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamLayer2YDestination                       := !CurRamAddr : !CurRamAddr := !CurRamAddr+2

    !RamMusicHandlerState                        := !CurRamAddr : !CurRamAddr := !CurRamAddr+2
    !RamEnableAsyncUploadsFlag                   := !CurRamAddr : !CurRamAddr := !CurRamAddr+2

    !RamSpcDB                                    := $9B ; 1 byte
    !RamSpcData                                  := $9C ; 2 bytes
    !RamSpcIndex                                 := $9E ; 1 byte
    !RamSpcLength                                := $9F ; 2 bytes

    !RamAsyncSpcState                            := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; basically their state machine address\
    !RamNmiCounter                               := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; ?

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
            LDA #$0000
            STA !RamCameraXSpeed : STA !RamCameraXSubSpeed : STA !RamCameraXState : STA !RamLayer1XSubPosition
            STA !RamCameraYSpeed : STA !RamCameraYSubSpeed : STA !RamCameraYState : STA !RamLayer1YSubPosition
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
            LDA !RamCameraXState : CMP #$0003 : BNE +
            SEC : RTL
        +   
            LDA !RamLayer2XDestination : PHA
            LDA !RamLayer2XPosition : PHA
            LDA #$0000 : PHA ; tInvertDirectionFlag = right
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
            JSR ScrollCamera ; Need to maintain the carry bit after this subroutine
            PLA ;: STA !RamLayer1XStartPos; no need to write back
            PLA : STA !RamCameraXSpeed
            PLA : STA !RamCameraXSubSpeed
            PLA : STA !RamCameraXState
            PLA : STA !RamLayer1XSubPosition
            PLA : STA !RamCameraXDistanceTraveledWhileAccelerating
            PLA : STA !RamLayer1XPosition
            PLA ;: STA !RamLayer1XDestination
            PLA ; tInvertDirectionFlag
            PLA : STA !RamLayer2XPosition
            PLA ; !RamLayer2XDestination
            RTL
    }
    
    ScrollCameraY: {
            LDA !RamCameraYState : CMP #$0003 : BNE +
            SEC : RTL
        +
            LDA !RamLayer2YDestination : PHA
            LDA !RamLayer2YPosition : PHA
            LDA #$0000 : PHA ; tInvertDirectionFlag = down
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
            JSR ScrollCamera ; Need to maintain the carry bit after this subroutine
            PLA ;: STA !RamLayer1YStartPos; no need to write back
            PLA : STA !RamCameraYSpeed
            PLA : STA !RamCameraYSubSpeed
            PLA : STA !RamCameraYState
            PLA : STA !RamLayer1YSubPosition
            PLA : STA !RamCameraYDistanceTraveledWhileAccelerating
            PLA : STA !RamLayer1YPosition
            PLA ;: STA !RamLayer1YDestination
            PLA ; tInvertDirectionFlag
            PLA : STA !RamLayer2YPosition
            PLA ; !RamLayer2YDestination
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
        ; $13,s: tLayer2Position
        ; $15,s: tLayer2Destination

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
        !tLayer2Position                          = !tBaseStackOffset+18,s
        !tLayer2Destination                       = !tBaseStackOffset+20,s

            PHP : PHX : PHA
            REP #$30

            ; Failsafe: If the scrolling has taken this long, we may be softlocked. End it here.
            LDA !RamDoorTransitionFrameCounter : CMP.w #10*60 : BMI + ; 10 seconds
            LDA #$0003 : STA !tCameraState

        +   LDA !tCameraState : ASL : TAX : JMP (.cameraStateHandlers,x)
        .cameraStateHandlers:
            dw .accelerate, .move, .decelerate, .stop

            ; update speed then layer1 pos
            ; first check if camera needs to be accelerated
        .accelerate
            LDA !tCameraSpeed : CMP !CameraMaxSpeed : BPL ..stopAccelerating
            LDA !tLayer1Destination : SEC : SBC !tLayer1StartPos : BPL +++ : EOR #$FFFF : INC
        +++ LSR : PHA : LDA !tLayer1PositionAfterPha : SEC : SBC !tLayer1StartPosAfterPha : BPL +++ : EOR #$FFFF : INC
        +++ CMP $01,s : BPL ..stopAcceleratingWithPull : PLA ; stop accelerating if we're over halfway
            LDA !CameraSubAcceleration : CLC : ADC !tCameraSubSpeed : STA !tCameraSubSpeed ; continue accelerating
            LDA !CameraAcceleration : ADC !tCameraSpeed : STA !tCameraSpeed
            BRA .setPosition
        ..stopAcceleratingWithPull
            PLA
        ..stopAccelerating
            LDA !tCameraState : INC : STA !tCameraState
            LDA !tLayer1Position : SEC : SBC !tLayer1StartPos : BPL +++ : EOR #$FFFF : INC
        +++ STA !tCameraDistanceTraveledWhileAccelerating
        .move
            ; first, check if we need to start declerating
            LDA !tCameraSubSpeed : BNE + : LDA !tCameraSpeed : BEQ .stop ; If we got here with speed of 0, stop this madness. (prevents possible softlock)
        +   LDA !tLayer1Destination : SEC : SBC !tLayer1Position : BPL +++ : EOR #$FFFF : INC
        +++ CMP !tCameraDistanceTraveledWhileAccelerating
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
            LDA !tLayer2Position : CLC : ADC !tCameraSpeed : STA !tLayer2Position
            BRA +
        ..invert
            LDA !tLayer1SubPosition : SEC : SBC !tCameraSubSpeed : STA !tLayer1SubPosition
            LDA !tLayer1Position : SBC !tCameraSpeed : STA !tLayer1Position
            LDA !tLayer2Position : SEC : SBC !tCameraSpeed : STA !tLayer2Position
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
            LDA !tLayer2Destination : STA !tLayer2Position
            PLA : PLX : PLP : SEC : RTS
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

; ==================================================================
; ============== DOOR TRANSITION LOADING - LOAD MUSIC ==============
; ==================================================================
{

;10-22
; I am going to expand the door transition game states to call a new handler for music queue
; also going to break the state that has the busy loop up so it can actually return back to the state handler every frame

; my new handler will (start out as) its own entire state machine 

; todo NOP out all places in door transitions where we are currently handling music queue and sound effects

; more notes:
; looks like it's actually the music handler that handles spc uploads?
; so it's the main game loop (the thing that actually calls each game state function) that calls
; the music handler... ugh
; so I guess I need to patch the main game loop or the music queue handler to have special behavior
; when we're in a door transition...

; thoughts:
; update music queue handler to have 2 options
; based on a memory address
; 1: transfer music until NMI, then leave SPC hanging until next frame.
; 2: transfer music until it is done.

; for option 1, we'd also have to keep track of if we're done or not,
; so that next frame when the music queue handler is called,
; we don't actully mess with the music queue variables and instead
; go straight back to working on transfering the music.

; this sounds like hell.

; TODO repoint these

org $808F82
    JSR CleanupOnlyIfNonAsyncStarted
    PLP : RTL

org $808F0F
    JMP CheckIfHandleMusicQueue

org $808340
    JMP CustomRequestNmi


org $808028
    JSL CheckIfStartAsyncUpload

org !Freespace80
CleanupOnlyIfNonAsyncStarted:
        LDA !RamUploadingToApuFlag : BNE +
        JSL MusicQueueCleanupAfterTransfer
    +   RTS

MusicQueueCleanupAfterTransfer:
print "MusicQueueCleanupAfterTransfer: ", pc
        PHP
        SEP #$20
        STZ $064C   ; Current music track = 0
        REP #$20
        LDX $063B   ;\
        STZ $0619,x ;) Music queue entries + [music queue start index] = 0
        STZ $0629,x ; Music queue timer + [music queue start index] = 0
        INX         ;\
        INX         ;|
        TXA         ;) Music queue start index = ([music queue start index] + 2) % 10h
        AND #$000E  ;|
        STA $063B   ;/
        LDA #$0008  ;\
        STA $0686   ;) Sound handler downtime = 8
        PLP
        RTL

CheckIfHandleMusicQueue:
    PHP : REP #$30
    LDA !RamUploadingToApuFlag : BNE .skip
    PLP
    DEC $063F ; instruction replaced by hijack
    JMP $8F12
.skip
    PLP : PLP : RTL

CustomRequestNmi:
    STA $05B4 ; nmi request flag = 1
    LDA !RamUploadingToApuFlag : BNE +
    JMP $8343 ; back to normal nmi routine
+   JMP WaitForNmiWhileTransferringData


; Returns zero flag set if normal upload should continue, zero flag clear otherwise.
CheckIfStartAsyncUpload:
        LDA !RamUploadingToApuFlag : BEQ +
        TDC : INC : DEC : RTL
    +   LDA !RamEnableAsyncUploadsFlag : BNE +
        LDA $808008 : RTL ; instruction replaced by hijack
    +   PHP
        SEP #$30
        LDA $02 : STA !RamSpcDB
        REP #$30
        LDA $00 : STA !RamSpcData
        LDA #SpcInit : STA !RamAsyncSpcState
        LDA #$0001 : STA !RamUploadingToApuFlag ; Begin async upload
        LDA #$FFFF : PLP : XBA : RTL




; This is heavily based off of / copied from NobodyNada's work for the SM practice hack at https://github.com/tewtal/sm_practice_hack/blob/master/src/menu.asm
; todo disable sounds during this time. todo initialize all of our ram variables.

WaitForNmiWhileTransferringData:
{
    REP #$30
    LDA !RamAsyncSpcState : TAX

  .loop
    LDA $05B4 : AND #$00FF ; NMI complete flag
    BEQ .done

    CPX #$0000 : BPL .loop
    PHA : PHP : PHB : JSR JumpToX : PLB : PLP
    LDA !RamAsyncSpcState : TAX : PLA
    BRA .loop

  .done
    PLB : PLP
    RTL
}

JumpToX:
{
    DEX : PHX
    RTS
}

SpcInit:
{
    PHP
    SEP #$20
    REP #$10
    LDA #$FF : STA $002140
    PLP


    ; wait for SPC to be ready
    LDA #$BBAA : CMP $2140 : BNE .return

    ; disable soft reset
    ;LDA #$FFFF : STA !RamUploadingToApuFlag

    SEP #$20
    LDA #$CC : STA !RamSpcIndex

    REP #$20
    ;LDA #$CFCF : STA !RamSpcDB
    ;LDA #$8000 : STA !RamSpcData

    LDA.w #SpcNextBlock : STA !RamAsyncSpcState

  .return
    RTS
}

SpcNextBlock:
{
    SEP #$20
    PHB : LDA !RamSpcDB : PHA : PLB
    LDY !RamSpcData

    ; Get block size
    LDA #$01
    LDX $0000,Y : BNE .not_last
    LDA #$00

  .not_last
    INY : BNE .done_inc_bank_1
    JSR SpcIncrementBank
  .done_inc_bank_1
    INY : BNE .done_inc_bank_2
    JSR SpcIncrementBank
  .done_inc_bank_2
    STX !RamSpcLength

    ; Get block address
    LDX $0000,Y
    INY : BNE .done_inc_bank_3
    JSR SpcIncrementBank
  .done_inc_bank_3
    INY : BNE .done_inc_bank_4
    JSR SpcIncrementBank
  .done_inc_bank_4
    PLB : STX $2142

    STA $2141

    STY !RamSpcData
    REP #$20
    LDA.w #SpcNextBlock_wait : STA !RamAsyncSpcState

    RTS
}

SpcIncrementBank:
{
    PHA
    LDA !RamSpcDB : INC : STA !RamSpcDB
    PHA : PLB : PLA
    LDY #$8000
    RTS
}

SpcNextBlock_wait:
{
    SEP #$20
    LDA !RamSpcIndex : STA $2140 : CMP $2140 : BNE .return

    STZ !RamSpcIndex
    REP #$20
    LDA !RamSpcLength : BEQ .eof
    LDA.w #SpcTransfer : STA !RamAsyncSpcState
    RTS

  .eof
    TDC : STA !RamAsyncSpcState
    STZ !RamDisableSoundsFlag : STZ !RamUploadingToApuFlag
    JSL MusicQueueCleanupAfterTransfer

  .return
    RTS
}

SpcTransfer:
{
    ; Determine how many bytes to transfer
    LDA !RamSpcLength : TAX
    SBC #$0040 : BCC .last
    LDX #$0040 : STA !RamSpcLength
    BRA .setup

  .last
    STZ !RamSpcLength

  .setup
    SEP #$20
    PHB : LDA !RamSpcDB : PHA : PLB
    LDY !RamSpcData
    LDA !RamSpcIndex
    SEP #$20

  .transfer_loop
    XBA : LDA $0000,Y : XBA

    REP #$20
    STA $002140
    SEP #$20

  .wait_loop
    CMP $002140 : BNE .wait_loop

    INC
    INY : BNE .done_inc_bank
    JSR SpcIncrementBank
  .done_inc_bank
    DEX : BNE .transfer_loop

    LDX !RamSpcLength : BNE .timeout
    ; Done with the transfer!
    CLC : ADC #$03 : STA !RamSpcIndex : STY !RamSpcData
    REP #$20
    LDA.w #SpcNextBlock : STA !RamAsyncSpcState

    PLB
    RTS

  .timeout
    STA !RamSpcIndex
    STY !RamSpcData

    PLB
    RTS
}

Done:

!Freespace80 := Done
warnpc !Freespace80End


    org $82E526 : JSR SetWaitForScrollingDoorTransitionFunction : RTS

    ;org $82E664 ; beware, we've hijacked this in one other place but its commented out
    ;    JSL CheckIfDoorNeedsToWaitOnMusic

;    org $82E72C : JSR DisableAsyncUploads

    org $82E17D : JSR InitializeMusicHandler

    
    ;org $82E16F : JSR RunDoorTransitionMusicHandlerAndExecuteDoorTransitionFunction ; game state 9
    org $82E28F : JMP RunDoorTransitionMusicHandlerAndExecuteDoorTransitionFunction ; game state B

    org $82E27C : LDA #$E2DB ; skip "wait for sounds to finish" - this will be handled by door transition music handler
    org $82E4AD : NOP #4 ; this will be handled by door transition music handler
    
    org $82E664
        LDA !RamMusicHandlerState : CMP #$0003 : BNE +
        LDA #$E6A2 : STA $099C
    +   RTS
    warnpc $82E675

    org !Freespace82 
    ; this allows us to still transfer music in background instead of sitting in the busy loop.
    SetWaitForScrollingDoorTransitionFunction: {
        LDA #WaitForScrollingFunction : STA $099C
    }

    WaitForScrollingFunction: {
            LDA $0931 : BPL +
            LDA #$E52B : STA $099C
        +   RTS
    }

    RunDoorTransitionMusicHandlerAndExecuteDoorTransitionFunction: {
        JSR DoorTransitionMusicHandler
        JMP ($099C) ; instruction replaced by hijack
    }

    ;; returns carry set if door needs to wait on music
    ;CheckIfDoorNeedsToWaitOnMusic:
    ;        LDA !RamUploadingToApuFlag : BNE +
    ;        JSL $808EF4 : BCS + ; instruction replaced by hijack
    ;        LDA #$0000 : STA !RamEnableAsyncUploadsFlag
    ;        CLC : RTS
    ;    +   SEC : RTS


;    DisableAsyncUploads:
;            STA $099C ; instruction replaced by hijack
;            PHA : LDA #$0000 : STA !RamEnableAsyncUploadsFlag : PLA
;            RTS

    InitializeMusicHandler: { ; todo can this be moved out of this bank?
            LDA #$0000
            STA !RamMusicHandlerState
            STA !RamSpcDB
            STA !RamSpcData
            STA !RamSpcIndex
            STA !RamSpcLength
            STA !RamAsyncSpcState
            STA !RamNmiCounter
            LDA #$0001 : STA !RamEnableAsyncUploadsFlag
            LDA $0E16 : RTS ; instruction replaced by hijack
    }

    

    DoorTransitionMusicHandler: {
        ;JSL $808F0C ; Handle music queue
        PHP : REP #$30
        LDA !RamUploadingToApuFlag : BNE .return
    +   LDA !RamMusicHandlerState ; : BNE + : JSL $8289EF ; Handle sound effects if music handler state is 0
    +   LDA !RamMusicHandlerState : ASL : TAX : JMP (.musicStateHandlers,x)
        
        .musicStateHandlers
            dw .waitForSoundsAndQueueMusic, .waitUntilMusicIsNotQueued, .queueMusicTrack, .done

        .waitForSoundsAndQueueMusic
            PHP
            SEP #$20
            LDA $0646 : SEC : SBC $0643 : AND #$0F : BNE + ; If [sound 1 queue next index] - [sound 1 queue start index] & Fh != 0: return
            LDA $0647 : SEC : SBC $0644 : AND #$0F : BNE + ; If [sound 2 queue next index] - [sound 2 queue start index] & Fh != 0: return
            LDA $0648 : SEC : SBC $0645 : AND #$0F : BNE + ; If [sound 3 queue next index] - [sound 3 queue start index] & Fh != 0: return
            REP #$20
            LDA !RamMusicHandlerState : INC : STA !RamMusicHandlerState
            JSL QueueDestinationRoomMusic ; Queue room music data
        +   PLP : BRA .return

        .waitUntilMusicIsNotQueued
            JSL $808EF4 : BCS + ; Check if music is queued
            LDA !RamMusicHandlerState : INC : STA !RamMusicHandlerState
        +   BRA .return

        .queueMusicTrack
            ; todo: follow door pointers to get music track data set up in RAM correctly before doing the rest of this
            JSL $82E0D5 ; Load new music track if changed - I think this is supposed to be after we uhh
            LDA !RamMusicHandlerState : INC : STA !RamMusicHandlerState
            BRA .return

        .done
            LDA #$0000 : STA !RamEnableAsyncUploadsFlag

        .return
            PLP : RTS

        .freespace
    }
    !Freespace82 := DoorTransitionMusicHandler_freespace
    warnpc !Freespace82End



















;lots of music change testing. starting to think the ideal way to do this would be another interrupt...
;what I will say is that there is plenty of CPU time to spare during fade to black. we should be queueing the music earlier.

; I actually think that if we queue the music earlier, we could finish the entire transfer in time...



    ;org $82E4AD : NOP #4 ; remove the code that originally queued room music data

;!!!!!
    ;org $82E526 ; busy loop while waiting for scrolling
    ;        JSR WaitForMusic
    ;
    ;org DoorTransitionFunctionScrollScreenToAlignment_freespace
    ;WaitForMusic: {
    ;        JSR WaitForMusic2
    ;        JSL $808338 ; Wait for NMI
    ;        LDA $0931 : RTS ; instruction replaced by hijack
    ;    .freespace
    ;}
    ;warnpc $82E353
;!!!!!


    ; todo: $E29E should be the one to queue the music
    ; the door transition game states also need to call the music queue handler
    ; then we can continue to use the code above but not call the music queue handler from there (since it'll be done by the game state handlers)


    ; note: music queue is supposed to be handled before sound effects (8089ef)
    
    
    ;org $82E28F ; game state bh (door transition - main).
    ;        JMP HandleMusicQueueAndExecuteFunction

;!!!!!
    ;org WaitForMusic_freespace
    ;WaitForMusic2: {
    ;        JSL $808EF4 : BCC + ; If music is queued:
    ;        JSL $808F0C         ; Handle music queue and return
    ;        RTS
    ;    +   JSL $82E0D5 ; Load new music track if changed
    ;        RTS
    ;}
;!!!!!

    ;HandleMusicQueueAndExecuteFunction: {
    ;        LDA $099C : CMP #$E29E : BEQ + ; If we're not done waiting for sounds to finish, skip music queue (is this needed?)
    ;        JSR WaitForMusic2
    ;    +   JMP ($099C) ; Execute door transition function
    ;    .freespace
    ;}
    ;warnpc $82E353

    ;org $82E3BC ; right after creating door interrupt
    ;    JSR QueueMusic2

   ;org HandleMusicQueueAndExecuteFunction_freespace
   ;QueueMusic2: {
   ;        STA $099C ; Instruction replaced by hijack
   ;        JSL $82E071 ; Queue room music data
   ;        RTS
   ;    .freespace
   ;}
   ;warnpc $82E353


    ;org $82E65D : LDA #$E6A2
;
    ;org $82E650 : CLCRTS:
    ;org $82E752
    ;    JSR WaitForMusic3
    ;org $82E664
    ;WaitForMusic3:
    ;    JSR $D961 : BCC CLCRTS ; instruction replaced by hijack
    ;    JSL $808EF4 : BCS CLCRTS ; If music is queued: return
    ;    ;JSL $82E0D5 ; load new music track if changed
    ;    SEC : RTS
    ;warnpc $82E675







;   org $82E2D6
;           JSR QueueMusic
;   
;   org HandleMusicQueueAndExecuteFunction_freespace
;   QueueMusic: {
;           STA $099C ; Instruction replaced by hijack
;           JSL QueueDestinationRoomMusic
;           RTS
;       .freespace
;   }
;   warnpc $82E353
;
   org !FreespaceAnywhere
   QueueDestinationRoomMusic: {
           PHP : PHB
           PEA $8383 : PLB : PLB ; DB = $83
           LDX $078D ; X = [door pointer]
           LDA $0000,x : TAX ; X = Room pointer (this would normally go in $079B)
           PEA $8F8F : PLB : PLB ; DB = $8F
           JSL $8FE5D2 ; Room state checking handler - issue: before calling this we need the area bit set accordingly, and whatever other states look at... Also, this modifies $07BB, todo back that up. TODO see what else it modifies.
           LDX $07BB ; X = room state pointer
           LDA $0004,x : AND #$00FF : STA $07CB ; Music data index = [[X] + 4]
           LDA $0005,x : AND #$00FF : STA $07C9 ; Music track index = [[X] + 5]
           JSL $82E071 ; Queue room music data

           ; JSL $82E071 - queue room music data
           ;$82:E774 20 F1 DD    JSR $DDF1  [$82:DDF1]  ; Load destination room CRE bitset
           ;$82:E777 20 12 DE    JSR $DE12  [$82:DE12]  ; Load door header
           ;$82:E77A 20 6F DE    JSR $DE6F  [$82:DE6F]  ; Load room header
           ;$82:E77D 20 F2 DE    JSR $DEF2  [$82:DEF2]  ; Load state header
           PLB : PLP : RTL
       .freespace
   }
   !FreespaceAnywhere := QueueDestinationRoomMusic_freespace
   warnpc !FreespaceAnywhereEnd


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
