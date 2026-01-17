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
    !SamusDoubleCritsEnabled        = 1 ; Set to 1 to enable Samus double-crits. Uses slightly more freespace.
    !EnemyDoubleCritsEnabled        = 1 ; Set to 1 to enable enemy double-crits. Uses slightly more freespace.
    !SamusCritChance                = #$5000 ;\
    !SamusDoubleCritChance          = #$6800 ;) Higher number = lower chance. I know. Sorry.
    !EnemyCritChance                = #$6800 ;|    Min value = 0001, max value = 7FFF.
    !EnemyDoubleCritChance          = #$7800 ;/    Also, double-crit odds partially overlap normal crit odds.
    !CritPaletteROMLocation         = $CC00 ; In $9B. 20h bytes.
    !DoubleCritPaletteROMLocation   = $CC20 ; In $9B. 20h bytes. Only written if Samus double-crits are enabled.
    !CritPaletteFileLocation        = "./criticalHitPalettes/critPalette.bin" ; File location on your computer.
    !DoubleCritPaletteFileLocation  = "./criticalHitPalettes/doubleCritPalette.bin"
    !FreespaceAnywhere              = $80FF50 ; Any bank $80-$BF, but do not cross bank boundaries.
    !FreespaceAnywhereEnd           = $80FFC0
    !Freespace91                    = $91FFEE
    !Freespace91End                 = $91FFFF
    !Freespace93                    = $93F620
    !Freespace93End                 = $93FFFF
    !FreespaceA0                    = $A0F900
    !FreespaceA0End                 = $A0FFFF

    ; new variables - can repoint the ram that these use
    !RamSamusCritFlag = $7ED8EE ; Whether or not a crit happened to Samus.
    ;{
    ;    0: No crit
    ;    1: Crit
    ;    2: Double crit
    ;}

    ; Vanilla variables - don't touch
    !RamRandomNumber      = $05E5
    !RamEnemyIndex        = $0E54
    !RamProjectileDamages = $0C2C
}

; =================================================
; ================== SAMUS CRITS ==================
; =================================================
{
    org $91DF61 ; Hijack routine - Deal [A] damage to Samus
        JSL HandleSamusCritDamage : NOP ; Hijack point overwrites useless code - no need to 

    org !FreespaceAnywhere
    HandleSamusCritDamage: {
            LDA #$0000 : STA !RamSamusCritFlag
            LDA !RamRandomNumber
            LSR
            if !SamusDoubleCritsEnabled > 0
                CMP !SamusDoubleCritChance : BPL .doubleCrit
            endif
            CMP !SamusCritChance : BPL .crit
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
; ================== ENEMY CRITS ==================
; =================================================
{
    org $93803F ; Hijack routine - Initialize projectile
        JSR HandleEnemyCritDamage
        BRA $04

    org !Freespace93
    HandleEnemyCritDamage: {
            STA !RamProjectileDamages,X ; Instruction replaced by hijack - set projectile damage
            LDA !RamRandomNumber
            LSR
            if !EnemyDoubleCritsEnabled > 0
                CMP !EnemyDoubleCritChance : BPL .doubleCrit
            endif
            CMP !EnemyCritChance : BPL .crit
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
            LDA !RamRandomNumber
            LSR
            if !EnemyDoubleCritsEnabled > 0
                CMP !EnemyDoubleCritChance : BPL .doubleCrit
            endif
            CMP !EnemyCritChance : BPL .crit
            LDX !RamEnemyIndex ; Instruction replaced by hijack
            RTS
        .doubleCrit
            if !EnemyDoubleCritsEnabled > 0
                ASL $16
            endif
        .crit
            ASL $16
            LDX !RamEnemyIndex ; Instruction replaced by hijack
            RTS
        .freespace
        !FreespaceA0 := HandleEnemyCritContactDamage_freespace
        warnpc !FreespaceA0End
    }
}