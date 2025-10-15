lorom

; by Nodever2 October 2025
; Please give credit if you use this patch.

; Death forgiveness. This allows Samus to survive with 1 HP if she has a certain amount of HP before being hit. Can customize how much health the player needs in order to survive an instant kill.
; This helps give the player one last chance to recover when taking a cheap shot. You'd be surprised how many modern games incorporate things like this.
; Uses no freespace - rewrites the vanilla damage Samus routine.
; I removed the check that vanilla has where if Samus takes 300 damage, it's treated like 0 damage. No idea why that was there.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !HealthThreshold = #$001E ; If Samus has at least this much health, she will survive an instant kill with 1 HP. Default: 30 (decimal). This should be a value of 2 or greater.
                              ; In vanilla, the low health alarm plays when Samus has 30 (decimal) or less HP.

    ; Vanilla variables
    !RamSamusHealth = $09C2
    !RamTimeIsFrozenFlag = $0A78
}

; ==================================================
; ============== DEAL DAMAGE TO SAMUS ==============
; ==================================================
{
    ;; Parameters:
    ;;     A: Damage. Negative = crash
    ; Ignores suits, call $A0:A45E for suit-adjusted damage
    org $91DF51
    DealDamage:
        PHP : PHB : PHX
        PHK : PLB                              ; DB = $91
        REP #$30
        STA $12                                ; $12 = [A]
        TAX : BPL + : BRA $FE                  ; If [$12] < 0: Crash
    +   LDA !RamTimeIsFrozenFlag : BNE .return ; If time is frozen: return

        LDA !RamSamusHealth
        LDX #$0000                             ;\
        CMP !HealthThreshold : BMI .dealDamage ;) X = 1 if Samus is allowed forgiveness, 0 otherwise.
        INX                                    ;/
    .dealDamage
        SEC : SBC $12          ; Subtract damage from Samus' health
        BEQ + : BPL .setHealth ; If she still has health remaining, store it and end.
    +   TXA                    ; If Samus is allowed forgiveness, give her 1 HP - else, give her 0 HP.
    .setHealth
        STA !RamSamusHealth
    .return
        PLX : PLB : PLP : RTL
    print "DealDamageEnd: ", pc
    warnpc $91DF80
}