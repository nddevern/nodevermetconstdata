lorom
; Modern Bugfix Compilation by Nodever2.
; PreRelease1 released Jan 28, 2023.

; note: many of these bugfixes have already been included in other patches.
; these are organized from low address to high address.

; todo: 1) continue searching through metconst discord for relevant mentions of the word "bug",
; 12-22-21 to 5-3-22 have all been searched so far
; 2) look through all vanilla bugfix patches on both new and old site and forums and add to this
; 3) look through metconst discord for other things like "error" and add to this
; 4) go through bank logs, look for any other mentions of bugs/errors
; also add a separate section for bugs with known fixes for which the fix would not be an objective improvement
; 5) also add maybe small improvements like reserves coming full

; 6) ADD JAM BUGFIXES FROM https://forum.metroidconstruction.com/index.php/topic,145.msg4812.html#msg4812

;===========================================RAM DEFINES==========================================
{
	!equippedItems = $09A2
	!samusContactDamageIndex = $0A6E
	!chargeCounter = $0CD0
	!plmIds = $1C37
}
;================================================================================================
; Routine: $82AFDB (equipment screen - main - weapons - move response)
; Bug: When having only a beam and a suit you have to press right+up to go from beam to suit. It's not natural.
; Fix by RandomMetroidSolver Team from https://github.com/theonlydude/RandomMetroidSolver/blob/master/patches/common/src/vanilla_bugfixes.asm
;                                      Fix it to only require pressing right
{
	;; test of return of $B4B7 compare A and #$0000,
	;; when no item found A==#$ffff, which sets the carry,
	;; so when carry is clear it means that an item was found in misc.
	;; if no item was found in misc, we check in boots then in suits,
	;; so if an item is found in both boots and suits, as suits is
	;; tested last the selection will be set on suits.
    org $82B000 : BCC $64
}
;================================================================================================
; Routine: $82B4B7 (equipment screen - move cursor lower on suits/misc)
; Bug: Cannot access screw attack in the menu without spring ball or boots due to an incorrect comparison value
; Fix by PJBoy on the bank logs directly:
{
	;  Cause: CPX #$000A should be CPX #$000C.
	org $82B4C4 : CPX #$000C
}
;================================================================================================
; Routine: $82DB68 (handle Samus running out of health and increment game time)
; Bug: Crashes the game if pausing during reserves
; Fix by Benox50 from https://metroidconstruction.com/resource.php?resource_id=418
;  (note that the linked resource contains other changes than this tweak)
{
	;  Check game state first in this routine.
	org $82DB73 ; occurs when samus runs out of hp
	; Check GameState, Crash safe 
		LDA $0998
		CMP #$0008 : BEQ +
		PLP : RTS
	+
	; Multi Checks if we do auto reserve or kill
		LDA $09C0
		BIT #$0001 : BEQ SamusNoHpContinueA ;if reserve auto
		LDA $09D6 : BEQ SamusNoHpContinueA ;if reserve 0 
	
	; Trigger Auto Reserves
		LDA #$8000 : STA $0A78
		LDA #$001B : STA $0998
		JSL $90F084    
		BRA SamusNoHpContinueB
	
	; Resume vanilla routine
	org $82DB9F
	SamusNoHpContinueA: ; Kill Samus (Game state = 13h)
	
	org $82DBB2
	SamusNoHpContinueB: ; TICK_GAME_TIME
}
;================================================================================================
; Routine: $84831A (load x-ray blocks)
; Bug: Game crashes when there is a respawning PLM in the room
; Fix by amoeba from metconst discord:
{
	; Don't crash the game when using X-Ray on a respawning PLM. (Originally $2C, $2B is what was intended - use $2B to make respawning PLMs not show under X-Ray so they are easier to find.)
	;  A better solution is $0F by amoeba which fixes the bug and makes them show under Xray as well
	org $848331 : BMI $0F
}
;================================================================================================
; Routine: $848CF1 (Instruction - activate save station and go to [[Y]] if [save confirmation selection] = no)
; Bug: Only the first 7 save slots are able to be read by save station code, but more are available.
; Fix by RandomMetroidSolver team from https://github.com/theonlydude/RandomMetroidSolver/blob/master/patches/common/src/vanilla_bugfixes.asm
{
    ;;; allow all possible save slots (needed for area rando extra stations)
    org $848D0C : AND #$001F
}
;================================================================================================
; Routine: $84A613, $84A61F, $84A663, $84A66F (yellow gate button PLM draw instructions)
; Bug: Yellow gate uses the wrong graphics tile, looks like a grey gate in vanilla
; Fix by JAM (Yellow Gate Fix) from http://old.metroidconstruction.com/patches.php?x=top
{
	org $84A61B : dw $C0DC ; downwards left
	org $84A623 : dw $C4DC ; downwards right
	org $84A66B : dw $C8DC ; upwards   left
	org $84A673 : dw $CCDC ; upwards   right
}
;================================================================================================
; Routine: $84CE83 (bomb block collision reaction PLM setup)
; Bug: doesn't break if samus is screw attacking in wall jump pose
; Fix by PJBoy from https://metroidconstruction.com/resource.php?id=530
{
	org $84CE83
	Setup_BombBlockCollision:
		; If contact damage is not speed boosting / shinesparking / screw attack, delete PLM
		LDA !samusContactDamageIndex : DEC : CMP #$0003 : BCC .breakBlock
		TYX : STZ !plmIds,x
		SEC : RTS
	warnpc $84CEC1
		
	org $84CEC1
	.breakBlock
}
;================================================================================================
; Routine: Morph Ball item pickup (chozo orb and shot block variants only) instruction lists
; Bug: Incorrect equipment argument for pickup equipment instruction; vanilla is 0002h (spring ball) and should be 0004h (morph ball)
; Fix by JAM (Morphing Ball Fix) from http://old.metroidconstruction.com/patches.php?x=top
{
	org $84E8CE : dw $0004 ; chozo orb
	org $84EE02 : dw $0004 ; shot block
}
;================================================================================================
; Routine: $86B6B9 (eye door projectile pre-instruction)
; Bug: Crash after 100h+ frames if you kill eye door on same frame eye door projectile spawns
; Fix by PJBoy from https://metroidconstruction.com/resource.php?id=492
{
	;  BUG: the $B707 branch assumes the enemy projectile index is in X, but this is only true if the branch on $B6BC/C1 is taken,
	;  otherwise the enemy projectile index is in Y, and the door bit array index is in X,
	;  causing misaligned writes to enemy projectile RAM if X is odd, eventually causing a crash when the garbage instruction pointer gets executed
	;  (which happens after a delay of 100h+ frames due to the misaligned write to the instruction time
	
	;  The fix here is setting the X register to the enemy projectile index,
	;  which can be done without free space due to an unnecessary RTS in the original code
	org $86B704
		BEQ eyedoorcrashfixret
		TYX
	
	org $86B713
	eyedoorcrashfixret:
}
;================================================================================================
; Routine: $90852C (handle speed booster animation delay)
; Bug at 859D: Overwrites reg A for SFX call but code afterwards expects the old A value. Can cause loss of blue suit seemingly randomly.
; Fix by Nodever2: save 2 bytes with TDC trickery and then PHA : PLA (assumes DP register is zero)
{
	;  This bug can cause the game to take away blue suit depending on what the sound effect call returns
	;  (spefifically, if the sound effect queue is full)
	org $90859D
		PHA       ;1 byte used
		TDC : INC ;1 byte saved
		STA $0B40
		INC : INC ;1 byte saved
		JSL $80914D
		PLA       ;1 byte used
}
;================================================================================================
; Routine: $9098BC (make Samus jump)
; Bug at $9927: bad Y velocity with speed booster
; Fix by Nodever2 from https://metroidconstruction.com/resource.php?id=494
{
	;  this is somewhat difficult to explain and I've already covered it before but basically
	;  the game improperly handles the addition to samus' Y velocity when she has speed booster.
	;  this is most noticeable when jumping with speed booster without high jump.
	
	;  This fix was also included in my patch Speed Booster Vertical Jump Speed Fix,
	;  more in-depth explanation can be found there.
	org $909927
		LDA $0B44		;\
		ROR				;| use carry from previous LSR
		CLC				;|
		ADC $0B2C		;) Samus Y subspeed += [Samus X subspeed]/2
		STA $0B2C		;/
		LDA $0B2E		;
}	
;================================================================================================
; Routine: $90A734 (samus movement - wall jumping)
; Bug: screw attack contact damage not set in this pose when screw attacking, allowing samus to get hit
; Fix by PJBoy from https://metroidconstruction.com/resource.php?id=530 (also included in benox's easier WJ patch)
{
	org $90A734
	SamusMovementWallJumping:
		; If screw attack equipped, set screw attack contact damage
		LDA !equippedItems : BIT #$0008 : BEQ .notScrewAttack
		LDA #$0003 : STA !samusContactDamageIndex
		BRA .contactDamageSet
	
	.notScrewAttack
		LDA !chargeCounter : CMP #$003C : BMI .contactDamageSet
		LDA #$0004 : STA !samusContactDamageIndex
	
	.contactDamageSet
		JMP $8FB3 ; Samus jumping movement
	
	warnpc $90A75F
}
;================================================================================================
; Routine: $91D9B2 (load blue suit palette)
; Bug: Samus' suit flashes glitchy colors if transitioning to blue suit palette from screw attack palette.
; Fix by Nodever2: Move check for out of bounds to before using the value
{
	;  Cause: LDA $0ACE at $91DA89 doesn't check if index is out of bounds first.
	;  This routine normally checks if it's out of bounds after running and corrects it for the next iteration,
	;  but since screw attack tables also use $0ACE as an index and those have longer tables,
	;  going from screw to speed can cause $0ACE to be too high and cause this index out of bounds issue.
	org $91DA89
		LDA $0ACE
		CMP #$0006 : BMI + : LDA #$0006   ;) Add 9 bytes
	+   TAY : CLC : ADC $24               ;/ (the TAY here is new)
		TAX : LDA $0000,x
		TAX : JSR $DD5B
		INY : INY : STY $0ACE : NOP : NOP ; save 9 bytes
}    
;================================================================================================
; Routine: $91F1FC (morph ball bounce - no springball)
; Bug: Turning off spring ball while bouncing can crash
; Fix by strotlog from https://github.com/theonlydude/RandomMetroidSolver/blob/master/patches/common/src/vanilla_bugfixes.asm
{
    ;;; Spring ball menu crash fix by strotlog.
    ;;; Fix obscure vanilla bug where: turning off spring ball while bouncing, can crash in $91:EA07,
    ;;; or exactly the same way as well in $91:F1FC:
    ;;; Fix buffer overrun. Overwrite nearby unreachable code at $91:fc4a (due to pose 0x65
    ;;; not existing) as our "free space". Translate RAM $0B20 values:
    ;;; #$0601 (spring ball specific value) --> #$0001
    ;;; #$0602 (spring ball specific value) --> #$0002
    ;;; thus loading a valid jump table array index for these two buggy functions.
    org $91ea07
        jsr fix_spring_ball_crash
    org $91f1fc
        jsr fix_spring_ball_crash
    org $91fc4a
    fix_spring_ball_crash:
        lda $0B20    ; $0B20: Used for bouncing as a ball when you land
        and #$00ff
        rts
    warnpc $91fc54 ; ensure we don't write past the point where vanilla-accessible code resumes
}    
;================================================================================================
; Routine: $A099F9 (Handle enemy projectile collision with projectile)
; Bug: Code for creating the dud shot graphics uses the wrong index register for the projectile position,
;      meaning the sprite object usually doesn't appear (used for nuclear waffle and Botwoon); thnks to PJ for identifying this bug
; Fix by MetroidNerd9001: Use the correct index registers
{
	org $A09A3D : db $B9 ; LDA $xxxx,X -> LDA $xxxx,Y
	org $A09A42 : db $B9 ; LDA $xxxx,X -> LDA $xxxx,Y
}
;================================================================================================
; Routine: Enemy / Samus collision handlers
; "Bug": Samus loses invincibility frames when hitting an enemy with screw attack
; Solution by PJBoy from discord:
{
	org $A0A096 : db $EA, $EA, $EA  ;) these tweaks make it so i-frames don't get reset when screw attack starts. (normally wouldn't be a problem but with respin it can be)
	org $A09A90 : db $EA, $EA, $EA  ;/
}
;================================================================================================
; Routine: $83A77D (mochtroid initialization AI)
; Bug: crashes when respawning
; Fix by PJ from bank logs: skip a check in the function "set enemy instruction list" call from init AI by changing function call destination
{
	org $A3A789 : JSR $A942
}
;================================================================================================
; Routine: Various WS ghost routines
; Bug: Uses indexing when reading Samus' posiiton???
; Fix by PJ from metconst discord:
{
	org $A89C13 : LDA $0AFA
	org $A89D45 : LDA $0AFA
	org $A89DC3 : LDA $0AF6
	org $A89DCD : LDA $0AFA
}
;================================================================================================
; Routine: $B4BD97 (clear sprite objects)
; Bug: Doesn't clear $7E:EF78 due to incorrect branch
; Fix by PJ from metconst discord:
{
	org $B4BDA3
		BPL $F8
}
;================================================================================================
;Honorable mentions:
; - Fix Kraid Vomit by PJ: https://metroidconstruction.com/resource.php?id=558
;   (not included due to freespace usage)
; - Door glitch fix by Black Falcon: https://metroidconstruction.com/resource.php?id=44
;   (not included due to freespace usage and incompatability with the commonly used patch Blackout Speedups)
; - Reserve Tank Bugfixes by Nodever2: https://metroidconstruction.com/resource.php?resource_id=418
;   (not included )



;Routine: RNG routine
;Bug: Bad
;Fix/Rewrite: steal from arcade, he posted it in metconst at one point so it's ok
;total — 01/13/2022
;This is the one used in SM Arcade: https://paste.ofcode.org/KFwPUSLiwRqFiPAU8YqEzG
;There's two versions with different periods, one with 32-bit and one with 16-bit period 
;Based on xorshift
;InsaneFirebat — 01/13/2022
;sweet, thanks
;Benox50 — 01/13/2022
;Running GDQ 👀 
;Wonder if he have a weight on GDQ accepting SM hacks 😩
;P.JBoy — 01/13/2022
;+1 on xorshift
;but I do think the SM RNG is good enough
;especially if its bug is fixed
;unless someone's doing monte carlo >_>
;Benox50 — 01/13/2022
;I like how this rng is smaller than vanilla too... rip
;P.JBoy — 01/13/2022
;the use of $16 makes me uncomfortable
;somerando(caauyjdp) — 01/13/2022
;/smram 16
;hilarious-man
;BOT
; — 01/13/2022
;$16: Common type or index value
;P.JBoy — 01/13/2022
;the DP misc. values are all very awkward
;it's real hard to say whether they need to be preserved or not
;ah but see
;this loop would break if $16 were clobbered http://patrickjohnston.org/bank/A9?just=B03E#B05B
;PJ's bank logs
;Bank $A9
;$B03E: Generate explosions around Mother Brain's body
;Image
;should break pretty badly actually
;I assume it's not used as a replacement RNG for Arcade then
;Benox50 — 01/13/2022
;just push pull $16
;man I would love to have an OP code to just PEA $16 directly
;P.JBoy — 01/13/2022
;there's PEI ($16)
;but no way to pull directly into $16 again
;Benox50 — 01/13/2022
;thats what I was gonna ask next :p
;it also always pushes a 16-bit value, regardless of PSR.m



;ANOTHER RNG ROUTINE DISCUSSION: https://discord.com/channels/127475613073145858/371734116955193354/989209124489293837
;Benox50 — 06/22/2022
;    LDA $05E5 : STA $16
;    ASL #2
;    EOR $16 : STA $16
;    LSR #5
;    EOR $16 : STA $16
;    ASL : EOR $16
;    STA $05E5
;amoeba — 06/22/2022
;it's not a long list no
;InsaneFirebat — 06/22/2022
;Thanks. At a glance that's at least twice what we have.
;Maybe they aren't all applicable
;amoeba — 06/22/2022
;I also made lava do a JSL to pull an extra random number partway through the frame instead of the XBA crap
;P.JBoy — 06/22/2022
;that XBA doesn't make any god damn sense
;I'm so annoyed at it
;amoeba — 06/22/2022
;it was because the RNG got stuck in a really small loop of just a few values because of the bug
;that makes it get unstuck
;as far as I know that's the only reason
;P.JBoy — 06/22/2022
;so it would maybe make sense to add in the RNG routine
;certainly not in the lava routine
;amoeba — 06/22/2022
;I guess they didn't want to always do it
;and recall that lava does use a lot of rng bits 
;so that's probably where they noticed it - in the audio 
;P.JBoy — 06/22/2022
;I certainly don't have a better theory
;amoeba — 06/22/2022
;I just made lave pull a fresh value and then use a not broken rng
;P.JBoy — 06/22/2022
;yeah that's definitely a better impl hahaha
;Benox50 — 06/22/2022
;why you removed reseeding? Isnt that gud
;amoeba — 06/22/2022
;the longer period is just a nice touch
;the reseeding is junk
;P.JBoy — 06/22/2022
;I don't understand the purpose of the reseeds either
;amoeba — 06/22/2022
;that's also needed to keep those enemies from jumping always in certain spots 
;Benox50 — 06/22/2022
;what difference does it make to do the efforts to remove them?
;amoeba — 06/22/2022
;so it reseeds to a better spot on the broken RNG state graph
;P.JBoy — 06/22/2022
;I assume seeding the RNG causes them to always jump the same way
;Benox50 — 06/22/2022
;less patterns?
;P.JBoy — 06/22/2022
;unlike the XBA trick
;amoeba — 06/22/2022
;I mean removing the reseed makes the RNG work correctly (especially since it has 32bits of state not 16)
;Benox50 — 06/22/2022
;the 32bits one looked a bit overkill
;P.JBoy — 06/22/2022
;$A3:AB0C A9 25 00    LDA #$0025             ;\
;$A3:AB0F 8D E5 05    STA $05E5  [$7E:05E5]  ;} Random number = 25h
;$A3:AB12 22 11 81 80 JSL $808111[$80:8111]  ; Generate random number
;
;hooray for maths
;InsaneFirebat — 06/22/2022
;lol
;What do yall like to do for the initial seeding?
;P.JBoy — 06/22/2022
;any non-zero value 
;probably 1 or -1
;InsaneFirebat — 06/22/2022
;I'm storing the current seeds in SRAM when exiting the menu (it's only updated in the menu, not used for gameplay) and restoring them from SRAM when its opened or when the game boots. That got rid of the predictable "random preset" I would often load before opening the menu at all.
;amoeba — 06/22/2022
;The one Total is using is 32bit
;16bit rng with 32bits of state
;the one I have is definitly different than the one you posted FWIW
;for initial seeding: I set my state to 0001;0001 since the RNG breaks if the are both 0
;(the rng will also never produce and internal state of 0000 0000, but the 16bit output can be 0000)
;Benox50 — 06/22/2022
;there were 2 from total, a small one and a Massive one ( this is how I call them in non programmer term instead of 16 and 32 x] ) 
;amoeba — 06/22/2022
;I think my "massive one" uses less bytes
;Benox50 — 06/22/2022
;sound contracditory, how does it looks like? 
;Benox50 — 06/22/2022
;cause Total's link borke
;amoeba — 06/22/2022
;  REP #$20 ; original function doesn't preserve P either and it seems to matter
;
;  ; t1 = x ^ (x << A)
;  LDA $1C21
;  ASL : ASL : ASL : ASL : ASL
;  EOR $1C21
;  STA $3E
;
;  ; t2 = t1 ^ (t1 >> B);
;  LSR : LSR : LSR
;  EOR $3E
;  STA $3E
;
;  ; x = y;
;  LDA $05E5
;  STA $1C21
;
;  ; y = (y ^ (y >> C)) ^ t2;
;  LSR
;  EOR $05E5
;  EOR $3E
;  STA $05E5
;
;  RTL
;A, B, and C are the params of the algorithm. Certain ones are much better than others and from those 5,3,1 is one of the easiest
;8,3,9 is also compact
;but 5,3,1 is smaller
;and those params happen to be the same ones Total used
;strotlog — 06/22/2022
;amoeba, is what you pasted the same as what IFB was trying to share here (404 error)? 
;Benox50 — 06/22/2022
;it doesnt look the same, hmmmm
;one I posted was his 16bit small, and the big 32bit one looked bigger than amoeba's,
;but I cant check so I could be wrong 
;but then good time to optimise:
;;;; Random number generator ;;;  Credits to Total
;org $808111
;    REP #$20                     ;Cause vanilla
;    LDA $05E5 : STA $3E          ;Use DP will never use, so no backup needs
;    ASL #2 : EOR $3E : STA $3E
;    LSR #5 : EOR $3E : STA $3E
;    ASL : EOR $3E
;    STA $05E5
;    RTL
;
;tho wont work coming in SEP #$10, but aww
;strotlog — 06/22/2022
;oh pasteOfCode always expires in 1 week huh 
;InsaneFirebat — 06/22/2022
;Sorry, I didn't check it before posting. I'm looking for it now
;I don't see the original anywhere but this should be the same code total provided.
;MenuRNG:
;; Generates new random number
;; 32-bit period (uses two 16-bit seeds)
;; Make sure ram_seed_X and ram_seed_Y is initialized to something other than zero
;{
;    LDA !ram_seed_X : ASL #5
;    EOR !ram_seed_X : STA $16
;
;    LDA !ram_seed_Y : STA !ram_seed_X
;
;    LDA $16 : LSR #3
;    EOR $16 : STA $16
;
;    LDA !ram_seed_Y : LSR
;    EOR !ram_seed_Y : EOR $16
;    STA !ram_seed_Y
;
;    ; return y (in a)
;    RTL    
;}
;
;MenuRNG2:
;; 16-bit period xorshift (uses only ram_seed_X)
;; Make sure ram_seed_X is not zero
;{
;    LDA !ram_seed_X
;    STA $16
;    ASL #2 : EOR $16 : STA $16
;    LSR #5 : EOR $16 : STA $16
;    ASL : EOR $16
;    STA !ram_seed_X
;    RTL
;}
;Benox50 — 06/22/2022
;look p much the same, tho shouldnt use $16 cause its too abused, mostly if youre making a big hack, should use a rare DP,
;and tring to backup the DP for safety with this routine was a nightmare lol, cause the way [A] must return etc.
;InsaneFirebat — 06/22/2022
;It's pretty safe for my use cases. The menu it runs in will have already demolished the first $20 or so bytes of DP

;================================================================================================



;     =====================================================================================================
;     =============================== KNOWN BUGS WITHOUT FIXES: ===========================================
;     =====================================================================================================

;Todo, investigate consequences of these fixes, as some of these might actually be bugs that players
;like/enjoy exploiting. Like does the below one fix kraid quick kill for ex?

;================================================================================================

;;; $DF34: Enemy shot - enemy $F07F (Shaktool) ;;;
{
; Bug: when an enemy dies and goes through its death animation, its enemy RAM is cleared,
; so the LDY always loads 0, meaning the other pieces aren't aren't set to delete

;================================================================================================

;$A7:B6E1 A9 00 01    LDA #$0100             ;\
;$A7:B6E4 AD AC 0F    LDA $0FAC  [$7E:0FAC]  ;} Typo (should be `Kraid instruction timer = 100h`)

;================================================================================================

;$80:87D3 A9 48       LDA #$48               ; >_<
;$80:87D5 9C 0A 21    STZ $210A  [$7E:210A]

;================================================================================================

;$A7:C55A AC 54 0E    LDY $0E54  [$7E:0E54]  ;\
;$A7:C55D BE 78 0F    LDX $0F78,y[$7E:0F78]  ;|
;$A7:C560 A9 4C 80    LDA #$804C             ;} Uhhh >_<; (enemy shot "=" RTL)
;$A7:C563 9F 32 00 A0 STA $A00032,x[$A0:E2F1];/

;================================================================================================

;$A9:95AE A9 16 00    LDA #$0016             ;\
;$A9:95B1 8F 4D 91 80 STA $80914D[$80:914D]  ;} Typo. Should be JSL for queue sound 16h, sound library 3, max queued sounds allowed = 6

;================================================================================================

;$A6:9B14 22 70 AD A0 JSL $A0AD70[$A0:AD70]
;$A6:9B18 2F FF FF 00 AND $00FFFF[$00:FFFF]
;$A6:9B1C D0 07       BNE $07    [$9B25]

;================================================================================================


;================================================================================================



;     =====================================================================================================
;     =============================== CODE THAT CAN BE OPTIMIZED: =========================================
;     =====================================================================================================















