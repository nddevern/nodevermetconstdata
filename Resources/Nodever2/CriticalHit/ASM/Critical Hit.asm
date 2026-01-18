lorom

; Critical Hit
; Original patch by DSO and JAM Dec 2017
; Labeled, commented, and edited by Nodever2 Jan 2026
;  * Samus and enemies receive double damage on crit
;  * When Samus receives a crit, she flashes a different color
;  * Able to customize odds of crits
;  * Item 1: prevent crits
;  * Item 2: allow crits on enemies
;  * If double crits are enabled, quadruple the normal damage is taken upon double crit.

; Terminology: The terminology I use here is describing WHO the crit is happening TO,
;   not who is DOING the crit.
;   For example, a Samus Crit is a critical hit happening TO samus, so she is taking extra damage.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !SamusDoubleCritsEnabled         = 1 ; Set to 1 to enable Samus double-crits. Uses slightly more freespace.
    !EnemyDoubleCritsEnabled         = 1 ; Set to 1 to enable enemy double-crits. Uses slightly more freespace.

    !SamusCritChance                 = #$5000 ;\
    !SamusDoubleCritChance           = #$6800 ;) Higher number = lower chance. I know. Sorry.
    !EnemyCritChance                 = #$6800 ;|    Min value = 0001, max value = 7FFF.
    !EnemyDoubleCritChance           = #$7800 ;/    Also, if enabled, double-crit odds partially overlap normal crit odds.

    !CritPaletteROMLocation          = $CC00 ; In $9B. 20h bytes.
    !DoubleCritPaletteROMLocation    = $CC20 ; In $9B. 20h bytes. Only written if Samus double-crits are enabled.
    !CritPaletteFileLocation         = "./criticalHitData/critPalette.bin" ; File location on your computer.
    !DoubleCritPaletteFileLocation   = "./criticalHitData/doubleCritPalette.bin"

    !CritImmunityItemBit             = $0010 ;) Item bits (set in $09A2, $09A4). In vanilla, unused ones are:
    !EnemyCritItemBit                = $0040 ;/    $0010, $0040, $0080, $0400, $0800.

    !CritImmunityItemMessageBox      = $13
    !EnemyCritItemMessageBox         = $13

    !CritImmunityItemGfxROMLocation  = $AEFD ; In $89. 100h bytes. To change palette - edit PLM instruction list.
    !CritImmunityItemGfxFileLocation = "./criticalHitData/critImmunityItemGfx.bin"
    !EnemyCritItemGfxROMLocation     = $AFFD ; In $89. 100h bytes. To change palette - edit PLM instruction list.
    !EnemyCritItemGfxFileLocation    = "./criticalHitData/enemyCritItemGfx.bin"

    !IncludeCritImmunityNormalPlm    = 1 ; Set to 0 to save ROM space.
    !IncludeCritImmunityChozoPlm     = 1 ; Set to 0 to save ROM space.
    !IncludeEnemyCritNormalPlm       = 1 ; Set to 0 to save ROM space.
    !IncludeEnemyCritChozoPlm        = 1 ; Set to 0 to save ROM space.

    !FreespaceAnywhere               = $80FF50 ; Any bank $80-$BF, but do not cross bank boundaries.
    !FreespaceAnywhereEnd            = $80FFC0
    !Freespace84                     = $84EFD3
    !Freespace84End                  = $84FFFF
    !Freespace91                     = $91FFEE
    !Freespace91End                  = $91FFFF
    !Freespace93                     = $93F620
    !Freespace93End                  = $93FFFF
    !FreespaceA0                     = $A0F900
    !FreespaceA0End                  = $A0FFFF
    !ReportFreespaceUsage            = 1  ; Set to 0 to stop this patch from printing it's freespace usage to the console when assembled.


    ; new variables - can repoint the ram that these use
    !RamSamusCritFlag = $7ED8EE ; Whether or not a crit happened to Samus.
    ;{
    ;    0: No crit
    ;    1: Crit
    ;    2: Double crit
    ;}

    ; Vanilla variables - don't touch
    !RamRandomNumber       = $05E5
    !RamSamusEquippedItems = $09A2
    !RamEnemyIndex         = $0E54
    !RamProjectileDamages  = $0C2C

    ; Don't touch. These constants are for the freespace usage report.
    !FreespaceAnywhereReportStart := !FreespaceAnywhere
    !Freespace84ReportStart := !Freespace84
    !Freespace91ReportStart := !Freespace91
    !Freespace93ReportStart := !Freespace93
    !FreespaceA0ReportStart := !FreespaceA0
}

; =================================================
; =============== SAMUS CRIT LOGIC ================
; =================================================
{
    org $91DF61 ; Hijack routine - Deal [A] damage to Samus
        JSL HandleSamusCritDamage : NOP ; Hijack point overwrites useless code.

    org !FreespaceAnywhere
    HandleSamusCritDamage: {
            LDA #$0000 : STA !RamSamusCritFlag
            LDA !RamSamusEquippedItems : AND #!CritImmunityItemBit : BNE .return
            LDA !RamRandomNumber
            LSR
            if !SamusDoubleCritsEnabled > 0
                CMP !SamusDoubleCritChance : BPL .doubleCrit
            endif
            CMP !SamusCritChance : BPL .crit
        .return
            RTL
        .doubleCrit
            if !SamusDoubleCritsEnabled > 0
                ASL $12 ; Double incoming damage
                LDA !RamSamusCritFlag : INC : STA !RamSamusCritFlag
            endif
        .crit
            ASL $12 ; Double incoming damage
            LDA !RamSamusCritFlag : INC : STA !RamSamusCritFlag
            RTL
        .freespace
        !FreespaceAnywhere := HandleSamusCritDamage_freespace
        warnpc !FreespaceAnywhereEnd
    }

    ; Samus palette = 20h bytes from $9B:[X]
    ; Parameters:
    ;     X: Pointer to Samus palette
    org $91DD5B
        SetSamusPalette:

    org $91D8E3 ; Hijack routine - Handle misc. Samus palette
        JSR GetSamusCritPalettePointerShort
        JSR SetSamusPalette

    org !Freespace91
    GetSamusCritPalettePointerShort: {
            PHA
            JSL GetSamusCritPalettePointer
            PLA : RTS
        .freespace
        !Freespace91 := GetSamusCritPalettePointerShort_freespace
        warnpc !Freespace91End
    }

    org !FreespaceAnywhere
    GetSamusCritPalettePointer: {
            LDA !RamSamusCritFlag
            if !SamusDoubleCritsEnabled > 0
                CMP #$0002 : BEQ .doubleCrit
            endif
            CMP #$0001 : BEQ .crit
            LDX #$A380 ; Instruction replaced by hijack
            RTL
        .doubleCrit
            if !SamusDoubleCritsEnabled > 0
                LDX #!DoubleCritPaletteROMLocation
                RTL
            endif
        .crit
            LDX #!CritPaletteROMLocation
            RTL
        .freespace
        !FreespaceAnywhere := GetSamusCritPalettePointer_freespace
        warnpc !FreespaceAnywhereEnd
    }

    org $9B0000+!CritPaletteROMLocation
        incbin !CritPaletteFileLocation
    org $9B0000+!DoubleCritPaletteROMLocation
        if !SamusDoubleCritsEnabled > 0
            incbin !DoubleCritPaletteFileLocation
        endif
}

; =================================================
; =============== ENEMY CRIT LOGIC ================
; =================================================
{
    org $93803F ; Hijack routine - Initialize projectile
        JSR HandleEnemyCritDamage
        BRA $04

    org !Freespace93
    HandleEnemyCritDamage: {
            STA !RamProjectileDamages,X ; Instruction replaced by hijack - set projectile damage
            LDA !RamSamusEquippedItems : AND #!EnemyCritItemBit : BEQ .return
            LDA !RamRandomNumber
            LSR
            if !EnemyDoubleCritsEnabled > 0
                CMP !EnemyDoubleCritChance : BPL .doubleCrit
            endif
            CMP !EnemyCritChance : BPL .crit
        .return
            RTS
        .doubleCrit
            if !EnemyDoubleCritsEnabled > 0
                ASL !RamProjectileDamages,X ; Double projectile damage
            endif
        .crit
            ASL !RamProjectileDamages,X ; Double projectile damage
            RTS
        .freespace
        !Freespace93 := HandleEnemyCritDamage_freespace
        warnpc !Freespace93End
    }

    org $A0A4E2 ; Hijack routine - Normal enemy touch AI - no death check
        JSR HandleEnemyCritContactDamage

    org !FreespaceA0
    HandleEnemyCritContactDamage: {
            LDA !RamSamusEquippedItems : AND #!EnemyCritItemBit : BEQ .return
            LDA !RamRandomNumber
            LSR
            if !EnemyDoubleCritsEnabled > 0
                CMP !EnemyDoubleCritChance : BPL .doubleCrit
            endif
            CMP !EnemyCritChance : BPL .crit
            BRA .return
        .doubleCrit
            if !EnemyDoubleCritsEnabled > 0
                ASL $16
            endif
        .crit
            ASL $16
        .return
            LDX !RamEnemyIndex ; Instruction replaced by hijack
            RTS
        .freespace
        !FreespaceA0 := HandleEnemyCritContactDamage_freespace
        warnpc !FreespaceA0End
    }
}

; =================================================
; ===================== ITEMS =====================
; =================================================
{
    org $8486C1 : PlmInstSetPreInst:
    org $848724 : PlmInstGoTo:
    org $84874E : PlmInstSetTimer:
    org $848764 : PlmInstLoadItemGfx:
    org $84887C : PlmInstGoToIfItemCollected:
    org $848899 : PlmInstSetItemCollected:
    org $8488F3 : PlmInstCollectEquipment:
    org $848A24 : PlmInstSetLinkInst:
    org $848A2E : PlmInstCallInstructionList:
    org $848BDD : PlmInstQueueMusicTrack:
    org $84DF89 : PreInstGoToLinkIfTriggered:
    org $84DFA9 : InstructionListEmptyItem:
    org $84DFAF : InstructionListItemOrb:
    org $84DFC7 : InstructionListItemOrbBurst:
    org $84EE64 : PlmSetupNormalItem:

    org !Freespace84

    ; PLM entries. Format: PlmSetupPointer, InstructionListPointer.
    if !IncludeCritImmunityNormalPlm > 0
        print "PLM Entry - Crit immunity item: ", pc
        dw PlmSetupNormalItem, InstructionListCritImmunityItem
    endif
    if !IncludeCritImmunityChozoPlm > 0
        print "PLM Entry - Crit immunity item (chozo): ", pc
        dw PlmSetupNormalItem, InstructionListCritImmunityItemChozo
    endif
    if !IncludeEnemyCritNormalPlm > 0
        print "PLM Entry - Enemy crit item: ", pc
        dw PlmSetupNormalItem, InstructionListEnemyCritItem
    endif
    if !IncludeEnemyCritChozoPlm > 0
        print "PLM Entry - Enemy crit item (chozo): ", pc
        dw PlmSetupNormalItem, InstructionListEnemyCritItemChozo
    endif

    InstructionListCritImmunityItem: {
    if !IncludeCritImmunityNormalPlm > 0
            dw PlmInstLoadItemGfx
                dw !CritImmunityItemGfxROMLocation
                db $00 ; Item GFX Palette index - block 1 - top-left
                db $00 ; Item GFX Palette index - block 1 - top-right
                db $00 ; Item GFX Palette index - block 1 - bottom-left
                db $00 ; Item GFX Palette index - block 1 - bottom-right
                db $00 ; Item GFX Palette index - block 2 - top-left
                db $00 ; Item GFX Palette index - block 2 - top-right
                db $00 ; Item GFX Palette index - block 2 - bottom-left
                db $00 ; Item GFX Palette index - block 2 - bottom-right
            dw PlmInstGoToIfItemCollected, .delete
            dw PlmInstSetLinkInst, .collectItem
            dw PlmInstSetPreInst, PreInstGoToLinkIfTriggered
        .loop
            dw $E04F ; Draw item frame 0
            dw $E067 ; Draw item frame 1
            dw PlmInstGoTo, .loop
        .collectItem
            dw PlmInstSetItemCollected
            dw PlmInstQueueMusicTrack : db $02 ; Clear music queue and queue item fanfare music track
            dw PlmInstCollectEquipment, !CritImmunityItemBit : db !CritImmunityItemMessageBox
        .delete
            dw PlmInstGoTo, InstructionListEmptyItem
    endif
    }

    InstructionListCritImmunityItemChozo: {
    if !IncludeCritImmunityChozoPlm > 0
            dw PlmInstLoadItemGfx
                dw !CritImmunityItemGfxROMLocation
                db $00 ; Item GFX Palette index - block 1 - top-left
                db $00 ; Item GFX Palette index - block 1 - top-right
                db $00 ; Item GFX Palette index - block 1 - bottom-left
                db $00 ; Item GFX Palette index - block 1 - bottom-right
                db $00 ; Item GFX Palette index - block 2 - top-left
                db $00 ; Item GFX Palette index - block 2 - top-right
                db $00 ; Item GFX Palette index - block 2 - bottom-left
                db $00 ; Item GFX Palette index - block 2 - bottom-right
            dw PlmInstGoToIfItemCollected, .delete
            dw PlmInstCallInstructionList, InstructionListItemOrb
            dw PlmInstCallInstructionList, InstructionListItemOrbBurst
            dw PlmInstSetLinkInst, .collectItem
            dw PlmInstSetPreInst, PreInstGoToLinkIfTriggered
            dw PlmInstSetTimer : db $16
        .loop
            dw $E04F ; Draw item frame 0
            dw $E067 ; Draw item frame 1
            dw PlmInstGoTo, .loop
        .collectItem
            dw PlmInstSetItemCollected
            dw PlmInstQueueMusicTrack : db $02 ; Clear music queue and queue item fanfare music track
            dw PlmInstCollectEquipment, !CritImmunityItemBit : db !CritImmunityItemMessageBox
        .delete
            dw PlmInstGoTo, InstructionListEmptyItem
    endif
    }

    InstructionListEnemyCritItem: {
    if !IncludeEnemyCritNormalPlm > 0
            dw PlmInstLoadItemGfx
                dw !EnemyCritItemGfxROMLocation
                db $00 ; Item GFX Palette index - block 1 - top-left
                db $00 ; Item GFX Palette index - block 1 - top-right
                db $00 ; Item GFX Palette index - block 1 - bottom-left
                db $00 ; Item GFX Palette index - block 1 - bottom-right
                db $00 ; Item GFX Palette index - block 2 - top-left
                db $00 ; Item GFX Palette index - block 2 - top-right
                db $00 ; Item GFX Palette index - block 2 - bottom-left
                db $00 ; Item GFX Palette index - block 2 - bottom-right
            dw PlmInstGoToIfItemCollected, .delete
            dw PlmInstSetLinkInst, .collectItem
            dw PlmInstSetPreInst, PreInstGoToLinkIfTriggered
        .loop
            dw $E04F ; Draw item frame 0
            dw $E067 ; Draw item frame 1
            dw PlmInstGoTo, .loop
        .collectItem
            dw PlmInstSetItemCollected
            dw PlmInstQueueMusicTrack : db $02 ; Clear music queue and queue item fanfare music track
            dw PlmInstCollectEquipment, !EnemyCritItemBit : db !EnemyCritItemMessageBox
        .delete
            dw PlmInstGoTo, InstructionListEmptyItem
    endif
    }

    InstructionListEnemyCritItemChozo: {
    if !IncludeEnemyCritChozoPlm > 0
            dw PlmInstLoadItemGfx
                dw !EnemyCritItemGfxROMLocation
                db $00 ; Item GFX Palette index - block 1 - top-left
                db $00 ; Item GFX Palette index - block 1 - top-right
                db $00 ; Item GFX Palette index - block 1 - bottom-left
                db $00 ; Item GFX Palette index - block 1 - bottom-right
                db $00 ; Item GFX Palette index - block 2 - top-left
                db $00 ; Item GFX Palette index - block 2 - top-right
                db $00 ; Item GFX Palette index - block 2 - bottom-left
                db $00 ; Item GFX Palette index - block 2 - bottom-right
            dw PlmInstGoToIfItemCollected, .delete
            dw PlmInstCallInstructionList, InstructionListItemOrb
            dw PlmInstCallInstructionList, InstructionListItemOrbBurst
            dw PlmInstSetLinkInst, .collectItem
            dw PlmInstSetPreInst, PreInstGoToLinkIfTriggered
            dw PlmInstSetTimer : db $16
        .loop
            dw $E04F ; Draw item frame 0
            dw $E067 ; Draw item frame 1
            dw PlmInstGoTo, .loop
        .collectItem
            dw PlmInstSetItemCollected
            dw PlmInstQueueMusicTrack : db $02 ; Clear music queue and queue item fanfare music track
            dw PlmInstCollectEquipment, !EnemyCritItemBit : db !EnemyCritItemMessageBox
        .delete
            dw PlmInstGoTo, InstructionListEmptyItem
    endif
        .freespace
    }
    !Freespace84 := InstructionListEnemyCritItemChozo_freespace
    warnpc !Freespace84End

    org $890000+!CritImmunityItemGfxROMLocation
        incbin !CritImmunityItemGfxFileLocation
    org $890000+!EnemyCritItemGfxROMLocation
        incbin !EnemyCritItemGfxFileLocation
}

; ========================================================
; ============== REPORT RAM/FREESPACE USAGE ==============
; ========================================================
{
    if !ReportFreespaceUsage == 1
        print "Freespace usage:"
        print "  Bank $84:"
        org !Freespace84ReportStart              : print "    First used byte:             $", pc
        org !Freespace84                         : print "    First free byte after usage: $", pc
        org !Freespace84-!Freespace84ReportStart : print "    Bytes used:                 0x", pc
        print "  Bank $91:"
        org !Freespace91ReportStart              : print "    First used byte:             $", pc
        org !Freespace91                         : print "    First free byte after usage: $", pc
        org !Freespace91-!Freespace91ReportStart : print "    Bytes used:                 0x", pc
        print "  Bank $93:"
        org !Freespace93ReportStart              : print "    First used byte:             $", pc
        org !Freespace93                         : print "    First free byte after usage: $", pc
        org !Freespace93-!Freespace93ReportStart : print "    Bytes used:                 0x", pc
        print "  Bank $A0:"
        org !FreespaceA0ReportStart              : print "    First used byte:             $", pc
        org !FreespaceA0                         : print "    First free byte after usage: $", pc
        org !FreespaceA0-!FreespaceA0ReportStart : print "    Bytes used:                 0x", pc
        print "  Any Bank $80-$BF:"
        org !FreespaceAnywhereReportStart                    : print "    First used byte:             $", pc
        org !FreespaceAnywhere                               : print "    First free byte after usage: $", pc
        org !FreespaceAnywhere-!FreespaceAnywhereReportStart : print "    Bytes used:                 0x", pc
    endif
}