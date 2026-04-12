lorom

; BY DEFAULT, THIS PATCH REQUIERS TOTAL'S SPC TRANSFER OPTIMIZATION!!! READ MORE BELOW. https://patrickjohnston.org/ASM/ROM%20data/Super%20Metroid/Other's%20work/total%20SPC%20transfer%20optimisation.asm

warnings disable Wfeature_deprecated

math round off
math pri on

; Nodever2's door transitions
;   By now, several of us have rewritten door transitions - this is my take on it.
;   This patch includes many customization options, allowing you to make them work exactly how you want.
;   V1.0 showcase video: https://youtu.be/rkpMoOeFj3Y
;   V1.1 showcase video: https://youtu.be/3M7aj3aaaks

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
;     > THIS IS REQUIRED BY DEFAULT!!! This makes music load faster. See !AsyncMusicUploadEnabled option if you don't want to use this.
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
; 2026-04-04 v1.1:
;   * VRAM transfers now occur over a longer period of time, resulting in a shorter fblank period each frame. This occurs during scrolling and does not slow down the total length of the transition.
;   * SPC music data transfers now start as soon as the screen fades to black and happen in the background throughout the rest of the transition, instead of happening all at once after scrolling stops.
;     This greatley reduces if not eliminates the hang time at the end of a door transition where there is a music transition.
;   * Added many options:
;      > PlaceSamusAlgorithm - default is now vanilla behavior. Thanks OmegaDragnet for the suggestion.
;      > SecondaryScrollDuration - can now granularly customize how long secondary scrolling takes. This replaces the option TransitionAnimation - this is just a more customizable version.
;      > TwoPhaseTransition - can now make doors first do secondary scrolling, then primary, like vanilla.
;      > ScrollCurve - This controls how fast the camera accelerates/decelerates in each direction.
;   * The patch now tries to warn you when you make the door move fast enough to cause visual scrolling bugs.
;        It's really an educated guess though. I came up with how fast it checks for based on my own testing.
;        It will warn you in the console when assembling the patch if it thinks it is fast enough to risk bugs.
;   * Fixed a softlock that could occur in certain situations due to a race condition. Thanks OmegaDragnet for the report.
;   * Fixed scrolling bugs for BG1, BG2 that would occur when the screen is scrolling while OOB in the negative X direction.
;   * Updated SM's scrolling code to not render OOB tiles or screen wrapped tiles. Collision is unaffected.
;   * Moved RAM usage in hopes that the conflict with amoeba's scrolling sky is resolved.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !Freespace80              = $80CD8E
    !Freespace80End           = $80FFC0
    !Freespace82              = $82F70F ; there is space at $E310 and $E675 still
    !Freespace82End           = $82FFFF
    !FreespaceAnywhere        = $B88000 ; Anywhere in banks $80-$BF
    !FreespaceAnywhereEnd     = $B8FFFF
    !RamBank                  = $7F0000
    !RamStart                #= $FC02+!RamBank ; $FB02-$FC01 is used by Amoeba's Custom Scrolling Sky patch; $FE00-$FFFF is used by saveload patch

    !ScreenFadeDelay        = #$0004 ; ScreenFadeDelay: Controls how fast the screen fades to/from black. Higher = slower. Vanilla: #$000C

    !PrimaryScrollDuration  = $002C  ; ScrollDuration: How long the door transition screen scrolling will take, in frames. Vanilla: 0040h (basically).
                                     ;     > If you make this too low, you may get graphical glitches, and this patch will scream at you while it's assembling when it thinks that this is possible.
                                     ;         (I came up with the threshold that makes the patch scream at you through testing on my own, may not be 100% accurate - make this value low at your own risk).
                                     ;         (The threshold also depends on which ScrollCurve you use).
                                     ;     > We generate lookup tables ScrollDuration entries long, so the larger the duration(s), the more freespace used.
                                     ;     > You can change primary/secondary scroll duration independently to make the screen take different "paths".
    !SecondaryScrollDuration #= !PrimaryScrollDuration*1/2

    !TwoPhaseTransition         = 0  ; TwoPhaseTransition: Determines whether primray and secondary scrolling occur sequentially (vanilla) or simultaneously.
                                     ;     0: Primary and seconary scrolling occur simultaneously.
                                     ;     1: Secondary scrolling first, then primary scrolling (like vanilla).
                                     ;     2: Primary scrolling first, then secondary scrolling.

    !PrimaryScrollCurve         = 1  ; ScrollCurve: Determines how the screen accelerates/decelerates during primary scrolling.
    !SecondaryScrollCurve       = 4  ;     1: quadratic ease in ease out.
                                     ;     2: ease out.
                                     ;     3: ease in.
                                     ;     4: bezier ease in ease out.
                                     ;     5: linear, like vanilla.

    !PlaceSamusAlgorithm        = 1  ; PlaceSamusAlgorithm: Determines which algorithm is used to place Samus after a door transition:
                                     ;     1: Vanilla. Like vanilla, default values are used if a negative distance to door is given.
                                     ;     2: The algorithm that was originally included in this patch. Places Samus at the door cap if it exists, otherwise uses default values. Ignores door distance to spawn value.
                                     ;     3: The door distance to spawn value is a hardcoded pixel offset from the edge of the screen.
                                     ;     4: Advanced mode - Uses extra !FreespaceAnywhere. Different values in the door distance to spawn have different behavior:
                                     ;        0000-8000: Vanilla behavior, i.e. algorithm 1.
                                     ;        8001-FFFE: Acts as algorithm 3, but ignores bit 8000h. All other bits are used as a hardcoded pixel offset from the edge of the screen.
                                     ;        FFFF: Acts as algorithm 2. Samus is placed at door cap, or at a default position if no door cap.
    
    !AsyncMusicUploadEnabled    = 1  ; AsyncMusicUploadEnabled: If 0, none of the new music upload code changes will be assembled by this patch.
                                     ;     IF ENABLED, TOTAL'S SPC TRANSFER OPTIMIZATION PATCH IS REQUIRED TO ALSO HAVE INSTALLED IN YOUR HACK!!!
                                     ;     GET IT HERE: https://patrickjohnston.org/ASM/ROM%20data/Super%20Metroid/Other's%20work/total%20SPC%20transfer%20optimisation.asm
                                     ;     Disable if you have conflicts, issues, or otherwise don't want the way the game loads music to be changed.
                                     ;     None of the other music-related options will take effect if this is 0.

    !ReportFreespaceAndRamUsage = 1  ; Set to 0 to stop this patch from printing it's freespace and RAM usage to the console when assembled.

    !BlackTile = #$8081 ; This is the level data for 1 solid black tile in vanilla. The patch writes this in a few places where you can see OOB.

    ; Debug settings below - These probably shouldn't be changed from their default state in the release version of your hack, but feel free to play with them.
    !ScreenFadesOut             = 1       ; Set to 0 to make the screen not fade out during door transitions. This was useful for testing this patch, but it looks unpolished, not really suitable for a real hack.
    !VanillaCode                = 0       ; Set to 1 to compile the vanilla door transition code instead of mine. Was useful for debugging.
    !VramChunkMax               = $0800   ; Maximum bytes to DMA per frame during door transition VRAM updates.
                                          ;     Vanilla transfers all data in one frame (~50 scanlines of forced blank), which can cause lag.
                                          ;     This splits large transfers into chunks of !VramChunkMax bytes per frame.
                                          ;     At $0800 (2048 bytes), each chunk takes ~12 scanlines. A typical ~8KB transfer splits into ~4 frames.
                                          ;     Set to $FFFF to disable chunking (vanilla behavior).
    !EarlyMusicUpload               = 1   ; EarlyMusicUpload: Start async SPC music upload as early as possible during door transitions, instead of waiting until the end.
                                          ;     0: Vanilla timing - old music plays throughout scrolling.
                                          ;     1: Start upload as soon as screen fades to black.
    !WaitForMusicUploadBeforeFadeIn = 1   ; Block the door transition fade-in until the async music upload has fully completed.
                                          ;     0: Fade in immediately after queue clears (may result in silent main gameplay until music loading completes).
                                          ;     1: Wait for async upload completion before fade-in (audio and visuals stay in sync).
    !MusicStopWaitFrames            = $08 ; Frames to wait between sending "stop music" ($00) and "start fast upload" ($FE) in EarlyStart.
                                          ;     Audio glitches can occur if this is too low, as the old music is mid-note and does not have time to stop playing while new music data loads.
                                          ;     Only used when !EarlyMusicUpload = 1; otherwise vanilla code naturally has the 8 frame wait.
                                          ;     Range: $0001..$7FFF (signed 16-bit delta). $08 matches vanilla timing.

    ; Don't touch. These constants are for the freespace usage report.
    !FreespaceAnywhereReportStart := !FreespaceAnywhere
    !Freespace80ReportStart       := !Freespace80
    !Freespace82ReportStart       := !Freespace82

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
    !RamBG1XBlock                     = $0907
    !RamBG1YBlock                     = $0909
    !RamBG2XBlock                     = $090B
    !RamBG2YBlock                     = $090D
    !RamLayer1XBlock                  = $08F7
    !RamLayer1YBlock                  = $08F9
    !RamLayer2XBlock                  = $08FB
    !RamLayer2YBlock                  = $08FD
    !RamBlocksToUpdateXBlock          = $0990
    !RamBlocksToUpdateYBlock          = $0992
    !RamVramBlocksToUpdateXBlock      = $0994
    !RamVramBlocksToUpdateYBlock      = $0996
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
    !RamDoorScrollingFinishedFlag     = $0931
    !RamDoorVramUpdateFlag            = $05BC ; 16-bit. Bit 15 = VRAM transfer pending.
    !RamDoorVramUpdateDestination     = $05BE ; 16-bit. VRAM destination address (in words).
    !RamDoorVramUpdateSource          = $05C0 ; 16-bit. DMA source address (low 16 bits).
    !RamDoorVramUpdateSourceBank      = $05C2 ; 8-bit. DMA source bank.
    !RamDoorVramUpdateSize            = $05C3 ; 16-bit. DMA transfer size (in bytes).
    !RamUploadingToApuFlag            = $0617
    !RamMusicTimer                    = $063F
    !RamMusicDataIndex                = $07F3
    !RamMusicTrackIndex               = $07F5
    !RamMusicCurrentTrack             = $064C ; Never read. See !RamMusicTrackIndex instead. $FF means new data is being uploaded.
    !RamRoomMusicDataIndex            = $07CB
    !RamNmiRequestFlag                = $05B4 ; 8-bit.
    !RamNmiCounter                    = $05B8 ; Includes lag frames. 16-bit.

    ; Vanilla ROM data that we read as a constant. Writing the expected value here so patch conflict checkers will detect if another patch modifies this address.
    !UpDoorYDestinationOffset = $80ADF0  ; Vanilla value: $0020 (operand of ADC #$0020 at $80:ADEF)
    org !UpDoorYDestinationOffset : dw $0020

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
    !RamAsyncSpcState                            := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; State number (0=idle, else state handler address)
    !RamAsyncSpcDataY                            := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; Current source pointer (Y register into bank)
    !RamAsyncSpcDataBank                         := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; Current source bank (low byte used, stored as word for convenience)
    !RamAsyncSpcBlockSize                        := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; Remaining bytes in current block
    !RamAsyncSpcIndex                            := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; Current handshake counter byte (low byte used)
    !RamAsyncSpcStopWaitTarget                   := !CurRamAddr : !CurRamAddr := !CurRamAddr+2 ; EarlyStart stop-wait: target value of !RamNmiCounter at which StateStopWait sends $FE
    !RamEnd                                      := !CurRamAddr

    ; note/todo: we can use 092b and 092d if we just stop the game from setting them

    undef "CurRamAddr"
}

; ====================================
; ============== NOTES ===============
; ====================================
{
    ; 1.2 (tentative):
    ;  - customization option to allow an option to NOT align the screen. this would be useful for rooms with a continuous wall of door transition tiles on the edge - i.e. outdoor rooms
    ;  - when H door is centered, flashing is intersecting escape timer... fix
    ;  - place doors anywhere on screen a-la "door glitch fix" https://metroidconstruction.com/resource.php?id=44
    ;  - place door transition tiles as close to the edge of the screen as you want
    ;  - make the SM scrolling code updates only apply if two phase scrolling is disabled (this would require moving secondary scrolling back to before the new room gets loaded as in vanilla - a big change)
    ; 1.x:
    ;  - todo: reach out to ocesse,
    ;  - NOTE: The easing multiply only handles 8-bit distances (0-255 pixels).
    ;         Primary scrolling uses fixed screen offsets ($0100 horizontal, $00E0 vertical),
    ;         and the $0100 case is handled by a fast-path that skips the multiply entirely.
    ;         Secondary scrolling (alignment) is always <= 1 screen, so distance fits in 8 bits.
    ;         If a future feature needs distances > 255, extend to 16x8 multiply:
    ;         split distance into high/low bytes, multiply each by the table value separately,
    ;         then combine: result = (dist_hi * table_val) << 8 + (dist_lo * table_val).
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
            LDA !RamLayer1YPosition-1 : BPL +
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
            LDA !RamLayer1XPosition-1 : BPL +
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
    ; --- Layer 2 scrolling during door transitions ---
    ;
    ; How Layer2Destination is calculated (this function):
    ;   L1 position is temporarily set to L1 destination, then CalculateLayer2Position ($A2F9/$A33A)
    ;   computes L2 from L1 using the room's parallax ratio. The result is saved as L2 destination.
    ;   For upward doors, L1Y is additionally offset by !UpDoorYDestinationOffset ($0020) before the
    ;   calculation, matching the vanilla up-door Y adjustment at $80:ADCF.
    ;
    ; How Layer2StartPos is calculated:
    ;   The vanilla direction-specific setup routines ($AD4A/$AD74/$AD9E/$ADC8) compute L2 at the
    ;   destination via CalculateLayer2Position, then apply a flat screen offset to BOTH L1 and L2:
    ;     Right ($AD4A): L2X = parallax(L1X_dest) - $0100, then L1X -= $0100
    ;     Left  ($AD74): L2X = parallax(L1X_dest) + $0100, then L1X += $0100
    ;     Down  ($AD9E): L2Y = parallax(L1Y_dest) - $00E0, then L1Y -= $00E0
    ;     Up    ($ADC8): L2Y = parallax(L1Y_dest + $1F) + $00E0, then L1Y += $0100
    ;   SetupScrolling then saves L2 position as Layer2StartPos.
    ;
    ; How Layer2 scrolls:
    ;   ScrollCamera applies the same absolute pixel offset (from the lookup table) to both L1 and L2,
    ;   using each layer's own start position. Since L2 start = L2 dest ± (same screen offset as L1),
    ;   both layers cover the same distance and arrive at their destinations simultaneously.
    ;
    ; Known limitation:
    ;   Because the screen offset is applied as a flat value (not via parallax), L2's intermediate
    ;   positions during the scroll are slightly incorrect for the parallax ratio. For example, with
    ;   50% parallax and a 256px scroll, L2 should start 128px from its destination, but actually
    ;   starts 256px away. Tiles on L2 that use non-fading palette colors would appear slightly out
    ;   of place during the scroll. This matches vanilla behavior and is nearly invisible in practice
    ;   since L2 is almost always fully faded to black during transitions.
    ;
    InitializeLayer2Destinations: {
            LDA !RamLayer1XPosition : PHA
            LDA !RamLayer1YPosition : PHA
            LDA !RamLayer1XDestination : STA !RamLayer1XPosition
            LDA !RamLayer1YDestination : STA !RamLayer1YPosition
            LDA !RamDoorDirection : AND #$0003 : CMP #$0003 : BNE +
            LDA !UpDoorYDestinationOffset : CLC : ADC !RamLayer1YPosition : STA !RamLayer1YPosition ; I hate vertical doors
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
                JSL ScrollCameraX
                JSL ScrollCameraY
                JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
                LDA !RamLayer1XStartPos : STA !RamLayer1XPosition
                LDA !RamLayer1YStartPos : STA !RamLayer1YPosition
                JSL CalculateBGScrollsAndUpdateBGGraphicsWhileScrolling
                INC !RamDoorTransitionFrameCounter
                CLC : RTS

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
            SEC : RTS ; Done with both horizontal and vertical scrolling, return carry set
        +   PLP : ++ : CLC : RTS ; Not done, return carry clear
    }

    CalculateLayer2Position: {
            JSR $A2F9 ; X
            JSR $A33A ; Y
            RTS
    }
    warnpc $80AF02

    org !FreespaceAnywhere
    ; Put all variables that ScrollCamera uses on the stack, so we can reuse the code for X and Y.
    ; Since all of this is being done in an interrupt, we don't want to use misc RAM where possible because that could
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

    ScrollCamera: {
        ; Scrolls the screen. This function is expected to be called every frame until this function returns carry set
        ; Assumes REP#$30 before calling
        ; Parameters listed below:

        !tBaseStackOffset #= 1+2+1+2+2+2+1 ; +1 for stack base, +2 for return addr, +1 for php, +2 for phx, +2 for phy, +2 for pha, +1 for phb
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
            ; yes, using the hardware registers is bad during the interrupt, but this is a vanilla problem already.
            ; 8x8 hardware multiply: (table_value * distance) >> 8
            ; A = distance (from TYA above), $01,s = table_value
            SEP #$20
            STA $4202          ; distance (low byte) -> multiplicand
            LDA $01,s          ; table_value
            STA $4203          ; triggers multiply
            REP #$20           ; 3 cycles \
            NOP #3             ; 6 cycles ) 9 cycle wait for hardware result
            LDA $4217          ; A_lo = multiply result high byte, A_hi = joypad garbage
            AND #$00FF         ; mask to just the result
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
    ; Need to patch $80A3DF/$80AB78
    ; (this took a ton of digging to figure out that this was the problem and solution... heh...)

    ; ===== FIX WHEN VERTICALLY OOB =====

    org $80A9E5
    JMP GetAddressOfBlocksToUpdateHandleNegative

    org !Freespace80
    GetAddressOfBlocksToUpdateHandleNegative: {
        ; $36 = address of blocks to update (in bank $7F)
        ; Y: negative flag
        ; A is in 16 bit mode here (callers use REP #$20; PHP at $A9E4 saved it)

        LDY #$0000
        LDA !RamBlocksToUpdateYBlock

        ; new code: set negative flag
        BPL +
        INY
        EOR #$FFFF : INC

    +   SEP #$20 ; 8-bit A for hardware multiply
        STA $4202 ; multiplicand A (Y block, positive)
        LDA !RamRoomWidthInBlocks
        STA $4203 ; multiplicand B (room width) - multiplication starts on this write
        PHB
        REP #$30

        NOP #4 ; wasting more time than I need probably, I don't feel like counting cycles

        LDA $4216 ; multiplication result

        ; new code: check negative flag
        DEY : BNE +
        EOR #$FFFF : INC

    +   CLC : ADC !RamBlocksToUpdateXBlock
        ASL
        CLC : ADC #$0002
        TXY : BEQ + : CLC : ADC #$9600 ; If background: add 9600
    +   STA $36

        JMP $AA0B ; return
        .freespace
    }
    !Freespace80 := GetAddressOfBlocksToUpdateHandleNegative_freespace
    warnpc !Freespace80End

    org $80AA0B : JSR SetTileDataSourceBankByte
    org $80AAA4 : LDX #$0000 : JSR SetBlockToUpdate : NOP #2

    ; ===== FIX WHEN HORIZONTALLY OOB =====
    ; handle vertical scrolling when the screen is at a negative X pos.

    org $80ABA5 : JSR SetTileDataSourceBankByte
    org $80AC57 : LDX #$0001 : JSR SetBlockToUpdate : NOP #2

    org !Freespace80
    ; A: Layer 1/2 Y block
    ; Y: BG1/2 Y block
    ; PSR.N flag: Set based on A
    ; A: Tile address without bank byte
    SetTileDataSourceBankByte: {
            CPX #$0000 : BNE ++ ; background
            CMP #$0000 : BMI +
        ++  LDA #$007F : RTS
        +   LDA #$007E : RTS
    }

    ; Parameters:
    ;   X: 1C for BG, 0 for FG.
    ;   Y: Offset into $7F to load from.
    ; Returns:
    ;   A: Offset into level data array or BG data array.
    ;   PSR.N: Set based on A.
    GetPotentialBlockOffset: {
            REP #$20
            TYA : CLC : ADC $36
            INX : DEX : BNE .background
        .foreground
            DEC #2                ; A = offset into layer 1 level data
            RTS
        .background
            SEC : SBC #$9602      ; A = offset into layer 2 BG data
            RTS
    }

    ; This handles negative indexes by loading a solid black tile instead of reading out of bounds like vanilla does.
    ; Parameters:
    ;   $01,s (before JSR) -> $05,s (after JSR and PHX): 1C for BG, 0 for FG.
    ;   $03,s (before JSR) -> $07,s (after JSR and PHX): Offset of first block of next row
    ;   $05,s (before JSR) -> $09,s (after JSR and PHX): Offset of first block of current row
    ;   X: 0 for vertical scrolling. 1+ for horizontal scrolling.
    ;   Y: Offset into [$36] to load from.
    ; Returns:
    ;   A: Block to update.
    SetBlockToUpdate: {
            PHX ; If you change stack use, update the stack relative addressing below
            LDA $05,s : TAX : JSR GetPotentialBlockOffset
            BMI .blackTile              ; if attempting to load from before the start of data - black tile
            CMP $07B9 : BPL .blackTile  ; if attempting to load from after the end of data - black tile
            TAX : LDA $01,s : BEQ .horizontalScrolling
        .verticalScrolling
            TXA : CMP $07,s : BPL .blackTile ; If current block is on the Y level after the one we started at, load black tile.
            CMP $09,s : BMI .blackTile       ; If current block is on a different Y level than we started at, load black tile.
            BRA .loadTile
        .horizontalScrolling
            LDX !RamBlocksToUpdateXBlock : BMI .blackTile   ; X block < 0
            CPX !RamRoomWidthInBlocks : BPL .blackTile      ; X block >= room width
        .loadTile
            LDA [$36],y : BRA .finish
        .blackTile
            LDA !BlackTile        
        .finish
            PLX
            STA $093B : AND #$03FF ; instructions replaced by hijack
            RTS
        .freespace
    }
    !Freespace80 := SetBlockToUpdate_freespace
    warnpc !Freespace80End


    ; ===== FIX ROOM WRAPPING =====

    ; vertical scrolling
    org $80AC4D : LDA $0992 : JMP GetOffsetOfNextRow : GetOffsetOfNextRowReturn: : LDY #$0000 : PHX ; Store offset of first block of next row in stack
    org $80AD16 : JMP ReturnFromUpdateLevelBGData ; Fix stack

    org !Freespace80
    ReturnFromUpdateLevelBGData: {
        PLX
        INC $0970,x
        PLA : PLA ; new additions
        PLB : PLP : RTS
    }

    ; Parameters:
    ;   A: Blocks to update Y block
    ; Returns:
    ;   $01,s: Offset of the first block in the next row of blocks after the current one. i.e. if the current block is in row 3, Y will have the offset of the first block in row 4.
    ;   $03,s: Offset of the first block in the current row of blocks after the current one. i.e. if the current block is in row 3, Y will have the offset of the first block in row 4.
    GetOffsetOfNextRow: {
        ; for now, do our calculations in blocks, not offsets
        PHA
        SEP #$20
        STA $004202
        LDA $07A5 : STA $004203
        NOP #4
        REP #$20 : PLA ; wait for multiplication
        LDA $004216
        ASL : PHA : LSR ; top of stack now contains index of first block of current row
        CLC : ADC $07A5
        ASL
        PHA ; top of stack now contains the index of the first block of next row        

        LDA #$0011 : STA $0939 ; Instructions replaced by hijack
        JMP GetOffsetOfNextRowReturn
        .freespace
    }
    !Freespace80 := GetOffsetOfNextRow_freespace
    warnpc !Freespace80End
}

; =============================================================
; ================ PATCH CODE TO CALC BG2 X/Y =================
; =============================================================
{
    ; This code was not handling negative L1 input position correctly
    ;  when BG2 X/Y scroll values are not 0% or 100%.
    
    ; We will use X as a negative flag, negate values before and after the calculation if needed.

    ; X scroll
    org $80A30A : PHX : JSR SetNegativeFlag : TYA : NOP
    org $80A31E : JSR GetHighByteOfY
    org $80A329 : JSR CheckNegativeFlag : PLX : TAY

    ; Y scroll
    org $80A34B : PHX : JSR SetNegativeFlag : TYA : NOP
    org $80A35F : JSR GetHighByteOfY
    org $80A36A : JSR CheckNegativeFlag : PLX : TAY

    org !Freespace80
    SetNegativeFlag: {
            PHP
            LDX #$0000
            CPY #$0000 : BPL .positive
            INX
            REP #$30
            PHA : TYA : EOR #$FFFF : INC : TAY : PLA
        .positive
            PLP : STA $4202 ; Instructions replaced by hijack
            RTS
    }

    GetHighByteOfY: {
        PHP : REP #$30 : TYA : XBA : PLP : RTS
    }

    CheckNegativeFlag: {
            CLC : ADC $4216 ; Instructions replaced by hijack
            DEX : BNE .positive
            EOR #$FFFF : INC
        .positive
            RTS
        .freespace
    }
    !Freespace80 := CheckNegativeFlag_freespace
    warnpc !Freespace80End
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
            LDA !RamDoorDirection : AND #$0003 : ASL : TAX
            LDA.l .defaults_mine,x : JSR .moveSamus
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
            LDA !RamDoorDirection : AND #$0003 : ASL : TAX
            LDA.l .defaults_vanilla,x
        +   TAX ; A and X contain door distance to spawn or default
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
        ..vanilla
        if !PlaceSamusAlgorithm == 1 || !PlaceSamusAlgorithm == 4
            dw $00C8 ; right
            dw $00C8 ; left
            dw $0180 ; down
            dw $0180 ; up
        endif
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

; =========================================================
; ============== DOOR TRANSITION VRAM UPDATE ==============
; =========================================================
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
            LDA !RamDoorDirection : BIT #$0002 : BEQ ++ ; If not vertical transition: return.
            LDA !RamLayer1YPosition : BMI + : AND #$00FF : + : CMP #$0090 : BPL ++
            JSR $9632 ; Door tube is low - execute VRAM update now. (Caller already checked if it's needed.)
        ++  RTS
        ..bottomOfScreen
            PHA ; need to preserve A here due to the routine we hijacked
            LDA !RamDoorDirection : BIT #$0002 : BEQ ++ ; If not vertical transition: return.
            LDA !RamLayer1YPosition : BMI + : AND #$00FF : + : CMP #$0090 : BMI ++
            ; Door tube is high - execute VRAM update now if needed.
            LDX !RamDoorVramUpdateFlag : BPL ++ : JSR $9632
        ++  PLA
            LDY #$0000 ; instruction replaced by hijack
            RTS

        .horizontal
        ..topOfScreen
            LDA !RamDoorDirection : BIT #$0002 : BNE ++ ; If vertical transition: return.
            JSR ..compareYPosition : BMI ++
            ; Door is low - move down if needed.
            LDX !RamDoorVramUpdateFlag : BPL ++ : JSR $9632
        ++  LDA !RamDoorScrollingFinishedFlag ; instruction replaced by hijack
            RTS
        ..bottomOfScreen
            ; This hijack replaces vanilla's unconditional JSR $9632 at $80:980F (IRQ command $1A).
            ; Vanilla's command $1A is the ONLY place $05BC gets cleared in the horizontal IRQ cycle.
            ; During early room loading (BEFORE the scroll wait at $82:E526), for UP doors
            ; $82:E3FB sets the interrupt command to $16 (horizontal cycle) - only DOWN doors use
            ; the vertical cycle during phase 1. $82:E49D only later switches UP doors to vertical.
            ; So during phase 1, the $82:E06B wait loops at $E446/E450/E45A/E474/E488 rely on the
            ; HORIZONTAL IRQ handlers to clear $05BC, even for UP doors.
            ; If we skip on vertical direction, $05BC never clears -> softlock at $82:E06B.
            ; Fix: match vanilla behavior (unconditional $9632) for non-horizontal directions.
            LDA !RamDoorDirection : BIT #$0002 : BNE +  ; If vertical transition: execute VRAM update unconditionally (match vanilla).
            JSR ..compareYPosition : BPL ++             ; Else (horizontal): only execute VRAM update if door is high on screen.
        +   JSR $9632 ; Execute VRAM update now. (Caller already checked that $05BC bit 15 is set.)
        ++  RTS

        ..compareYPosition
            LDA !RamLayer1YPosition : SEC : SBC !RamLayer1YDestination
            PHA : LDA !RamHDoorTopBlockYPosition : SEC : SBC $01,s : PLX : CMP #$0060
            RTS

        .freespace
    }
    !Freespace80 := CheckIfVramUpdateNeeded_freespace
    warnpc !Freespace80End

    ; Hijack vanilla ExecuteDoorTransitionVRAMUpdate to use our chunked version.
    ; All callers JSR $9632, so JSL+RTS here works - RTL returns here, then RTS returns to the caller.
    org $809632
        JSL ChunkedVramTransfer
        RTS

    ; Chunked VRAM transfer: splits large DMA transfers across multiple frames.
    ;     This is done to eliminate risk of causing a lag frame due to IRQ running too long. IRQ running too long was causing the HUD to bug out for 1 frame.
    ;     Without doing the VRAM transfers in smaller chunks, the IRQ was running too long in the rare scenario where a horizontal column of tiles was loaded due to scrolling,
    ;     a vertical column of tiles was loaded, and the VRAM transfer all took place on the same frame.
    ; Called via JSL from $9632. All callers had 16-bit A (REP #$20) active.
    ; Updates !RamDoorVramUpdateSource, !RamDoorVramUpdateDestination, !RamDoorVramUpdateSize in-place after each chunk.
    ; Only clears the !RamDoorVramUpdateFlag pending flag after the last chunk completes.
    org !FreespaceAnywhere
    ChunkedVramTransfer: {
            ; A is 16-bit on entry

            ; Guard: skip if no transfer is pending (bit 15 of flag clear).
            ; The vanilla $9632 routine had this check internally. Two of the four callers
            ; (vertical_topOfScreen, horizontal_bottomOfScreen) rely on $9632 to check the flag
            ; rather than checking it themselves, so this guard must remain here.
            LDA !RamDoorVramUpdateFlag : BPL .noTransfer

            LDA !RamDoorVramUpdateSize      ; remaining transfer size
            CMP #!VramChunkMax+1
            BCC .useRemaining               ; if remaining <= chunk max, transfer all of it
            LDA #!VramChunkMax              ; else cap at chunk max
        .useRemaining:
            PHA                             ; push this_chunk_size
    
            ; Force blank
            SEP #$20
            LDA #$80 : STA $2100
    
            ; Configure DMA channel 1
            LDX !RamDoorVramUpdateDestination : STX $2116 ; VRAM destination
            LDX #$1801 : STX $4310                        ; DMA control: 16-bit VRAM write (register $2118, mode 1)
            LDX !RamDoorVramUpdateSource : STX $4312      ; DMA source address
            LDA !RamDoorVramUpdateSourceBank : STA $4314  ; DMA source bank
            LDA #$80 : STA $2115                          ; VRAM address increment mode (increment after high byte write)
            REP #$20
            LDA $01,s : STA $4315                         ; DMA size = this_chunk_size from stack
            SEP #$20
            LDA #$02 : STA $420B                          ; Execute DMA on channel 1
    
            ; Update source, dest, remaining in-place for next chunk
            REP #$20
    
            ; source address += this_chunk_size
            LDA $01,s
            CLC : ADC !RamDoorVramUpdateSource : STA !RamDoorVramUpdateSource
    
            ; VRAM dest += this_chunk_size / 2 (VRAM addresses are in words, DMA size is in bytes)
            LDA $01,s : LSR A
            CLC : ADC !RamDoorVramUpdateDestination : STA !RamDoorVramUpdateDestination
    
            ; remaining -= this_chunk_size
            LDA !RamDoorVramUpdateSize
            SEC : SBC $01,s : STA !RamDoorVramUpdateSize
    
            PLA ; clean this_chunk_size off stack
    
            LDA !RamDoorVramUpdateSize : BNE .moreRemaining ; If remaining == 0, transfer is complete
            LDA #$8000 : TRB !RamDoorVramUpdateFlag         ; Transfer complete: clear the pending flag so Bank $82 polling loop can continue

        .moreRemaining:
            ; If more data remains, flag stays set.
            ; Next frame's IRQ will call $9632 again, which JSLs here for the next chunk.
            SEP #$20
            LDA #$0F : STA $2100            ; restore screen brightness (disable forced blank)
        .noTransfer:
            REP #$20                        ; match original routine's exit state (16-bit A)
            RTL    
            .freespace
    }
    !FreespaceAnywhere := ChunkedVramTransfer_freespace
    warnpc !FreespaceAnywhereEnd
}

if !AsyncMusicUploadEnabled > 0
; ===============================================
; ============== ASYNC SPC UPLOADS ==============
; ===============================================
{
    org $8FE7E1 : MusicPointers:

    ; ============ Hijacks ============

    ; Guard the music queue handler ($808F0C) to skip entirely when an async upload is in progress.
    ; Without this, subsequent music queue entries (track numbers) write to $2140 (IO 0),
    ; clobbering the SPC upload protocol mid-handshake.
    ; When the music queue is skipped, we will not return back here - the return address will be popped
    ; and MusicQueueGuard will return to the caller of the music queue. This is similar to a technique used by PLMs.
    org $808F0C
        PHP : NOP : JSL AsyncSpcUpload_MusicQueueGuard ; Returns N/Z flags

    ; Hijack just before call to Upload to APU (call site is $808F7E)
    ;     If in a door transition: Start async SPC upload and skip 808F7E and return
    ;     Else: Match vanilla behavior, call 808F7E which will not return until the music upload completes.
    ; Does not hijack the line of code at $808F7E because total's patch already does.
    org $808F72
        JSL AsyncSpcUpload_InitializeUpload

    ; During door transition scrolling, transfer music data to SPC while the main thread waits for scrolling to complete.
    org $82E526
        NOP : JSL AsyncSpcUpload_ScrollWaitTransfer

    ; While waiting for NMI, transfer music data to SPC.
    org $808343
        NOP : JSL AsyncSpcUpload_NmiWaitTransfer

    ; Prevent the sound handler from running via main game loop during an async SPC transfer,
    ;     as this would clobber registers to transfer data to the SPC.
    org $82896E
        JSL AsyncSpcUpload_SoundHandlerGuard

    if !EarlyMusicUpload
        ; After the state header is loaded, immediately initialize SPC upload instead of
        ;     the later part of the process where it happens in vanilla.
        ; This causes the vanilla call at $82E4AD to effectively become a no-op.
        org $82E37F
            JSL AsyncSpcUpload_EarlyStartHook
    endif

    if !WaitForMusicUploadBeforeFadeIn
        ; The vanilla check for this at $82E664 no longer works because our code immediately clears the music queue entry.

        ; Fix: replace $82:E664's body in place, inserting an additional check on !RamAsyncSpcState.
        ; Original body is 17 bytes ($E664..$E674 inclusive). The replacement is slightly longer, so
        ; we extend into the space currently occupied by the unused door transition function at
        ; $82:E675 (which is 45 bytes of dead code - verified unused per PJBoy's notes).
        org $82E664
            JSL $808EF4 : BCS +                     ; if music is queued: return
            LDA !RamAsyncSpcState : BNE +           ; if async upload state is active: return (aka wait next frame)
            LDA #$E6A2 : STA !RamDoorTransitionFunctionPointer
            JSL $82E0D5                             ; load new music track if changed
        +   RTS
        warnpc $82E6A2
    endif

    ; ============ Async SPC Music Upload ============
    ; Replaces the vanilla blocking SPC upload ($80:8024) with a multi-frame state machine.
    ; Instead of uploading all music data inside a single call (5-20 frames of blocking),
    ; this breaks the upload into small chunks transfered during idle busy-wait loops.
    ;
    ; Uses total's fast $FE SPC upload protocol (total SPC transfer optimisation.asm):
    ;   CPU sends $FE to IO 0 -> SPC responds with $11AA on IO 2-3.
    ;   Block headers: CPU sends dest addr to IO 0-1, $00BB to IO 2-3.
    ;   SPC acknowledges block with $11CC on IO 2-3.
    ;   Data transferred 2 bytes at a time: data on IO 0-1, counter on IO 2.
    ;   End-of-block: (counter-1) | $0100 sent to IO 2-3 (bit 0 of IO 3 = end flag).
    ;   EOF: dest=$0000, $00BB to IO 2-3, wait for $11CC.
    ;
    ; total's SPC-side fast upload handler is at ARAM $56E2.
    ; It also has a command hook at ARAM $17A1 that routes $FF to vanilla, $FE to fast.
    ; SPC has NO timeout between bytes - it waits indefinitely, so multi-frame is safe.
    ;
    ; RAM used (all in bank $7F, accessed via absolute long):
    ;   !RamAsyncSpcState     = state number (0=idle, else active state × 2)
    ;   !RamAsyncSpcDataY     = source pointer Y (into current bank)
    ;   !RamAsyncSpcDataBank  = source bank (low byte used)
    ;   !RamAsyncSpcBlockSize = remaining bytes in current block
    ;   !RamAsyncSpcIndex     = handshake counter (low byte used)
    ;
    ; State numbers (×2 for jump table indexing):
    ;   0  = idle
    ;   2  = Init (send $FE, wait for $11AA)
    ;   4  = NextBlock (wait $11AA, read header, send dest + $00BB)
    ;   6  = BlockWait (wait for $11CC)
    ;   8  = Transfer (transfer 2-byte pairs, up to 64 bytes per call)
    ;   10 = EofWait (wait for $11CC after EOF)
    ;   12 = Complete (clear flags, go idle)
    ;   14 = StopWait

    !AsyncSpcBytesPerTransfer = $0040               ; 64 bytes per transfer call

    !AsyncSpcStateIdle      = $0000
    !AsyncSpcStateInit      = $0002
    !AsyncSpcStateNextBlock = $0004
    !AsyncSpcStateBlockWait = $0006
    !AsyncSpcStateTransfer  = $0008
    !AsyncSpcStateEofWait   = $000A
    !AsyncSpcStateComplete  = $000C
    !AsyncSpcStateStopWait  = $000E             ; EarlyStart only: wait N frames after "stop music" ($00) before sending $FE

    org !FreespaceAnywhere
    AsyncSpcUpload: {

        .InitializeUpload:
            ; X = music data index
            LDA.l MusicPointers,x ; Instruction replaced by hijack
            PHA

            ; Check if we should use async upload (door transition, game state $09-$0B)
            LDA !RamGameState
            CMP #$0009 : BCC ..VanillaApuUpload            ; < $09: not door transition
            CMP #$000C : BCS ..VanillaApuUpload            ; >= $0C: not door transition
            LDA !RamAsyncSpcState : BNE ..VanillaApuUpload ; already active - let blocking handle it
            PLA                                            ; restore A (source pointer low bytes)

            ; --- Door transition: start async upload ---

            STA $00                 ;\
            LDA.l MusicPointers+1,x ;) $00 = [MusicDataPointers + [music data index]]
            STA $01                 ;/

            ; Start async state machine
            PHP
            REP #$30
            LDA $00    : STA !RamAsyncSpcDataY      ; save source pointer Y
            LDA #$FFFF : STA !RamUploadingToApuFlag ; Set uploading flag (prevents music queue handler and sound handler from touching APU ports)
            SEP #$20
            LDA $02  : STA !RamAsyncSpcDataBank     ; save source bank
            LDA #$FE : STA $002140                  ; Send $FE to APU IO 0 to request fast upload mode (total's protocol)
            LDA #$81 : STA $01,s                    ; Skip call to vanilla APU upload by updating stack retrun address; return to $808F82
            REP #$20
            LDA #!AsyncSpcStateInit : STA !RamAsyncSpcState ; Set initial state: wait for SPC to respond with $11AA on IO 2-3. NMI checks this, so do this last.
            PLP            
            RTL

        ..VanillaApuUpload:
            PLA : RTL ; Not a door transition (or async already active).

        .EarlyStartHook:
            JSL $8882C1                             ; instruction replaced by hijack

        ; ---- Early start: kick off async upload the instant !RamRoomMusicDataIndex is known from new room header ----
        ; With this hook, we bypass the music queue entirely and start our async state machine
        ; directly from the MusicPointers pointer table. We also update !RamMusicDataIndex = !RamRoomMusicDataIndex so the later
        ; $82:E071 call at $E4AD becomes a no-op (its CMP !RamMusicDataIndex : BEQ return check fires).
        ;
        ; Music-stop sequencing: we do NOT send $FE immediately. Vanilla's music queue path imposes
        ; an 8-frame delay between "stop music" ($00) and "upload data" because each $808FC1 call
        ; primes an 8-frame queue timer. The gap gives the SPC music engine time to read $00 from
        ; IO 0, process it through dispatch, and key-off any sustaining DSP voices before we start
        ; overwriting ARAM. Without this gap, the DSP keeps playing the last-loaded samples until
        ; we clobber them mid-note, producing stuck notes and sample-swap glitches.
        ;
        ; We match vanilla timing: write $00 to IO 0 here, capture !RamNmiCounter + !MusicStopWaitFrames as
        ; the target frame, and transition to .StateStopWait. StateStopWait polls !RamNmiCounter from the
        ; transfer loop and, once the target is reached, writes $FE and transitions to .StateInit.
        ;
        ; Preconditions on entry:
        ;   - Called via JSL from the $82:E37F hijack wrapper (DB = $82 from JMP ($099C))
        ;   - P state is whatever $82:E36E was in - we PHP/PLP to restore
        ; Postconditions:
        ;   - If !RamRoomMusicDataIndex == 0 or !RamRoomMusicDataIndex == !RamMusicDataIndex (no music change): no-op
        ;   - If already uploading (!RamAsyncSpcState != 0): no-op
        ;   - Otherwise: "stop music" queued to SPC, !RamUploadingToApuFlag set, !RamMusicDataIndex updated, state = StopWait
            PHP : PHB : REP #$30 : PHX

            LDA !RamAsyncSpcState : BNE ..Return ; Skip if async upload already in progress

            ; Load new room's music data index (!RamRoomMusicDataIndex is already set from room header).
            LDA !RamRoomMusicDataIndex : BEQ ..Return ; if index = 0: no music -> skip
            CMP !RamMusicDataIndex : BEQ ..Return     ; if same as current music data: no change -> skip

            ; New room's music differs. Start async upload immediately.
            ; Update !RamMusicDataIndex so the later $82:E071 at $E4AD sees "no change" and becomes a no-op.
            STA !RamMusicDataIndex

            ; Fetch source pointer from the music data pointer table MusicPointers
            TAX                                                ; X = music data index (byte offset)
            PHB
            PEA $8F8F : PLB : PLB                              ; DB = $8F
            LDA.w MusicPointers,x   : STA !RamAsyncSpcDataY    ; 16-bit: low 2 bytes of 3-byte pointer = offset
            SEP #$20
            LDA.w MusicPointers+2,x : STA !RamAsyncSpcDataBank ; 8-bit: 3rd byte of pointer = bank
            LDA #$FF : STA !RamMusicCurrentTrack               ; current music track = $FF (match $80:8F6D)

            REP #$20
            STZ !RamMusicTrackIndex

            ; Send "stop music" ($00) to IO 0 and arm the StopWait countdown.
            ; The SPC music engine's dispatch loop will see $00 on IO 0, interpret it as a music
            ; track index of 0, and kill the current song. We then wait !MusicStopWaitFrames frames
            ; (matching vanilla's $808FC1 8-frame delay) before sending $FE to request fast upload mode.
            SEP #$20
            LDA #$00 : STA $002140                  ; IO 0 = $00 (stop music command)
            REP #$20
            LDA !RamNmiCounter
            CLC : ADC.w #!MusicStopWaitFrames       ; target = now + wait (16-bit wrap OK, compared signed in StateStopWait).
            STA !RamAsyncSpcStopWaitTarget          ; save target

            ; Set uploading flag (guards sound handler / music queue handler from APU port writes).
            ; Must be set BEFORE returning so that the sound handler, which runs later in the same
            ; frame at $82:896E, skips itself and doesn't stomp our $00 write to IO 0.
            LDA #$FFFF : STA !RamUploadingToApuFlag
            LDA #!AsyncSpcStateStopWait : STA !RamAsyncSpcState
            PLB

        ..Return:
            PLX
            PLB
            PLP
            RTL

        .ScrollWaitTransfer:
            PHP : REP #$20
        ..Loop:
            JSR .Dispatch
            REP #$20
            LDA !RamDoorScrollingFinishedFlag : BPL ..Loop ; negative = done scrolling, stop transferring.
            PLP : RTL

        .NmiWaitTransfer:
            PHP
        ..Loop:
            REP #$20
            JSR .Dispatch
            SEP #$20
            LDA !RamNmiRequestFlag : BNE ..Loop
            PLP : RTL

        ; ---- Dispatch: call current state handler if active ----
        ; Called via JSR with 16-bit A. X/Y size may vary (8-bit from NMI-wait, 16-bit from scroll-wait).
        ; We force 16-bit X/Y before push/pull to ensure stack balance regardless of caller state.
        .Dispatch:
            LDA !RamAsyncSpcState : BEQ ..Idle

            ; Check gamestate. Similar to InitializeUpload's game state check.
            LDA !RamGameState
            CMP #$0007 : BCC ..Idle          ; < $07: title/intro states - skip
            CMP #$000C : BCC ..Ok            ; $07-$0B: gameplay + door transition - proceed
        ..Idle:                              ; >= $0C: pause, death, ending, etc. - skip
            RTS

        ..Ok:
            LDA !RamAsyncSpcState : CMP #!AsyncSpcStateStopWait+2 : BCS ..Corrupt ; Sanity check: if state > max valid entry, handle it with ..Corrupt

            REP #$30                                ; force 16-bit A AND X/Y before push (critical for stack balance)
            PHX : PHY : PHB
            PHK : PLB                               ; DB = code bank (for jump table)
            TAX                                     ; X = state number (16-bit, pre-multiplied by 2)
            JSR (.JumpTable,x)
            REP #$10                                ; ensure 16-bit X/Y for pull (state handlers may have changed it)
            PLB : PLY : PLX
            RTS

        ..Corrupt:
            ; State is outside valid range. Force everything back to idle. This should never happen.
            LDA #$0000
            STA !RamAsyncSpcState                   ; state = idle
            STA !RamUploadingToApuFlag              ; clear upload flag (unblock music queue + sound handler)
            RTS

        .JumpTable:
            dw $0000                                ; 0 = idle (should never be reached)
            dw .StateInit                           ; 2 = Init
            dw .StateNextBlock                      ; 4 = NextBlock
            dw .StateBlockWait                      ; 6 = BlockWait
            dw .StateTransfer                       ; 8 = Transfer
            dw .StateEofWait                        ; 10 = EofWait
            dw .StateComplete                       ; 12 = Complete
            dw .StateStopWait                       ; 14 = StopWait (EarlyStart only)

        ; ---- State: StopWait (EarlyStart only) ----
        ; Entered from .EarlyStart after writing $00 (stop music) to IO 0 and arming
        ; !RamAsyncSpcStopWaitTarget = (!RamNmiCounter at entry) + !MusicStopWaitFrames.
        ;
        ; Purpose: give the SPC music engine time to (a) read $00 from IO 0 via its dispatch
        ; loop, (b) key-off the sustaining DSP voices, and (c) let envelopes decay before we
        ; clobber ARAM with fast upload data. Vanilla achieves the same effect via two back-to-
        ; back $808FC1 calls, each priming an 8-frame music queue timer.
        ;
        ; Frame counter: !RamNmiCounter is the 16-bit NMI counter (incremented every NMI in BRANCH_RETURN
        ; at $80:95F9, including via the BRANCH_LAG fall-through). We deliberately do NOT use
        ; $05B5 - during door transitions an erroneous 16-bit write to !RamNmiRequestFlag clobbers $05B5 to 0
        ; every frame, so a wait against $05B5 can never be satisfied. !RamNmiCounter is the only frame-
        ; like counter that advances reliably across door transitions. The state machine transfer is
        ; called many times per frame from .ScrollWaitTransfer / .NmiWaitTransfer loops, so we just poll
        ; !RamNmiCounter each dispatch.
        ;
        ; Comparison: signed 16-bit (current - target). If bit 15 is clear, we've reached or
        ; passed the target. This tolerates 16-bit wraparound as long as the wait is < 32768
        ; frames (!MusicStopWaitFrames range $0001..$7FFF; default $0008).
        ;
        ; On completion: write $FE to IO 0 (fast upload request) and transition to .StateInit,
        ; which polls $11AA on IO 2-3 for the SPC's fast-upload acknowledgment.
        .StateStopWait:
            REP #$20
            LDA !RamNmiCounter                      ; current 16-bit NMI counter
            SEC : SBC !RamAsyncSpcStopWaitTarget    ; A = current - target (16-bit signed)
            BMI .SwWaiting                          ; if current < target (bit 15 set): still waiting

            ; Wait satisfied. Kick off the fast upload.
            SEP #$20
            LDA #$FE : STA $002140                  ; IO 0 = $FE (request total's fast upload mode)
            REP #$20
            LDA #!AsyncSpcStateInit : STA !RamAsyncSpcState
            RTS
        .SwWaiting:
            RTS

        ; ---- State: Init ----
        ; Wait for SPC to respond with $11AA on IO 2-3.
        ; We already sent $FE to IO 0 (from .Start directly, or from .StateStopWait after the
        ; stop-wait countdown). The SPC music engine periodically checks IO 0 for commands;
        ; when it sees $FE, total's command hook routes to the fast upload handler at ARAM
        ; $56E2, which writes $11 to $F7 and $AA to $F6 (= $11AA on IO 2-3).
        .StateInit:
            REP #$20
            LDA $2142 : CMP #$11AA : BNE .InitNotReady

            ; SPC is ready. Transition to NextBlock.
            LDA #!AsyncSpcStateNextBlock : STA !RamAsyncSpcState
        .InitNotReady:
            RTS

        ; ---- State: NextBlock ----
        ; Wait for $11AA on IO 2-3, then read block header and send to SPC.
        ; Block header format in source data: 2-byte size + 2-byte dest address.
        ; If size=0, this is the EOF marker - upload is finishing.
        ;
        ; Protocol (total's $FE):
        ;   CPU sends dest addr to IO 0-1.
        ;   CPU sends $00BB to IO 2-3 (tells SPC "address sent").
        ;   SPC reads dest from $F4-$F5, writes $CC to $F6 (CPU sees $xxCC on IO 2-3).
        ;   For EOF: CPU sends $0000 to IO 0-1 and $00BB to IO 2-3.
        .StateNextBlock:
            ; Wait for $11AA (SPC ready for a new block header).
            ; First block: Init already confirmed $11AA, this re-check is instant.
            ; Subsequent blocks: SPC re-enters fastspc after end-of-block, sets $11AA quickly.
            REP #$20
            LDA $2142 : CMP #$11AA : BNE .NbNotReady

            SEP #$20
            PHB
            LDA !RamAsyncSpcDataBank : PHA : PLB    ; DB = source bank
            REP #$30                                ; 16-bit A AND X/Y
            LDA !RamAsyncSpcDataY : TAY             ; Y = source offset (16-bit)

            ; Read block size (2 bytes)
            LDA $0000,y
            STA !RamAsyncSpcBlockSize
            ; Advance Y past size field
            INY : BNE +
            JSR .IncBank
        +   INY : BNE +
            JSR .IncBank
        +

            ; Check for EOF (size == 0)
            LDA !RamAsyncSpcBlockSize : BEQ .NbEof

            ; Read destination address (2 bytes)
            LDA $0000,y
            STA $002140                             ; IO 0-1 = dest address (long addr: DB is source bank, not $00)
            ; Advance Y past dest field
            INY : BNE +
            JSR .IncBank
        +   INY : BNE +
            JSR .IncBank
        +

            ; Save source pointer (now past the 4-byte header, pointing at data start)
            TYA : STA !RamAsyncSpcDataY

            ; Tell SPC: "address sent" ($00BB to IO 2-3)
            LDA #$00BB : STA $002142                ; long addr: DB is source bank

            ; Reset handshake counter for transfer
            SEP #$20
            LDA #$00 : STA !RamAsyncSpcIndex

            ; Transition to BlockWait
            REP #$20
            LDA #!AsyncSpcStateBlockWait : STA !RamAsyncSpcState

            PLB
            RTS

        .NbEof:
            ; EOF block: size == 0. Source pointer is past the 2-byte size (no dest to read).
            TYA : STA !RamAsyncSpcDataY

            ; Send dest=$0000 to IO 0-1 (signals EOF to SPC)
            LDA #$0000 : STA $002140                ; long addr: DB is source bank
            ; Tell SPC: "address sent"
            LDA #$00BB : STA $002142                ; long addr: DB is source bank

            ; Transition to EofWait (wait for SPC to acknowledge with $11CC)
            LDA #!AsyncSpcStateEofWait : STA !RamAsyncSpcState

            PLB
            RTS

        .NbNotReady:
            RTS

        ; ---- State: BlockWait ----
        ; Wait for SPC to acknowledge block header with $11CC on IO 2-3.
        ; SPC reads dest from $F4-$F5, writes $CC to $F6. CPU sees $xxCC on IO 2-3.
        ; After this, SPC enters .transfer and waits for the first data counter on $F6.
        .StateBlockWait:
            REP #$20
            LDA $2142 : CMP #$11CC : BNE .BwWaiting

            ; SPC acknowledged. Transition to Transfer.
            LDA #!AsyncSpcStateTransfer : STA !RamAsyncSpcState
        .BwWaiting:
            RTS

        ; ---- State: Transfer ----
        ; Transfer up to !AsyncSpcBytesPerTransfer bytes per call using total's 2-byte pair protocol.
        ;
        ; Protocol per pair:
        ;   - Send 2 data bytes to IO 0-1 (16-bit write)
        ;   - Send counter to IO 2 (IO 3 stays 0 during transfer; SPC checks IO 3 bit 0 for end)
        ;   - Wait for SPC echo of counter at IO 2 (SPC writes Y to $F6 after processing)
        ;
        ; Counter sequence: 0 (first pair), then 1, 3, 5, 7, ... (increment by 2 after each pair)
        ; The first pair after $11CC also waits for $11CC to confirm SPC is ready.
        ;
        ; End-of-block: instead of sending next counter, send (counter-1) to IO 2 and $01 to IO 3.
        ; SPC sees bit 0 of $F7 ($2143) set -> exits transfer, re-enters fastspc for next block.
        ;
        ; Register usage during transfer loop:
        ;   A (8-bit) = handshake counter (next value to send)
        ;   X (16-bit) = bytes remaining in transfer budget (counts down by 2)
        ;   Y (16-bit) = source data pointer (into current bank via DB)
        ;
        ; NOTE: DP $00 is NOT used - NMI can fire mid-loop and clobber DP scratch.
        .StateTransfer:
            SEP #$20
            PHB
            LDA !RamAsyncSpcDataBank : PHA : PLB    ; DB = source bank
            REP #$30                                ; 16-bit A AND X/Y
            LDA !RamAsyncSpcDataY : TAY             ; Y = source (16-bit)

            SEP #$20
            LDA !RamAsyncSpcIndex                   ; A = counter (8-bit)
            REP #$10                                ; ensure 16-bit X/Y
            LDX #!AsyncSpcBytesPerTransfer              ; X = transfer budget in bytes

            CMP #$00 : BNE .TxTransferLoop             ; counter > 0 -> mid-block, resume transfering

            ; --- First pair of block ---
            ; Wait for $11CC (SPC ready for data after acknowledging block header).
            ; BlockWait already confirmed $11CC, so this should match instantly.
            REP #$20
        .TxWaitReady:
            LDA $002142 : CMP #$11CC : BNE .TxWaitReady  ; long addr: DB is source bank

            ; Load and send first 2 data bytes
            LDA $0000,y : STA $002140               ; IO 0-1 = first 2 bytes of block data (long addr)
            ; Send counter=0 to IO 2-3
            LDA #$0000 : STA $002142                ; long addr (no STZ long opcode exists)
            SEP #$20
            LDA #$01                                ; counter becomes 1 (next to send)
            ; Y is NOT advanced here - .TxTransferLoop does INY INY at the start
            ; to advance past the previous pair before loading the next one
            DEX : DEX                               ; budget -= 2
            BEQ .TxChunkDone
            ; Fall through to transfer subsequent pairs

        .TxTransferLoop:
            ; A = counter (8-bit), X = budget (16-bit), Y = source (16-bit)
            ; Advance Y past previous pair's data
            INY : BNE +
            JSR .IncBank
        +   INY : BNE +
            JSR .IncBank
        +

            ; Decrement block size by 2
            PHA                                     ; save counter (8-bit -> 1 byte on stack)
            REP #$20
            LDA !RamAsyncSpcBlockSize
            SEC : SBC #$0002
            STA !RamAsyncSpcBlockSize
            BEQ .TxEndBlock                         ; size == 0 -> even block end
            CMP #$FFFF : BEQ .TxEndBlockOdd         ; size == -1 -> odd block end
            SEP #$20
            PLA                                     ; restore counter

            ; Wait for SPC echo of counter at IO 2
            ; (SPC writes Y to $F6 after processing each pair; CPU reads $F6 from IO 2)
            ; IO 3 ($F7) stays $00 during transfer (set by SPC's mov $f7, #$00 at .transfer entry)
        .TxWaitEcho:
            CMP $002142 : BNE .TxWaitEcho           ; long addr: DB is source bank

            ; Send next 2 data bytes
            PHA                                     ; save counter (need 16-bit A for data load)
            REP #$20
            LDA $0000,y : STA $002140               ; IO 0-1 = data pair (long addr)
            SEP #$20
            PLA                                     ; restore counter
            STA $002142                             ; IO 2 = counter (long addr; IO 3 stays 0 from first pair)

            ; Advance counter by 2 (wraps at 256 via 8-bit arithmetic)
            CLC : ADC #$02

            DEX : DEX                               ; budget -= 2
            BNE .TxTransferLoop
            ; Fall through when budget exhausted

        .TxChunkDone:
            ; Save state for next transfer call
            STA !RamAsyncSpcIndex                   ; save counter
            REP #$20
            TYA : STA !RamAsyncSpcDataY             ; save source pointer
            SEP #$20
            PHB : PLA : STA !RamAsyncSpcDataBank    ; save bank (may have changed via .IncBank)
            PLB                                     ; restore original DB
            RTS

        .TxEndBlock:                                ; A is 16-bit here, counter is on stack (8-bit push)
            SEP #$20
            PLA                                     ; restore counter
            BRA .TxSendEnd

        .TxEndBlockOdd:                             ; A is 16-bit here, counter is on stack
            SEP #$20
            PLA                                     ; restore counter
            DEY                                     ; back up source by 1 byte (odd block had 1 extra advance)
            ; Fall through to send end signal

        .TxSendEnd:
            ; A = counter (8-bit). Block is finished.
            ; Wait for SPC echo of current counter (SPC processed last pair we sent)
        .TxWaitFinalEcho:
            CMP $002142 : BNE .TxWaitFinalEcho      ; long addr: DB is source bank

            ; Send end-of-block signal:
            ; IO 2 = counter - 1 (doesn't match any Y the SPC expects, so SPC falls to bbc0 check)
            ; IO 3 = $01 (bit 0 set = end flag; SPC's bbc0 $f7 test sees it and exits transfer)
            DEC A : STA $002142                     ; IO 2 = counter - 1 (long addr)
            LDA #$01 : STA $002143                  ; IO 3 = end flag (long addr)

            ; Save source pointer and bank
            REP #$20
            TYA : STA !RamAsyncSpcDataY
            SEP #$20
            PHB : PLA : STA !RamAsyncSpcDataBank

            ; Reset counter for next block
            LDA #$00 : STA !RamAsyncSpcIndex

            ; Transition to NextBlock to read next block header
            REP #$20
            LDA #!AsyncSpcStateNextBlock : STA !RamAsyncSpcState
            PLB
            RTS

        ; ---- State: EofWait ----
        ; After sending EOF marker (dest=$0000 + $00BB), wait for SPC to acknowledge with $11CC.
        ; SPC sees dest=$0000, writes $CC to $F6, then clears ports and returns to music engine.
        .StateEofWait:
            REP #$20
            LDA $2142 : CMP #$11CC : BNE .EwNotReady

            ; SPC acknowledged EOF. Transition to Complete.
            LDA #!AsyncSpcStateComplete : STA !RamAsyncSpcState
            JMP .StateComplete                      ; execute immediately
        .EwNotReady:
            RTS

        ; ---- State: Complete ----
        ; Upload finished. Clear flags, set state to idle.
        .StateComplete:
            REP #$20
            LDA #$0000
            STA !RamUploadingToApuFlag
            STA !RamAsyncSpcState                   ; state = idle (0)
            RTS

        ; ---- Helper: Increment source bank (Y wrapped to $8000) ----
        ; Same as vanilla $80:8107 and practice hack's cm_spc_inc_bank.
        ; Called when Y overflows past $FFFF. Sets Y=$8000, increments bank.
        ; IMPORTANT: Called from both 8-bit and 16-bit A contexts (.StateNextBlock uses 16-bit,
        ; .StateTransfer uses 8-bit). We must use 8-bit internally for the PHA/PLB/PLA sequence
        ; because PLB always pulls exactly 1 byte regardless of the M flag.
        .IncBank:
            PHP                                     ; save processor state (including M flag)
            SEP #$20                                ; force 8-bit A
            PHA
            LDA !RamAsyncSpcDataBank : INC : STA !RamAsyncSpcDataBank
            PHA : PLB                               ; DB = new bank (1-byte push, 1-byte pull - balanced)
            PLA
            PLP                                     ; restore original processor state
            LDY #$8000
            RTS

        ; When !RamUploadingToApuFlag != 0 (async upload active), skip the sound handler entirely.
        ; When !RamUploadingToApuFlag == 0, call the original sound handler normally.
        .SoundHandlerGuard:
            PHP : REP #$20
            LDA !RamUploadingToApuFlag : BNE ..SkipSoundHandler
            PLP
            JSL $8289EF                             ; call sound handler
            RTL
        ..SkipSoundHandler:
            PLP
            RTL                                     ; skip sound handler - return to $82:8972

        ; If !RamUploadingToApuFlag != 0 (async upload active), skip the music queue handler.
        ; If !RamUploadingToApuFlag == 0, execute the overwritten instructions and return to $8F12.
        .MusicQueueGuard:
            REP #$20                                ; code replaced by hijack
            LDA !RamUploadingToApuFlag : BNE ..SkipMusicQueue
            DEC !RamMusicTimer                      ; code replaced by hijack
            RTL                                     ; return N/Z flags

        ..SkipMusicQueue:
            ; Upload in progress - skip the ENTIRE music queue handler.
            ; Stack right now (top to bottom):
            ;   [3 bytes] return addr -> $808F11 (from JSL at $808F0D)
            ;   [1 byte]  P from the vanilla PHP at $808F0C (the caller's original P)
            ;   [3 bytes] return addr -> caller of $808F0C (outer return addr)
            ;
            ; To skip cleanly: discard the inner return addr, restore the vanilla P (so the
            ; caller sees its original P state - critical: M must match what the caller had,
            ; otherwise the caller's subsequent instructions decode with the wrong width),
            ; then RTL to return to the outer caller.
            SEP #$20                                ; force 8-bit A so PLA pulls 1 byte each
            PLA : PLA : PLA                         ; discard 3-byte inner return addr (-> $808F11)
            PLP                                     ; restore caller's P state from vanilla PHP
            RTL                                     ; return to outer caller (any caller, not just $80:A13A)
        .freespace
    }
    !FreespaceAnywhere := AsyncSpcUpload_freespace
    warnpc !FreespaceAnywhereEnd
}
endif

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
