lorom

; by Nodever2 October 2025
; Please give credit if you use this patch.

; Death forgiveness. This allows Samus to survive with 1 HP if she has a certain amount of HP before being hit. Can customize how much health the player needs in order to survive an instant kill,
; and how much HP she is left with when she does.
; This helps give the player one last chance to recover when taking a cheap shot. You'd be surprised how many modern games incorporate things like this.
; Uses no freespace - rewrites the vanilla damage Samus routine and part of the periodic damage routine.
; I removed the check that vanilla has where if Samus takes 300 damage, it's treated like 0 damage. No idea why that was there.

; Revision 1 - !HealthRemaining is now customizable.
; Revision 2 - 2026-01-25 Now protects from periodic damage including spikes in the same way as other damage sources. Added option to disable this.
;                Also added option to disable forgiveness when Samus has reserve health.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !HealthThreshold = #$001E ; If Samus has at least this much health, she will survive an instant kill with !HealthRemaining HP. Default: 30 (decimal). This should be greater than !HealthRemaining.
                              ;   In vanilla, the low health alarm plays when Samus has 30 (decimal) or less HP.
    !HealthRemaining = #$0001 ; This is how much health Samus will be left with when she takes damage that is otherwise fatal.
    !ForgivePeriodicDamage       = 1 ; Set to 0 to disable death forgiveness from periodic damage including heat & spikes.
    !ForgiveWhenReservesNotEmpty = 0 ; Set to 0 to disable forgiveness when Samus' reserve health is not zero (REGARDLESS OF IF RESERVE TANKS ARE ON AUTO OR MANUAL MODE)

    ; Vanilla variables
    !RamSamusHealth        = $09C2
    !RamSamusSubHealth     = $0A4C ; only used by periodic damage
    !RamSamusReserveHealth = $09D6
    !RamTimeIsFrozenFlag   = $0A78
    !RamPeriodicDamage     = $0A50
    !RamPeriodicSubDamage  = $0A4E
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
        PHP : PHX
        REP #$30
        STA $12                                ; $12 = [A]
        TAX : BMI $FE                          ; If [$12] < 0: Crash
        LDX !RamTimeIsFrozenFlag : BNE .return ; If time is frozen: return

        ; X = 0 from previous line of code           ;\
        LDA !RamSamusHealth                          ;|
        CMP !HealthThreshold : BMI .dealDamage       ;) X = What Samus' health will be set to when recieving fatal damage. If she is allowed forgiveness this time, it will be nonzero.
        if !ForgiveWhenReservesNotEmpty == 0         ;|
        CPX !RamSamusReserveHealth : BNE .dealDamage ;|
        endif                                        ;|
        LDX !HealthRemaining                         ;/
    .dealDamage
        SEC : SBC $12          ; Subtract damage from Samus' health
        BEQ + : BPL .setHealth ; If she still has health remaining, store it and end.
    +   TXA                    ; Else, give Samus X HP.
    .setHealth
        STA !RamSamusHealth
    .return
        PLX : PLP : RTL
    print "DealDamageEnd: ", pc
    warnpc $91DF80
}

; ==================================================
; ==== DEAL PERIODIC/ENVIRONMENTAL/SPIKE DAMAGE ====
; ==================================================
{
    if !ForgivePeriodicDamage > 0
    org $90EA24
    HandlePeriodicDamage:
        ; Carry contains result of subtracting environmental subdamage from Samus' sub health
        LDA !RamPeriodicDamage
        BCS + : INC ; If carry is 0 (meaning subtraction underflow), do 1 more damage to Samus' HP to account for this.
    +   JSL DealDamage
        LDA !RamSamusHealth : BNE .end
        STZ !RamSamusSubHealth
        BRA .end 
    warnpc $90EA3D
    org $90EA3D
    .end
    endif
}