lorom

warnings disable Wfeature_deprecated

math round off
math pri on

; Nodever2's door transitions
;   By now, several of us have rewritten door transitions - this is my take on it.
;   This patch includes many customization options, allowing you to make them work exactly how you want.
;   Patch showcase video: https://youtu.be/rkpMoOeFj3Y

; by Nodever2 November 2025
; Works with Asar (written with metconst fork of asar 1.90pre), won't work with xkas
; Please give credit if you use this patch.

; This patch was also made possible by:
;  * P.JBoy  - Keeper of the commented Super Metroid bank logs, without which this patch would not have been possible. https://patrickjohnston.org/bank/index.html
;  * Tundain - Gave me the idea of how we can tell whether to position the door DMA (a.k.a. black flickering) on the top or bottom of the screen

; Other patches you should use that were tested with this, that have no conflicts and work out of the box:
;  * Decompression Optimization by Kejardon, with bugfix from Maddo - Included in this patch
;     > This makes large rooms load faster.
;
;  * SPC Transfer Optimization by total - https://patrickjohnston.org/ASM/ROM%20data/Super%20Metroid/Other's%20work/total%20SPC%20transfer%20optimisation.asm
;     > This makes music load faster.
;
;  * Full Door Cap PLM Rewrite by Nodever2 - https://metroidconstruction.com/resource.php?id=562
;     > This makes door caps a lot less annoying, you can't bonk on them as they're opening anymore alongside other improvements.

; Terminology:
;  * Door directions: A door direction is based on the direction Samus travels through it.
;       For example, a right door is a door that Samus enters by walking to the right.
;  * Primary vs secondary scrolling:
;       Primray scrolling is when the screen scrolls in the same direction as the door.
;       Secondary scrolling is when the screen scrolls perpendicularly to the primary direction.
;       For example, if Samus enters a right door while the screen is too high or too low, the screen
;       will scroll up or down to center itself (secondary scrolling) and to the right (primary scrolling).

; Version history:
; 2025-11-08 v1.0: Initial release.
;   * Known Issues:
;      > I got stuck in the ceiling after leaving Mother Brain's room - was able to get out and not get softlocked
;      > Escape timer flickers during horizontal door transitions
;      > Can see flickering of door tubes when moving down an elevator room that has door tubes -> confirmed this is an issue in vanilla, so I'm leaving it for now.
; 2026-02-?? v1.1:
;   * Fixed a softlock that could occur in certain situations due to a race condition. Thanks OmegaDragnet for the report.
;   * Added many options:
;      > PlaceSamusAlgorithm - default is now vanilla behavior. Thanks OmegaDragnet for the suggestion.
;      > SecondaryScrollDuration - can now granularly customize how long secondary scrolling takes.
;      > TwoPhaseTransition - can now make doors first do secondary scrolling, then primary, like vanilla.
;      > ScrollCurve - This controls how fast the camera accelerates/decelerates in each direction.
;   * The patch now tries to warn you when you make the door move fast enough to cause visual scrolling bugs.
;        It's really an educated guess though. I came up with how fast it checks for based on my own testing.
;        It will warn you in the console when assembling the patch if it thinks it is fast enough to risk bugs.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !Freespace80              = $80CD8E
    !Freespace80End           = $80FFC0
    !Freespace82              = $82F70F ; keep in mind there is space at $E310 still
    !Freespace82End           = $82FFFF
    !FreespaceAnywhere        = $B88000 ; Anywhere in banks $80-$BF
    !FreespaceAnywhereEnd     = $B8FFFF
    !RamBank                  = $7F0000
    !RamStart                #= $FB46+!RamBank

    !ScreenFadeDelay          = #$0004 ; ScreenFadeDelay: Controls how fast the screen fades to/from black. Higher = slower. Vanilla: #$000C

    !PrimaryScrollDuration    = $002C  ; ScrollDuration: How long the door transition screen scrolling will take, in frames. Vanilla: 0040h (basically).
                                       ;     > If you make this too low, you may get graphical glitches, and this patch will scream at you while it's assembling when it detects that this is possible.
                                       ;         (I came up with the threshold that makes the patch scream at you on my own through testing - make this value low at your own risk).
                                       ;         (The threshold also depends on which ScrollCurve you use).
                                       ;     > We generate lookup tables ScrollDuration entries long, so the larger the duration(s), the more freespace used.
                                       ;     > You can change primary/secondary scroll duration independently to make the screen take different "paths".
    !SecondaryScrollDuration #= !PrimaryScrollDuration*2/3

    !TwoPhaseTransition       = 0      ; TwoPhaseTransition: Determines whether primray and secondary scrolling occur sequentially (vanilla) or simultaneously.
                                       ;     0: Primary and seconary scrolling occur simultaneously.
                                       ;     1: Secondary scrolling first, then primary scrolling (like vanilla).
                                       ;     2: Primary scrolling first, then secondary scrolling.

    !PrimaryScrollCurve       = 1      ; ScrollCurve: Determines how the screen accelerates/decelerates during primary scrolling.
    !SecondaryScrollCurve     = 4      ;     1: quadratic ease in ease out.
                                       ;     2: ease out.
                                       ;     3: ease in.
                                       ;     4: bezier ease in ease out.
                                       ;     5: linear, like vanilla.

    !PlaceSamusAlgorithm      = 1      ; PlaceSamusAlgorithm: Determines which algorithm is used to place Samus after a door transition:
                                       ;     1: Vanilla. Like vanilla, default values are used if a negative distance to door is given.
                                       ;     2: The algorithm that was originally included in this patch. Places Samus at the door cap if it exists, otherwise uses default values. Ignores door distance to spawn value.
                                       ;     3: The door distance to spawn value is a hardcoded pixel offset from the edge of the screen.
                                       ;     4: Advanced mode - Uses extra !FreespaceAnywhere. Different values in the door distance to spawn have different behavior:
                                       ;        0000-8000: Vanilla behavior, i.e. algorithm 1.
                                       ;        8001-FFFE: Acts as algorithm 3, but ignores bit 8000h. All other bits are used as a hardcoded pixel offset from the edge of the screen.
                                       ;        FFFF: Acts as algorithm 2. Samus is placed at door cap, or at a default position if no door cap.
    
    !ReportFreespaceAndRamUsage = 1    ; Set to 0 to stop this patch from printing it's freespace and RAM usage to the console when assembled.

    ; Debug constants - These probably shouldn't be changed from their default state in the release version of your hack, but feel free to play with them.
    !ScreenFadesOut             = 1    ; Set to 0 to make the screen not fade out during door transitions. This was useful for testing this patch, but it looks unpolished, not really suitable for a real hack.
    !VanillaCode                = 0    ; Set to 1 to compile the vanilla door transition code instead of mine. Was useful for debugging.

    ; Don't touch. These constants are for the freespace usage report.
    !FreespaceAnywhereReportStart := !FreespaceAnywhere
    !Freespace80ReportStart := !Freespace80
    !Freespace82ReportStart := !Freespace82

    ; Vanilla variables
    !RamDoorTransitionFunctionPointer = $099C
    !RamGameState                     = $0998
    !RamDoorTransitionFrameCounter    = $0925
    !RamLayer1XPosition               = $0911
    !RamLayer1XSubPosition            = $090F
    !RamLayer1YPosition               = $0915
    !RamLayer1YSubPosition            = $0913
    !RamLayer1XDestination            = $0927
    !RamLayer1YDestination            = $0929
    !RamLayer2XPosition               = $0917
    !RamLayer2YPosition               = $0919
    !RamBG1XScroll                    = $B1
    !RamBG1XOffset                    = $091D
    !RamBG1YScroll                    = $B3
    !RamBG1YOffset                    = $091F
    !RamBG2XScroll                    = $B5
    !RamBG2XOffset                    = $0921
    !RamBG2YScroll                    = $B7
    !RamBG2YOffset                    = $0923
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

    ; note/todo: we can use 092b and 092d if we just stop the game from setting them

    undef "CurRamAddr"
}

; ====================================
; ============== NOTES ===============
; ====================================
{
    ; roadmap/ideas:
    ; 1.0:
    ;  - Parity with vanilla door transition functionality but with better/faster animation and customizability
    ;  - Fixed dma flickering - now, if you place doors not in the middle of the screen, they won't flicker at all during the transition, because I move the DMA Y position dynamically.
    ; 1.1:
    ;  - add a way to control where samus is placed in each transition if the user wants it to work that way
    ;  - figure out a way to make the patch error out or report if the speed is too fast
    ;  - add more door movement speed algorithm options, i.e. ease in and ease out, maybe being able to customize acceleration/deceleration speeds too. add a linear scrolling option too.
    ;  - option to pad level data with zeroes to avoid seeing artifacts (in smaller rooms anyway) - ex moving upwards while screen not aligned out of post phantoon room shows artifacts.
    ;  - and add an option for the door to align itself before doing main scrolling like vanilla.
    ; 1.2 (tentative):
    ;  - customization option to allow an option to NOT align the screen. this would be useful for rooms with a continuous wall of door transition tiles on the edge - i.e. outdoor rooms
    ;  - when H door is centered, flashing is intersecting escape timer... fix
    ;  - place doors anywhere on screen a-la "door glitch fix" https://metroidconstruction.com/resource.php?id=44
    ;  - place door transition tiles as close to the edge of the screen as you want
    ; 1.x:
    ;  - "async" music loading a-la https://github.com/tewtal/sm_practice_hack/blob/4d6358f022b5a0d092419dd06a3b60c2bd27927a/src/menu.asm#L283 - look for the quickboot_spc_state stuff by nobodynada
}

; ====================================
; ========= MACROS/FUNCTIONS =========
; ====================================
{
    ; The ultimate cheat code: Making the assembler do all the work.

    function abs(num) = select(less(num, 0), num*-1, num)

    ; All these functions take in and return a value from 0 to 1. The inputs and outputs are scaled when these are called.
    function bezierEaseInEaseOut(x) = (x**2)*(3-2*x)
    function quadraticEaseInEaseOut(x) = 2*x-(1/2)-2*(x-(1/2))*abs(x-(1/2)) ; these are easier to write than they are to read, heh... I started with x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2
    function quadraticEaseOut(x) = (1-(1-x)*(1-x))
    function quadraticEaseIn(x) = (x*x)
    function linear(x) = x
    
    macro generateLookupTableEntry(t, ScrollType, CheckMultiplier)
        !x = (<t>/!<ScrollType>ScrollDuration)
        !threshold = $10

        if !<ScrollType>ScrollCurve == 4
            !func = bezierEaseInEaseOut
        endif
        if !<ScrollType>ScrollCurve == 1
            !func = quadraticEaseInEaseOut
        endif
        if !<ScrollType>ScrollCurve == 2
            !func = quadraticEaseOut
        endif
        if !<ScrollType>ScrollCurve == 3
            !func = quadraticEaseIn
        endif
        if !<ScrollType>ScrollCurve == 5
            !func = linear
            !threshold = $09
        endif

        db $100*!func(!x)

        ; Check to see if the screen will move too fast. The CheckMultiplier for secondary scrolling is a bit of a heuristic.
        if <t> > 0
            if abs($100*!func(<t>/!<ScrollType>ScrollDuration)-$100*!func((<t>-1)/!<ScrollType>ScrollDuration)) > !threshold*<CheckMultiplier>
                print "WARNING! THE CAMERA IS NEARLY FAST ENOUGH DURING THE DOOR TRANSITION TO CAUSE VISUAL BUGS! USE AT YOUR OWN RISK!"
                print "   I came up with this check on my own through experimentation, so it may not be 100% accurate. <ScrollType>"
            endif
        endif
        undef "func"
        undef "x"
        undef "threshold"
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
            JSR InitializeLayer2Destinations
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

    org $80AE29
    UpdateBGScrollOffsets: {
        ; Difference between this and vanilla: BG2 offsets are based on layer 1 destination instead of layer 1 position
        ; This was done because not aligning the door screwed this up compared to vanilla; this accounts for it.
        LDA !RamBG1XScroll : SEC : SBC !RamLayer1XPosition : STA !RamBG1XOffset
        LDA !RamBG1YScroll : SEC : SBC !RamLayer1YPosition : STA !RamBG1YOffset
        LDA !RamBG2XScroll : SEC : SBC !RamLayer1XDestination : STA !RamBG2XOffset
        LDA !RamBG2YScroll : SEC : SBC !RamLayer1YDestination : STA !RamBG2YOffset
        RTS
    }
    warnpc $80AE4E

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
            INC !RamDoorTransitionFrameCounter
            LDA !RamDoorDirection : AND #$0003 : CMP #$0002 : BNE +
            ; Seemingly, if we run this, we need to return and wait for next frame to actually scroll.
            ; Seems like the engine can only DMA 1 horizontal row of tiles onto the screen per frame.
            ; $0968 was getting overwritten when I tried to continue after this call. $808DAC executes the DMA.
            JSL DrawTopRowOfScreenForDownwardsTransition : INC !RamDoorTransitionFrameCounter : CLC : RTS
        +

            if !TwoPhaseTransition > 0
                LDA !RamDoorTransitionFrameCounter : DEC : BNE +
                
                ; This is kind of a hack. If we don't scroll the screen in both directions at the beginning,
                ; part of the door tube can be overwritten with black when scrolling starts.
                ; So, scroll both directions, update the BG scrolls, then reset our position, and update BG scrolls again.
                ; Only do it once, at the beginning of the two phase scrolling - after that, we're good...
                ; In the long run I would like to find a better solution but this works for now.
                JSL ScrollCameraX; : PHP
                JSL ScrollCameraY; : PHP
                JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
                LDA !RamLayer1XStartPos : STA !RamLayer1XPosition
                LDA !RamLayer1YStartPos : STA !RamLayer1YPosition
                JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
                INC !RamDoorTransitionFrameCounter
                CLC : RTS
                ;BRA ++

            +   ; need to do secondary direction first, then primary direction
                LDA !RamDoorDirection : BIT #$0002
                if !TwoPhaseTransition == 1
                    BNE +
                endif
                if !TwoPhaseTransition > 1
                    BEQ +
                endif
                ; X direction is primary
                JSL ScrollCameraY : PHP : BCC +++
                JSL ScrollCameraX : +++ : PHP
                BRA ++
            +   ; Y direction is primary
                JSL ScrollCameraX : PHP : BCC +++
                JSL ScrollCameraY : +++ : PHP
            ++  ; continue
            endif
            if !TwoPhaseTransition == 0
                JSL ScrollCameraX : PHP
                JSL ScrollCameraY : PHP
            endif

            JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
            INC !RamDoorTransitionFrameCounter
            PLP : BCC +
            PLP : BCC ++
            JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling ; why does vanilla call this twice? didn't really observe any effects from commenting this out (yet)
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
            
            LDA !tPrimaryDirectionFlag : BNE +
            LDA.w #!SecondaryScrollDuration-1 : BRA ++
        +   LDA.w #!PrimaryScrollDuration-1
        ++  CMP !tCameraTableIndex : BEQ .finish : BPL .continue
        .finish
            LDA !tLayer1Destination : STA !tLayer1Position
            LDA !tLayer2Destination : STA !tLayer2Position
            PLB : PLA : PLY : PLX : PLP : SEC : RTS ; done
        .continue
            PHK : PLB ; DB = current bank
            
            LDA !tPrimaryDirectionFlag : BNE +
            LDA !tCameraTableIndex : TAX : LDA .lookupTables_secondary,x : BRA ++
        +   LDA !tCameraTableIndex : TAX : LDA .lookupTables_primary,x
        ++  AND #$00FF : BNE + : INC : +
            
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
        .return
            PLB : PLA : PLY : PLX : PLP : CLC : RTS ; return, not complete

        .lookupTables:
        ..primary
        !tCounter = 0
        while !tCounter < !PrimaryScrollDuration
            %generateLookupTableEntry(!tCounter, Primary, 1)
            !tCounter #= !tCounter+1
        endwhile
        ..secondary
        !tCounter = 0
        while !tCounter < !SecondaryScrollDuration
            %generateLookupTableEntry(!tCounter, Secondary, 2)
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
    org $82E3CF : JSL PositionSamus : BRA SkipPlacingSamus
    org $82E3E5
        SkipPlacingSamus:

    org !FreespaceAnywhere
    PositionSamus: {
            ; move Samus to door cap position for now while I'm testing this. Actually I might just stick with this.
            PHX : PHP : PHB
            REP #$30

            if !PlaceSamusAlgorithm == 1
                JMP .vanilla
            endif
            if !PlaceSamusAlgorithm == 2
                ; mine
            endif
            if !PlaceSamusAlgorithm == 3
                BRA .directOffset
            endif
            if !PlaceSamusAlgorithm == 4
                LDX $078D : LDA $830008,x ; A = [$83:0000 + [door pointer] + 8] (distance to spawn)
                BPL .vanilla
                CMP #$8000 : BEQ .vanilla
                CMP #$FFFF : BNE .directOffset
                ; else, mine
            endif

        
        if !PlaceSamusAlgorithm == 2 || !PlaceSamusAlgorithm == 4
        .mine
            ; first set Samus to correct screen
            JSR .mySetSamusScreenX
            JSR .mySetSamusScreenY

            ; then set her position on the screen
            LDA !RamDoorDirection
            ASL A       ;\
            CLC         ;|
            ADC #$E68A  ;) A = [$E68A + [door direction] * 2] (PLM ID)
            TAX         ;|
            LDA $0000,x ;/
            BNE ..doorcap ; If door has door cap, use it's X and Y positions to set Samus
            ; else, use my defaults:
        ..nodoorcap
            LDA !RamDoorDirection : BIT #$0002 : BNE ...verticalTransition
        ...horizontalTransition
            LDA !RamLayer1XDestination : STA !RamSamusXPosition
            BRA ...continue
        ...verticalTransition
            LDA !RamLayer1YDestination : STA !RamSamusYPosition
        ...continue
            LDX !RamDoorDirection : AND #$0003
            LDA .defaults_mine : JSR .moveSamus
            JMP .finish

        ..doorcap
            LDX $078D : LDA $830004,x : TAX ; X = [$83:0000 + [door pointer] + 4] (X and Y positions)
            LDA !RamDoorDirection : AND #$0003 : BIT #$0002 : BNE ...verticalTransition
        ...horizontalTransition
            LDA !RamLayer1XDestination : STA !RamSamusXPosition
            TXA : AND #$000F : ASL #4 : ORA !RamSamusXPosition : STA !RamSamusXPosition
            BRA ...continue
        ...verticalTransition
            LDA !RamLayer1YDestination : STA !RamSamusYPosition
            TXA : XBA : AND #$000F : ASL #4 : ORA !RamSamusYPosition : STA !RamSamusYPosition
            LDA !RamDoorDirection : BIT #$0001 : BEQ ....samusMovingDown
        ....samusMovingUp
            LDA !RamSamusYPosition : SEC : SBC #$0038 : STA !RamSamusYPosition
            BRA ...continue
        ....samusMovingDown
            LDA !RamSamusYPosition : CLC : ADC #$0010 : STA !RamSamusYPosition
        ...continue
            JMP .finish
        endif

        if !PlaceSamusAlgorithm == 1 || !PlaceSamusAlgorithm == 4
        .vanilla
            LDX $078D : LDA $830008,x ; A = [$83:0000 + [door pointer] + 8] (distance to spawn)
            TAX : BPL + ; If negative, use default values
            LDX #$0180 ; Vertical default
            LDA !RamDoorDirection : BIT #$0002 : BNE + ;\
            LDX #$00C8                                 ;) If horizontal door, use horizontal default
        +   TXA ; A and X contain door distance to spawn or default
            LSR #2 : PHA ; Convert vanilla door distance to spawn to pixels (vertical doors still need adjustment)
            LDA !RamDoorDirection : BIT #$0002 : BNE ..verticalTransition
        ..horizontalTransition
            LDA !RamSamusXPosition : AND #$00FF : CLC : ADC !RamLayer1XStartPos : STA !RamSamusXPosition ; vanilla code to set samus to correct screen
            JSR .mySetSamusScreenY
            PLX : JSR .moveSamus
            LDA !RamDoorDirection : BIT #$0001 : BEQ ...samusMovingRight
        ...samusMovingLeft
            LDA #$0007 : TRB !RamSamusXPosition ; Samus X position &= ~7
            BRA .finish
        ...samusMovingRight
            LDA #$0007 : TSB !RamSamusXPosition ; Samus X position |= 7
            BRA .finish
        ..verticalTransition
            LDA $01,s : LSR #3 : EOR #$FFFF : INC : CLC : ADC $01,s : STA $01,s ; Fix distance to door -> pixel conversion inaccuracy for vertical doors (remove 1/8th of the distance, since 38h is 7/8ths of 40h - see vanilla $82DE12)
            LDA !RamSamusYPosition : AND #$00FF : CLC : ADC !RamLayer1YStartPos : STA !RamSamusYPosition ; vanilla code to set samus to correct screen
            JSR .mySetSamusScreenX
            PLX : JSR .moveSamus
            BRA .finish
        endif

        if !PlaceSamusAlgorithm == 3 || !PlaceSamusAlgorithm == 4
        .directOffset
            JSR .mySetSamusScreenX
            JSR .mySetSamusScreenY
            LDX $078D : LDA $830008,x ; A = [$83:0000 + [door pointer] + 8] (distance to spawn)
            AND #$7FFF
            JSR .moveSamus
            BRA .finish
        endif

        .finish
            LDA !RamSamusXPosition : STA !RamSamusPrevXPosition
            LDA !RamSamusYPosition : STA !RamSamusPrevYPosition
            PLB : PLP : PLX : RTL

        ; input: X = distance to move
        .moveSamus
            LDA !RamDoorDirection : BIT #$0001 : BEQ +
            TXA : EOR #$FFFF : INC : TAX
        +   PHX
            LDA !RamDoorDirection : BIT #$0002 : BNE ..verticalTransition
        ..horizontalTransition
            PLA : CLC : ADC !RamSamusXPosition : STA !RamSamusXPosition
            RTS
        ..verticalTransition
            PLA : CLC : ADC !RamSamusYPosition : STA !RamSamusYPosition
            RTS
        
        .mySetSamusScreenX
            LDA !RamLayer1XDestination : AND #$FF00 : PHA : LDA !RamSamusXPosition : AND #$00FF : ORA $01,s : STA !RamSamusXPosition : PLA
            RTS
        
        .mySetSamusScreenY
            LDA !RamLayer1YDestination : AND #$FF00 : PHA : LDA !RamSamusYPosition : AND #$00FF : ORA $01,s : STA !RamSamusYPosition : PLA
            RTS

        .defaults ; right, left, down, up
        ..mine
        if !PlaceSamusAlgorithm == 2 || !PlaceSamusAlgorithm == 4
            dw $0030 ; right
            dw ($0100-$30)*-1 ; left
            dw $0040 ; down
            dw ($0100-$1C)*-1 ; up
        endif
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

    org $8097F7
        JSR CheckIfVramUpdateNeeded_horizontal_topOfScreen

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
        +   LDA $9031 ; instruction replaced by hijack
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
