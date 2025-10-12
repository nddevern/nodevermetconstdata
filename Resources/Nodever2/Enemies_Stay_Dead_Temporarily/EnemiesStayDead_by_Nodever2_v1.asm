lorom

; This patch remembers which enemies were killed in the past 5 rooms that Samus killed enemies in. (If Samus passes through a room without killing an enemy, it does not count towards the 5 room total).
; When Samus re-enters one of those rooms, the enemies she killed will not spawn.
; The code does not delete respawning enemies, or enemies in rooms with bosses ($179C > 0). It sets the Enemies Killed In Current Room counter ($0E50) appropriately, so enemy kill doors will also still work as expected.
; Only the first 16 (decimal) enemies in each room are remembered. Respawning enemies still count towards this, so if you have more than 16 enemies in a room, make respawning enemies the 17th enemy index or later.
; The amount of rooms to remember is customizable, but the amount of enemies to remember per room is not.

; LIMITATIONS: 1. If your hack supports having room enemy population data in multiple banks (in vanilla it's always in $B4) then this code will not work as expected in edge cases
;                    (where the two banks both have enemy population data at the same offset). As long as it's all in the same bank it's fine no matter which bank.
;              2. Currently, other than the Respawning bit, there is no way to make an enemy instance not stay dead via this code. This could be problematic for enemies that are killable but are also
;                    required for progressing through rooms. Without this patch, the player could simply reload the room to respawn those enemies.
;                    If you know ASM, it would be pretty trivial to add a bit to the enemy header to not stay dead or something and check it in this code.
;              3. If your hack kills or deletes enemies using code other than $A0A3AF and you want them to stay dead using this code, that will not work out of the box, and you'll have to call into SetBitIfNeeded yourself.
;              4. Wasn't sure how to handle firefleas for game balance reasons, so I added a hardcoded check to not remember their deaths. Feel free to remove that. Or add code to darken the room when a fireflea is deleted upon
;                    room load - see $A38E6B

; by Nodever2 October 2025 - Developed with ASAR. Will not work with xkas.
; Uses !NumRooms*4 + 2 consecutive bytes of RAM located at !RamStart. 22 decimal bytes when !NumRooms = 5, which is the default.

; format: 2 parallel arrays, entries 2 bytes long each, + 2 extra bytes added to the room enemy set poitner list for terminator.
; first array has 16 bits representing whether the first 16 enemies in the room were killed or not. Flags will not be set if the enemy is respawning.
; second array has room enemy set pointer
; The start of the list is always the oldest rooms to have been added, and the end of the list is always the newest.

; =================================================
; ============== VARIABLES/CONSTANTS ==============
; =================================================
{
    ; Constants - feel free to edit these
    !Freespace80          = $80D196
    !FreespaceA0          = $A0F7D3
    !FreespaceAnywhere    = $83FCE0
    !EndFreespaceAnywhere = $83FFFF
    !NumRooms             = $0005 ; The last !NumRooms rooms where an enemy was killed will be remembered.

    ; Vanilla variables
    !RamEnemiesKilled          = $0E50
    !RamEnemyIndex             = $0E54
    !RamEnemyPopulationPointer = $07CF
    !RamEnemyIDs               = $0F78
    !RamEnemyProperties        = $0F86
    !RamBitmask                = $05E7 ; Bitmask. In particular, the bitmask result of $80:818E (change nth bit index to byte index and bitmask).
    !RamBossID                 = $179C

    ; New variables - Feel free to move !RamStart and !RamBank to where you'd like.
    !RamBank                            = $7F0000
    !RamStart                          #= $FB00+!RamBank
    !RamEnemyBitflagTable               = !RamStart
    !RamEnemyPopulationPointerTable    #= ($02*!NumRooms)+!RamEnemyBitflagTable
    !RamEnemyPopulationPointerTableEnd #= ($02*!NumRooms)+!RamEnemyPopulationPointerTable+$02 ; leave room for 2 byte FF terminator in the level data pointer table
    !RamEnd                             = !RamEnemyPopulationPointerTableEnd
    
    org !RamStart         : print "First used byte of RAM:              $", pc
    org !RamEnd           : print "First free RAM byte after RAM Usage: $", pc
    org !RamEnd-!RamStart : print "RAM bytes used:                     0x", pc
}

; =======================================
; ============== GAME INIT ==============
; =======================================
{
    ; We need to initialize these ram values we are using on game start, as the game does not do this by default.
    ORG $80A085
        JSR InitRam

    ORG !Freespace80
    InitRam:
        PHA : PHX : LDA #$FFFF ; Initializing to FFFF because that is the terminator.
        LDX #!RamStart
    -   STA !RamBank,x
        INX : INX
        CPX #!RamEnd : BMI -
        PLX : PLA : STZ $07E9 : RTS ; instruction replaced by hijack
    warnpc $80FFC0
}

; ==================================================
; ============== LOAD ENEMIES IN ROOM ==============
; ==================================================
{
    ; Hijack
    org $A08B88 : JSR CheckEnemy

    ; Enemy index in Y.
    ; Delete enemy if not respawning and enemy flag is set in the new table.
    org !FreespaceA0
    CheckEnemy:
        STA $1786 ; Instruction replaced by hijack
        PHP : PHA : PHX : PHY : REP #$30
        
        LDA !RamEnemyIDs,y : BEQ .initializeEnemy ; This branch should never be taken
        LDA !RamEnemyProperties,y : AND #$4000 : BNE .initializeEnemy ; Enemy respawns, let it do so
        
        JSL GetEnemyPopulationPointerTableIndex : CMP #$FFFF : BEQ .initializeEnemy ; If pointer is FFFF, we didn't find a match in the table.
        
        CPX #!NumRooms*2-2 : BEQ .checkBit
        
        ; If we found an entry that is not the most recent entry in the list, move it
        ; so that it is considered the most recent entry in the list.
        LDA !RamEnemyBitflagTable,x : PHA
        JSL PushListEntries
        PLA : STA !RamEnemyBitflagTable,x
        LDA !RamEnemyPopulationPointer : STA !RamEnemyPopulationPointerTable,x

        ; Found it, index is in X. Enemy index in Y.
    .checkBit
    +   TYA : JSL GetFinalIndexAndBitmask : BCC .initializeEnemy
        TAX : LDA !RamEnemyBitflagTable,x : AND !RamBitmask : BNE .deleteEnemy ; Check if bit is set in our list
        
    .initializeEnemy
        PLY : PLX : PLA : PLP : RTS
    .deleteEnemy
        INC !RamEnemiesKilled

        TYX
        LDY #$003E  ;\
                    ;|
    -   STZ $0F78,x ;|
        INX : INX   ;) Clear enemy slot
        DEY : DEY   ;|
        BPL -       ;/

        PLY : PLX : PLA : PLP : PLA : JMP $8B91 ; Skip enemy init
    warnpc $A0FFFF
}

; =========================================
; ============== ENEMY DEATH ==============
; =========================================
{
    org $A0A3D0 : NOP #2 : JSL SetBitIfNeeded

    org !FreespaceAnywhere
    SetBitIfNeeded:
        STA $0E20 : LDX !RamEnemyIndex   ; Instructions replaced by hijack - load enemy index into X
        PHP : PHA : PHY : PHX : REP #$30 ; load enemy index into top of stack

        LDA !RamEnemyPopulationPointer : CMP #$FFFF : BEQ .return ; If the room does not have an enemy population pointer, do not set bit
        LDA !RamEnemyProperties,x : AND #$4000 : BNE .return ; If enemy respawns, do not set bit
        LDA !RamBossID : BNE .return ; Do not remember dead enemies in boss rooms
        LDA !RamEnemyIDs,x : CMP #$D6BF : BEQ .return ; Do not remember firefleas. I hate doing things like this but it seems like the best thing for the game's balance.

        ; Check if a matching entry exists in the table
        JSL GetEnemyPopulationPointerTableIndex : CMP #$FFFF : BNE .foundEntry
        ; We didn't find it in the table, we need to add the entry
        CPX #!NumRooms*2 : BMI .buildEntry ; If X >= #!NumRooms*2, then the list is full. We need to bump the entries forward and add our room.

    .removeOldestEntry
        LDX #$0000
        JSL PushListEntries

    .buildEntry ; X is the index of the first free entry in the table
        LDA !RamEnemyPopulationPointer : STA !RamEnemyPopulationPointerTable,x
        LDA #$0000 : STA !RamEnemyBitflagTable,x

    .foundEntry ; Actually set bit
        LDA $01,s ; top of stack has enemy index
        JSL GetFinalIndexAndBitmask : BCC .return
        TAX : LDA !RamEnemyBitflagTable,x : ORA !RamBitmask : STA !RamEnemyBitflagTable,x ; Set bit in list

    .return
        PLX : PLY : PLA : PLP : RTL
    .freespace
    !FreespaceAnywhere := SetBitIfNeeded_freespace ; shoutout to cout for this cool shit - https://github.com/cout/baby_metroid/
    warnpc !EndFreespaceAnywhere
}

; ==============================================
; ============== HELPER FUNCTIONS ==============
; ==============================================
{
    org !FreespaceAnywhere
        ; Parameters: 
        ;   X = Index into !RamEnemyPopulationPointerTable for this room
        ;   A = Enemy index
        ; Returns:
        ;   !RamBitMask = Bitmask for the desired enemy flag
        ;   A = Byte index into !RamEnemyBitflagTable for the desired enemy flag
        ;   X = Index into !RamEnemyPopulationPointerTable for this room
        ;   C = 0 if index out of bounds, 1 otherwise
        GetFinalIndexAndBitmask: {
            PHX                    ; Top of stack = index into list for this room
            LSR #6                 ; A = Enemy Index / 40h - Each enemy index is 40h bytes apart
            CMP #$0010 : BPL .fail ; If this is the 16th or higher enemy in the room, return carry clear
            JSL $80818E            ; Convert bit index to byte index and bitmask
            CLC : ADC $01,s        ; Add (byte index into this room's enemy respawn data) to (this room's index into the list of room enemy respawn data)
            PLX : SEC : RTL        ; return carry set
        .fail
            PLX : CLC : RTL
        }

        ; Parameters: 
        ;   !RamEnemyPopulationPointer = This room's enemy population pointer
        ; Returns:
        ;   X = Index into !RamEnemyPopulationPointerTable for this room if found, otherwise it will be the index of the terminator
        ;   A = !RamEnemyPopulationPointerTable,x if found, FFFF otherwise
        GetEnemyPopulationPointerTableIndex: {
            LDX #$0000-2
        -   INX : INX : LDA !RamEnemyPopulationPointerTable,x
            CMP #$FFFF : BEQ .return ; Encountered terminator
            CMP !RamEnemyPopulationPointer : BNE - ; Found matching enemy set
        .return
            RTL
        }

        ; Parameters:
        ;   X = Index of the entry to be overwritten when moving entries towards the start of the list.
        ;       All entries after this one will be moved towards the start of the list.
        ; Returns:
        ;   X = Index of the first free entry in the table.
        ;   A = FFFF.
        PushListEntries: {
            DEX : DEX
        -   INX : INX
            LDA !RamEnemyBitflagTable+2,x : STA !RamEnemyBitflagTable,x
            LDA !RamEnemyPopulationPointerTable+2,x : STA !RamEnemyPopulationPointerTable,x
            CMP #$FFFF : BNE - ; Encountered terminator
            RTL
        }

    warnpc !EndFreespaceAnywhere
}