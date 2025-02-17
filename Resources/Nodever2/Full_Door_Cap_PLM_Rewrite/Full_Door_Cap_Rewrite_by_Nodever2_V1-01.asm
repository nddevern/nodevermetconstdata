lorom

; June 10, 2022. Release v1.01
; Version history:
{
	; June 07, 2022 (v1.00): Initial release.
	; June 10, 2022 (v1.01): Fixed eye door HP, was 07, is now 03 like vanilla.
}
; Developed with xkas v0.06. Also tested with metconst asar.
; This is an ASM file by Nodever2. Please give credit if you use it, it is probably my highest effort patch release so far. Thanks to PJ's docs as always, and for JAM for the elevator vertical door display bugfix.
; Apologies in advance for how verbose this is, but my intent is for people of all skill levels to be able to understand and use this patch.
; If you already know what you're doing, feel free to start reading code and come back to the walls of text if you get stuck.
; This file also makes heavy use of collapsible curly braces, make sure you have a code editor such as notepad++ which can collapse their contents.
; Relevant: https://wiki.metroidconstruction.com/doku.php?id=super:expert_guides:asm_stylesheet
; If you ever have any questions or issues with this patch, please feel free to contact me. My discord username is Nodever2#1624.

; This patch completely rewrites all door caps in Super Metroid with the objective of making them MUCH easier to customize.
; Many door cap customizations which previously would have required a high amount of effort or tedium are now relatively easy.
; Even for advanced users, editing the instruction lists with this ASM file should be much easier than trying to do it from scratch,
; as they are now more readable and repeated ones use macros, so you'll only have to edit 1 instruction list for each door type you want to edit.

; Some values that are now extremely easy to tweak: Each door's opening/closing speeds, # of hits required to open, sfx values, and more. Repointing things is also easy.

; The patch is configured by default to make doors behave almost identically to vanilla Super Metroid. However, this patch does more than just reproduce vanilla
; functionality; some inconsistencies in vanilla are now fixed, such as some specific door types/orientations using different animation speeds, some door colors
; not having hit sounds, and grey doors opening when hit by power bombs but blue doors not doing so.
; In addition to fixing inconsistencies, arguably the biggest innovation this patch brings is that (by default) ALL DOORS ARE NONSOLID AS SOON AS THEY BEGIN TO OPEN.
; They remain solid while they are closing. Also, DOOR CLOSING/FLASHING ANIMATIONS CAN GENERALLY BE INTERRUPTED NOW WHEN THEY PREVIOUSLY SOMETIMES COULDN'T.
; For example, while a blue door is in its closing animation, you can shoot it to have it immediately start opening again; in vanilla, the door would have ignored your shot until it finished
; the closing animation. All colored doors would behave similarly in vanilla but can now be immediately shot even while closing, no matter how slowly you set the animation speed to.

; Of course, if you do not like these bundled changes, it is not too difficult to revert them to vanilla functionality, but with these in particular there is little reason to.

; The main things you want to edit are in the "DEFINES\PRIMARY TWEAKS" and "DEFINES\DATA LOCATIONS" sections,
; you can poke around the rest of the file if you're familiar with asm.

; Scope of this document: Blue/Red/Green/Yellow/Grey doors, BT door, Eye doors (Gadoras).
; Outside of scope: Any other PLM

;---Commonly used acronyms/abbreviations in this document:---
{
	; CLR: Abbreviation for "Color"/Type of a door. Valid door "colors":
	; (Note that for properties that are shared between YLW, GRN, and RED doors, "CLR" may be used directly to refer to them.)
		; YLW: "Yellow".
		; GRN: "Green".
		; RED: included for completeness' sake.
		; BLU: "Blue".
		; GRY: "Grey".
		; EYE: Refers to "Eye Doors" aka "Gadoras".
	
	; O: Abbreviation for "Orientation" of a door. Valid door "orientations":
		; H: "Horizontal" (i.e. a door that Samus travels horizontally through)
		; V: "Vertical:   (i.e. a door that Samus travels vertically through)
	
	; D: Abbreviation for the "Direction" that a door faces. Valid door "directions":
		; L: "Left"  (i.e. a door that Samus travels through FROM LEFT TO RIGHT)
		; R: "Right" (i.e. a door that Samus travels through FROM RIGHT TO LEFT)
		; U: "Up"    (i.e. a door that Samus travels through FROM ABOVE TO BELOW)
		; D" "Down"  (i.e. a door that Samus travels through FROM BELOW TO ABOVE)
	
	; "Loc": Abbreviation for "Location" regarding locations of writing data.
	; "Inst"/"Insts": Abbreviation for "Instruction"/"Instructions" regarding PLM instructions.
	
	; Animation Frame Number Disambiguation:
		; Animation frame numbers in this document are generally based on a door's CLOSING ANIMATION (for non-eye doors).
		; Frame 1 is the first frame of a door's closing animation.
		; Frame 4 is a closed door.
}

;---Regarding information printed by this ASM to the console at assemble time:---
{
	; This ASM file rewrites doors within the same space as vanilla in a way that uses less space in several regions.
	; This patch reports the beginning and end addresses of newly generated freespace regions in $84, which can safely be used to store other custom data.
	; This patch also has warnpc's setup in the event that the available space is exceeded (not possible without modifying this patch's ASM).
	; If a warnpc is printed, assume that the beginning and end addresses of available space are invalid.
	
	; This ASM also prints the location of every PLM entry that is written to ROM. By default, every one of them are written in their vanilla locations for compatibility reasons.
	; However, they can easily be repointed if you have the need to do so. In that case, you will need to configure your editor's PLM data folder accordingly.
}

; Scroll past the "Defines" section for information on data structures used by code in this document, including some new ones.

;=======================DEFINES=======================
{
	; THIS IS THE MAIN THING YOU WILL WANT TO EDIT IN THIS DOCUMENT.
	; A lot of these defines are used dynamically by macros, so I strongly recommend against renaming them.
	
	;=====PRIMARY TWEAKS=====
	{
		;---FRAME DELAYS---
		{
			; in other words, these are the number of game frames between door animation frames
			;  (the higher the number, the slower the animation. Minimum value for frame delays is 0001.)
			; these can all be safely changed.
			
			!BLUOpenDelay    = $0006 ; vanilla is $0006. Blue door opening anim.
			!BLUClosDelay    = $0002 ; vanilla is $0002. Blue door closing anim.
			!YLWOpenDelay    = $0006 ; vanilla is $0006 and sometimes 0004... wtf nintendo. Yellow door opening anim.
			!YLWClosDelay    = $0002 ; vanilla is $0002. Yellow door closing anim.
			!GRNOpenDelay    = $0006 ; vanilla is $0006. Green door opening anim.
			!GRNClosDelay    = $0002 ; vanilla is $0002. Green door closing anim.
			!REDOpenDelay    = $0006 ; vanilla is $0006. Red door opening anim.
			!REDClosDelay    = $0002 ; vanilla is $0002. Red door closing anim.
			!GRYOpenDelay    = $0006 ; vanilla is $0004 <- so much vanilla inconsistency. Grey door opening anim.
			!GRYClosDelay    = $0002 ; vanilla is $0002. Grey door closing anim.
			
			!TorizoClosDelay = $0002 ; vanilla is $0002. Torizo door closing anim.
			
			!DHitCLRDelay    = $0004 ; vanilla $0004. Time that the door color is shown in missile door hit animation (i.e. animation where door is hit but has greater than zero HP remaining).
			!DHitBLUDelay    = $0003 ; vanilla $0003. Time that the color blue is shown in missile door hit animation.
			!FlashGRYGDelay  = $0004 ; vanilla $0004. The time that grey doors are grey in their unlocked flashing animation.
			!FlashGRYBDelay  = $0003 ; vanilla $0003. The time that grey doors are blue in their unlocked flashing animation.
			
			!EDeadEYEDelay   = $0003 ; vanilla $0003. The time that an eye door is shown when flashing during it's death animation.
			!EDeadBLUDelay   = $0004 ; vanilla $0004. The time that a blue door is shown during an eye door's death animation.
			
			!TorizoDoorDelay = $0028 ; vanilla $0028. The delay before torizo door closes after you get bombs.
		}
		
		;---SFX VALUES---
		{
			; These can be safely changed.
			; This first set of defines is the sound effect index for the given sound library.
			!OpenSound   = $07 ; vanilla $07. The SFX that plays when opening a door.
			!ClosSound   = $08 ; vanilla $08. The SFX that plays when a door is closing.
			!DHitSound   = $09 ; vanilla $09. SFX for hitting but not opening a door.
			!EyeHitSound = $09 ; vanilla $09. The SFX that plays when hitting but not killing an eye door.
			
			; Pointers to sound library calling instructions in $84. These use the above 3 defines as arguments.
			; These dictate which sound library will be used for each sound effect.
			!InstOpenSFX   = $8C19 ; vanilla $8C19. Sound library call instruction for door open SFX.
			!InstClosSFX   = $8C19 ; vanilla $8C19. Sound library call instruction for door close SFX.
			!InstDHitSFX   = $8C19 ; vanilla $8C19. Sound library call instruction for door hit SFX (when not opening a door).
			!InstEyeHitSFX = $8C10 ; vanilla $8C10. Sound library call instruction for eye door hit SFX.
		}
		
		;---DOOR HEALTH VALUES---
		{
			; These can all be safely changed. Valid values are from 01-7F.
			; Each of these refers to the number of hits from the proper weapon that are required to open each door.
			!YLWHP = $01 ; vanilla $01. Changing this isn't very effective since PBs hit it multiple times.
			!GRNHP = $01 ; vanilla $01
			!REDHP = $05 ; vanilla $05
			!GRYHP = $01 ; vanilla $01, also applies to torizo door. Hitting grey doors with any weapon (except power bombs if the below define is set to -2) will damage the grey door.
			!EYEHP = $03 ; vanilla $03
			
			!SuperMissileRedDoorDamage = #$0005 ; Amount of HP that is subtracted from a red door when hit by a super missile. Set this value equal to REDHP to make them open in one hit.
			!SuperMissileEyeDoorDamage = #$0003 ; Amount of HP that is subtracted from an eye door when hit by a super missile.
			
			!BlueDoorsReactToPBs = -2 ; SET THIS TO 0 IF YOU WANT POWER BOMBS TO OPEN BLUE/GREY DOORS. SET TO -2 OTHERWISE.
			                          ; (also applies to dead flashing eye doors)
		}
		
		;---DOOR TILES---
		{
			; IF YOU MOVE DOOR TILES AROUND IN THE TILETABLE, YOU WILL NEED TO EDIT THE DEFINES IN THIS SECTION.
			; This tells the asm where to read graphics tiles from.
			
			; These are the Tile Table index (Tilemap Tile Number in SMART's Tileset Editor) of the "edge tile" or outer tile of the door cap.
			; Needs to be specified for both horizontal and vertical doors.
			!YLWHDoorTile   = $0000 ; vanilla $0000. edge tile of YLW horizontal door.
			!GRNHDoorTile   = $0004 ; vanilla $0004. edge tile of GRN horizontal door.
			!REDHDoorTile   = $0008 ; vanilla $0008. edge tile of RED horizontal door.
			!BLUHDoorTile   = $000C ; vanilla $000C. edge tile of BLU horizontal door.
			
			!YLWVDoorTile   = $0011 ; vanilla $0011. edge tile of YLW vertical door.
			!GRNVDoorTile   = $0015 ; vanilla $0015. edge tile of GRN vertical door.
			!REDVDoorTile   = $0019 ; vanilla $0019. edge tile of RED vertical door.
			!BLUVDoorTile   = $001D ; vanilla $001D. edge tile of BLU vertical door.
			
			!NoCapHDoorTile = $0082 ; vanilla $0082. edge tile of door with no cap.
			!NoCapVDoorTile = $0084 ; vanilla $0084. edge tile of door with no cap.
			
			!GRYHDoorTile   = $00AE ; vanilla $00AE. edge tile of GRY horizontal door.
			!GRYVDoorTile   = $00B3 ; vanilla $00B3. edge tile of GRY vertical   door.
			
			; These are the distance between the two tiles WITHIN THE SAME FRAME OF ANIMATION for each orientation of doors (horizontal / vertical doors).
			; The ASM assumes that all door colors use the same distances here.
			; Specifically this define needs to be set to be equal to (tile 2's TTB position - tile 1's TTB position)
			!HDoorTileDist = $0020 ; vanilla $0020.
			!VDoorTileDist = $FFFF ; vanilla $FFFF (i.e. negative 1).
			
			; These are the distance between tile 1 of each animation frame of each door color.
			; Remember that frame 4 is a closed door and frame 1 is a door that is just starting to close.
			; This asm requires that all colored doors have the same offsets for this section.
			!DoorCLRHFrame4Offset = $00 ; vanilla $00
			!DoorCLRHFrame3Offset = $01 ; vanilla $01
			!DoorCLRHFrame2Offset = $02 ; vanilla $02
			!DoorCLRHFrame1Offset = $03 ; vanilla $03
			
			!DoorCLRVFrame4Offset = $00 ; vanilla $00
			!DoorCLRVFrame3Offset = $20 ; vanilla $20
			!DoorCLRVFrame2Offset = $02 ; vanilla $02
			!DoorCLRVFrame1Offset = $22 ; vanilla $22
			
			!DoorBLUHFrame4Offset = $00 ; vanilla $00
			!DoorBLUHFrame3Offset = $01 ; vanilla $01
			!DoorBLUHFrame2Offset = $02 ; vanilla $02
			!DoorBLUHFrame1Offset = $03 ; vanilla $03
			
			!DoorBLUVFrame4Offset = $00 ; vanilla $00
			!DoorBLUVFrame3Offset = $20 ; vanilla $20
			!DoorBLUVFrame2Offset = $02 ; vanilla $02
			!DoorBLUVFrame1Offset = $22 ; vanilla $22
			
			!DoorGRYHFrame4Offset = $00 ; vanilla $00
			!DoorGRYHFrame3Offset = $01 ; vanilla $01
			!DoorGRYHFrame2Offset = $02 ; vanilla $02
			!DoorGRYHFrame1Offset = $03 ; vanilla $03
			
			!DoorGRYVFrame4Offset = $00 ; vanilla $00
			!DoorGRYVFrame3Offset = $20 ; vanilla $20
			!DoorGRYVFrame2Offset = $02 ; vanilla $02
			!DoorGRYVFrame1Offset = $22 ; vanilla $22
		}
		
	}
	
	;=====DATA LOCATIONS (YOU CAN REPOINT ANY OF THESE!!!)=====
	{
		; Locations data in this file is written. By default they are generally in their vanilla locations.
		; By default this patch does not use any space at all that is freespace in vanilla.
		; There are a couple locations where data is written by this patch which are specified in the below section instead due to the data originally at that location no longer being used.
		
		!DrawInstsLoc         = $84A677 ; Location where many PLM draw instructions used to be written for blue and colored doors. These are no longer used and much of this space can now be used for other data.
		!EyeDoorDrawInstsLoc  = $849BF7 ; Location of PLM draw instructions for eye doors
		
		!PLMEntriesLoc        = $84C842 ; Main group of PLM entries (CLR, BLU, GRY)
		!EyeDoorPLMEntriesLoc = $84DB48 ; Eye door PLM entries
		!TorizoPLMEntryLoc    = $84BAF4 ; Only BT (Bomb Torizo) door PLM entry location
		; Reminder, this asm prints the location of each PLM entry so that you can set up your PLM entries in SMART or SMILE. By default no extra configuration is needed though.
		
		!GRYInstListLoc       = $84BE59 ; Location where most of this patch's new data goes. Starting at the beginning of grey door instruction lists and going all the way through to the end of the blue door instruction lists.
		
		!EyeDoorInstListLoc   = $84D81E ; Location where eye door instruction lists are written.
		
		!TorizoDoorCloseInstListLoc = $84BA4C ; Bomb Torizo grey door closing anim inst list location. This instruction list flows into the normal grey door instruction list,
		                                      ; and the BT door is otherwise identical to a normal grey door.
	}
	
	;=====DEFINES YOU SHOULDN'T TOUCH UNLESS YOU KNOW WHAT YOU'RE DOING=====
	{
		; These are indices into each door's DoorSpeedTable, used as an argument to our new door draw instruction. See InstDrawDoor.
		!OpenSpeedIndex = $00 ; index of all door opening speeds
		!ClosSpeedIndex = $01 ; index of all door closing speeds
		!HitBSpeedIndex = $02 ; index of colored door blue anim delay when flashing when hit
		!HitCSpeedIndex = $03 ; index of colored door color anim delay when flashing when hit
		!GryBSpeedIndex = $02 ; index of grey door blue anim delay
		!GryGSpeedIndex = $03 ; index of grey door grey anim delay
		!TorizoDSpIndex = $04 ; index of torizo door wait time
		!TorizoClosSpeedIndex = $05 ; index of torizo door close speed
		!EndAnimSpIndex = $0F ; always results in a frame delay of !EndAnimDelay, specified by draw door InstDrawDoor.
		
		!EndAnimDelay = $0001 ; vanilla 0001 or 005E. A frame delay. No reason not to have it 0001, this is the time the final frame of each animation is drawn for nearly every PLM animation
		                      ;  (and that frame stays drawn after the animation is over)
		
		!EyeDoorLProjectileArg = $0000
		!EyeDoorRProjectileArg = $0014
		
		!EyeDoorLSweatArg = $0000
		!EyeDoorRSweatArg = $0004
		
		; to get the actual index, load these into A then XBA.
		!DoorSpeedsTableGRYIndex = $0000
		!DoorSpeedsTableYLWIndex = $0100
		!DoorSpeedsTableGRNIndex = $0200
		!DoorSpeedsTableREDIndex = $0300
		!DoorSpeedsTableBLUIndex = $0400
		!DoorSpeedsTableEYEIndex = $0500
		
		; Pointers to PLM instructions in $84, given names for readability.
		!InstDelete                    = $86BC ; no args
		!InstSleep                     = $86B4 ; no args
		!InstSetBTS                    = $8AF1 ; args: 1 byte BTS value to set current block to
		!InstGoto                      = $8724 ; args: 2 byte pointer to inst to goto
		!InstSetLink                   = $8A24 ; args: 2 byte pointer to link inst
		!InstSetPre                    = $86C1 ; args: 2 byte pointer to pre-inst
		!InstGotoIfNotHaveBombs        = $BA6F ; args: 2 byte pointer to inst to goto
		!InstClearPre                  = $86CA ; no args
		!InstGotoIfSamusDistance       = $8D41 ; args: 1 byte column distance samus must be within, 1 byte row distance samus must be within
		!InstShootEyeDoorProj          = $D77A ; args: 2 byte argument for enemy projectile
		!InstSpawn2EyeDoorSmoke        = $D79F ; no args
		!InstSpawnEyeDoorSmoke         = $D7B6 ; no args
		!InstSpawnEyeDoorSweat         = $D790 ; args: 2 byte argument for enemy projectile
		!InstSetTimer1ByteArg          = $874E ; args: 1 byte to set !RAMPLMTimers,x to
		!InstDecTimerAndGotoIfNonzero  = $873F ; args: 2 byte pointer to inst to goto
		!InstMovePLMUpAndMakeRBlueDoor = $D7C3 ; no args
		!InstMovePLMUpAndMakeLBlueDoor = $D7DA ; no args
		
		; WARNING: THESE (below) INSTRUCTIONS ARE NOW OVERWRITTEN, DO NOT USE.
		{
			;!InstGotoIfRoomArg = $8A72 ; args: 2 byte pointer to inst to goto
			;  (overwritten by !GotoLinkIfShotGRY)
		}
		
		; other routines which are newly unused and can safely be overwritten later
		{
			!InstDoorHit = $8A91 ; args: 1 byte max door hits; 2 byte address to go to if that many hits have been reached
			;  (overwritten by nothing)
			
			!InstSetGRYDoorPreInst = $BE3F ; no args
			;  (overwritten by nothing)
			
			!SetupGRYDoorPLM = $C794
			;  (overwritten by nothing)
		}
		
		; Pointers to pre-instructions in $84. Used by macros.
		!GotoLinkIfShotYLW     = $BD26
		!GotoLinkIfShotGRN     = $BD88
		!GotoLinkIfShotRED     = $BD50     ; OUR PATCH WRITES DATA AT THIS LOCATION, WE RE-WROTE IT IN PLACE. You can repoint this if you want.
		!GotoLinkIfShotEYE     = $BD50
		!GotoLinkIfShotGRY     = $8A72+$02 ; OUR PATCH WRITES DATA AT THIS LOCATION, WE RE-WROTE IT OVER TOP OF !InstGotoIfRoomArg. You can repoint this if you want. NOTE THAT OUR PATCH STARTS WRITING DATA AT $848A72, IGNORE THE +$02.
		!GotoLinkIfRoomArgDoor = $D753     ; this one also clears pre instruction if room argument door is set
		
		; Grey door pre-instructions
		!GotoLinkIfBossDead      = $BDD4
		!GotoLinkIfMiniBossDead  = $BDE3
		!GotoLinkIfTorizoDead    = $BDF2
		!GotoLinkIfEnemiesDead   = $BE01
		!GotoLinkNever           = $BE1C
		!GotoLinkIfTourianStatue = $BE1F
		!GotoLinkIfAnimals       = $BE30
		
		; Vanilla Functions
		!FuncProcessPLMDrawInst                 = $861E
		!FuncLCalcPLMBlockCoords                = $848290
		!FuncDrawPLM                            = $8DAA
		!FuncWriteLevelDataBlockTypeAndBTS      = $82B4
		!FuncLBitIndexToByteIndexAndBitmask     = $80818E ; stores result in !RAMBitIndexToByteIndexAndBitmaskResult
		!FuncLQueueSoundLib2MaxSounds6          = $8090CB
		
		; Vanilla setup asm pointers for door PLMs.
		!SetupNormalColoredDoor = $C7B1
		!SetupDeactivatePLM     = $B3C1
		!SetupEyeDoorEye        = $DA8C
		!SetupEyeDoorEdge       = $DAB9
		
		; Instruction Lists
		!InstListDelete = $AAE3
		
		;---TILE TYPES (for PLM draw instructions)---
		; The most significant nybble of these defines are the only ones which should be modified.
		; This is a tile type to write with our new InstDrawDoor, so we don't have to have hardcoded tile types in our
		; draw instructions.
		
		!TTairbyte   = $00 ; vanilla 00 (air)
		!TTshotbyte  = $C0 ; vanilla C0 (shot)
		!TTsolidbyte = $80 ; vanilla 80 (solid)
		!TTcpyHbyte  = $50 ; vanilla 50 (H-copy)
		!TTcpyVbyte  = $D0 ; vanilla D0 (V-copy)
		
		; same thing but 1 word instead of 1 byte
		!TTcpyH  = $5000 ;vanilla 5000 (H-copy)
		!TTcpyV  = $D000 ;vanilla D000 (V-copy)
		
		;---PLM RAM values---
		{
			; From https://patrickjohnston.org/ASM/ROM%20data/Super%20Metroid/RAM%20map.asm
			
			!RAMPLMEnableFlag       = $1C23 ; PLM flag. Set to negative to enable PLMs.
			!RAMPLMDrawTilemapIndex = $1C25 ; PLM draw tilemap index (into $7E:C6C8)
			!RAMPLMID               = $1C27 ; PLM ID
			!RAMPLMXBlock           = $1C29 ; PLM X block (calculated by $84:8290)
			!RAMPLMYBlock           = $1C2B ; PLM Y block (calculated by $84:8290)
			!RAMPLMGFXIndex         = $1C2D ; PLM item GFX index (into $1C2F and some tables in $84:8764)
			!RAMPLMItemGFXPtrs      = $1C2F ; $1C2F..36: Item PLM GFX pointers (bank $89, 100h bytes)
			  ; Note, the above is not per-PLM
			!RAMPLMIDs              = $1C37 ; $1C37..86: PLM IDs
			!RAMPLMBlockIndices     = $1C87 ; $1C87..D6: PLM block indices (into $7F:0002)
			!RAMPLMPreInsts         = $1CD7 ; $1CD7..1D26: PLM pre-instructions
			!RAMPLMInstListPointers = $1D27 ; $1D27..76: PLM instruction list pointers
			!RAMPLMTimers           = $1D77 ; $1D77..C6: PLM timers (according to instructions $873F, $8747, $874E, $875A)
			{
				; Used as shot status by doors (!) and Mother Brain's glass
				
				; Used as advancement stage ($84:B876 table index) by lavaquake PLM ($84:B846)
				; Used as trigger flag by gates and item collision detection
			}
			!RAMPLMRoomArgs         = $1DC7 ; $1DC7..1E16: PLM room arguments
			{
				; For new doors, at first contains grey door type, respawn flag, flips, and door ID (See "RELEVANT DATA STRUCTURES" section). After setup only contains door ID and respawn flag.
			
				; Used as shot counter by Mother Brain's glass ($84:D1E6)
				; Used as door hit counter by Dragon cannon with shield ($84:DB64)
			}
			!RAMPLMVars             = $1E17 ; $1E17..66: PLM variables
			{
				; Base door tile (new colored doors), includes X and Y flips extracted from the room argument.
				
				; Respawn block (drawn by $84:8B17)
				; Scroll PLM triggered flag ($84:B393)
				; Samus X position for Brinstar plants (used by $84:AC89, set by $84:B0DC/B113)
				; Grey door type ($84:BE3F) (NOTE, IF I REWRITE GREY DOORS, I WILL MAKE THE GREY DOOR SETUP DO THIS INSTEAD)
				; Draygon turret damaged flag address ($84:DB8E)
			}
			; $1E67: Custom draw instruction - number of blocks (must be 1)
			;   (ALSO USED AS A RANDOM TEMP VAR in my new draw instr)
			; $1E69: Custom draw instruction - PLM block
			;   (ALSO USED AS A RANDOM TEMP VAR in my new draw instr)
			; $1E6B: Custom draw instruction - zero-terminator
			!RAMPLMInstTimers       = $7EDE1C ; $7EDE1C..6B: PLM instruction timers
			!RAMPLMDrawInstPtrs     = $7EDE6C ; $7EDE6C..BB: PLM draw instruction pointers
			!RAMPLMLinkInstrs       = $7EDEBC ; $7EDEBC..DF0B: PLM link instructions (instructions $8A24, $8A2E, $8A3A)
			!RAMPLMVars2            = $7EDF0C ; $7EDF0C..5B: PLM variables
			{
				;For new colored doors:
				; High byte is index into DoorSpeedsTables to use for this door
				; Low byte is remaining door HP
				
				;PLM item GFX index for item PLMs ($84:831A)
				;Samus Y position for Brinstar plants (used by $84:AC89, set by $84:B0DC/B113)
			}
			
			!DoorBitflagArr         = $7ED8B0 ; Opened door bit array. $C6..EF are unused. See "Door PLMs.asm"
			
			!RAMDPCustomPLMDrawInstructionLocation = $26 ; We will be using $0C bytes here (including terminator) temporarily.
		}
		
		;---Other RAM values---
		{
			!ProjectileIndex        = $0DDE
			!ProjectileTypes        = $0C18
			!LevelDataL1Arr         = $7F0002
			!RAMBitIndexToByteIndexAndBitmaskResult = $05E7 ; result of !FuncLBitIndexToByteIndexAndBitmask
		}
		
	}
	
}

;===============RELEVANT DATA STRUCTURES==============
{
	; New door PLM room arg format:
	{
		; ryxggg-ddddddddd
		;  r: Door cap will respawn if this bit is set
		;  y: Flip door graphics vertically.
		;  x: Flip door graphics horizontally.
		;  g: Index of grey door pre instruction to use. Should be zero for all non-grey doors. vanilla options are 0-6.
		;  -: Should be zero.
		;  d: Bit index into door bit array to determine if door cap has already been opened.
	}
	
	; New door draw instruction ("InstDrawDoor") arguments:
	{
		; To use, include the following into your PLM instruction list:
		; dw InstDrawDoor<O> : db XX, TS
		
		; Arguments disambiguation:
		; <O>: Should be H or V; this is part of the name of the instruction label. Orientation of the door, which determines which entry code into the new door draw instruction to use.
		; XX (8 bits): The tile offset from the door PLM's base door tile to use to calculate which frame of animation to draw.
		; T  (4 bits): The tile type that the drawn door should use. Note that this only affects the top leftmost tile of the door, the rest are always copy tiles.
		; S  (4 bits): Speed Index: Index into the door's DoorSpeedTable for what speed value to use.
		
		; Example: A red door has the following PLM instruction:
		; dw InstDrawDoorH : db !DoorCLRHFrame3Offset, !TTairbyte|!OpenSpeedIndex
		; Most of this should be self-explanatory based on the disambiguation above, just note that we are logical OR'ing the
		; !TTairbyte and !OpenSpeedIndex at assemble time to input the T and S arguments. So only the highest 4 bits of !TTairbyte and only the lowest 4 bits of !OpenSpeedIndex should ever be nonzero.
	}

	; Vanilla PLM draw instruction format: (only describing parts that are relevant here)
	{
		; draw instruction is a list of:
		
		;  nnnn       ; Number of blocks
		;  bbbb [...] ; Blocks
		;  xx yy      ; X and Y offsets from origin to start drawing from
		
		; terminated by xx yy = 00 00.
	}
	
	; Vanilla Level data format:
	{
		;  _______ Block type
		; |    ___ Y flip
		; |   | __ X flip
		; |   || _ Block number (Tilemap Tile Number in SMART tileset editor)
		; |   |||
		; ttttyxnnnnnnnnnn
	}
	
	; Vanilla Block types:
	{
		; 0: Air
		; 1: Slope
		; 2: Air (no X-ray)
		; 3: Treadmill
		; 4: Air (shot)
		; 5: H-Copy
		; 6: Unused?
		; 7: Air (bomb)
		; 8: Solid
		; 9: Door
		; A: Spike
		; B: Crumble
		; C: Shot
		; D: V-Copy
		; E: Grapple
		; F: Bomb
	}
}

;========================MACROS=======================
{
	
	; Apparently you can't tab macro definitions in xkas? nice.
	
	; These macros generate assembly code for the new door instruction lists, setup ASM, and PLM entries.
	; If you modify these it is expected that you know what you're doing. With that being said, these should be far easier to edit
	; than editing the vanilla instruction lists should be, since it is all already converted to symbolic ASM and use less space than vanilla
	; (leaving extra space for you to add things. If you add to much and run out of space, the aforementioned warnpc's in this document will alert you.)
	
	;=====COLORED DOORS=====
	{
		; ColoredDoorSetup: Generates setup ASM for a colored door.
		; NOTE: This setup ASM determines whether the door is flipped in X or Y directions based on room arg.
		; Arguments:
		;    CLR: The color of the door. Valid options are YLW, RED, GRN.
macro ColoredDoorSetup(CLR)
{
	Door<CLR>InvertedHSetup:
		JSR InvertRoomArgH ; invert the door's horizontal flip bit in room arg
		
	Door<CLR>NormalHSetup:
		TYX ; PLM index is in both Y and X now
		LDA #!<CLR>HDoorTile : STA !RAMPLMVars,x            ; set door tile
		LDA #DoorCLRHHit : STA !RAMPLMLinkInstrs,x          ; set door link instruction
		BRA ?mainclrsetup
		
	Door<CLR>InvertedVSetup:
		JSR InvertRoomArgV ; invert the door's vertical flip bit in room arg
		
	Door<CLR>NormalVSetup:
		JSR InvertRoomArgH ; (extra inversion required by vertical doors) invert the door's horizontal flip bit in room arg
		TYX
		LDA #!<CLR>VDoorTile : STA !RAMPLMVars,x            ; set door tile	
		LDA #DoorCLRVHit : STA !RAMPLMLinkInstrs,x          ; set door link instruction
		
	?mainclrsetup:
		LDA #$0000+!<CLR>HP                                 ; set door HP
		ORA #!DoorSpeedsTable<CLR>Index : STA !RAMPLMVars2,x; set door speeds table index
		LDA #!GotoLinkIfShot<CLR> : STA !RAMPLMPreInsts,x   ; set door pre-instruction
		JMP SharedColoredDoorSetup
}
endmacro
		
		; ColoredDoorInstList: Generates instruction list for a colored door.
		; Arguments:
		;    O: The orientation of the door. Valid options are H, V.
macro ColoredDoorInstList(O)
{
	; Instruction List - door closing animation
	DoorCLR<O>Close:
		dw InstDrawNoCapDoor<O> : db $00, !TTshotbyte|!EndAnimSpIndex ; this shows up for more than 1 frame in actuality because door transitions run PLM handler for 1 frame
		dw !InstClosSFX : db !ClosSound
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame1Offset, !TTshotbyte|!ClosSpeedIndex
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame2Offset, !TTshotbyte|!ClosSpeedIndex
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame3Offset, !TTshotbyte|!ClosSpeedIndex
		
	; Instruction List - main, includes door opening animation
	DoorCLR<O>Main:
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame4Offset, !TTshotbyte|!EndAnimSpIndex
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame4Offset, !TTshotbyte|!EndAnimSpIndex ; draw it again, thanks JAM for the "Vertical doors after elevator" fix https://forum.metroidconstruction.com/index.php/topic,145.msg4812.html#msg4812
	?sleep:
		dw !InstSleep
	DoorCLR<O>Hit:
		dw InstNewDoorHit : dw ?open ; set room argument door and goto ?open if door HP is zero
		dw !InstDHitSFX : db !DHitSound
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame4Offset, !TTshotbyte|!HitBSpeedIndex
		dw InstDrawDoor<O>    : db !DoorCLR<O>Frame4Offset, !TTshotbyte|!HitCSpeedIndex
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame4Offset, !TTshotbyte|!HitBSpeedIndex
		dw InstDrawDoor<O>    : db !DoorCLR<O>Frame4Offset, !TTshotbyte|!HitCSpeedIndex
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame4Offset, !TTshotbyte|!HitBSpeedIndex
		dw InstDrawDoor<O>    : db !DoorCLR<O>Frame4Offset, !TTshotbyte|!HitCSpeedIndex
		dw !InstGoto, ?sleep
	?open:
		dw !InstOpenSFX : db !OpenSound
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame3Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame2Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawDoor<O> : db !DoorCLR<O>Frame1Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawNoCapDoor<O> : db $00, !TTairbyte|!EndAnimSpIndex
		dw !InstDelete
}
endmacro
		
		; ColorDoorPLMEntry: Generates a PLM entry for a colored door.
		; Arguments:
		;    CLR: The color of the door. Valid options are YLW, RED, GRN.
		;    O: The orientation of the door. Valid options are H, V.
		;    I: Whether or not the door is inverted (i.e. flipped). Valid options are Normal, Inverted.
macro ColorDoorPLMEntry(CLR, O, I)
{
	print "PLM Entry - <CLR> door facing <O> at ", pc
	dw Door<CLR><I><O>Setup, DoorCLR<O>Main, DoorCLR<O>Close
}
endmacro
		
		; AllColorDoorPLMEntries: Generates four PLM entries for a given colored door color.
		; Arguments:
		;    CLR: The color of the door. Valid options are YLW, RED, GRN.
macro AllColorDoorPLMEntries(CLR)
{
	%ColorDoorPLMEntry(<CLR>, H, Normal)
	%ColorDoorPLMEntry(<CLR>, H, Inverted)
	%ColorDoorPLMEntry(<CLR>, V, Normal)
	%ColorDoorPLMEntry(<CLR>, V, Inverted)
}
endmacro
	}
	
	;=====GREY DOORS=====
	{
		; GreyDoorSetup: Generates setup ASM for a grey door.
		; NOTE: This setup ASM determines whether the door is flipped in X or Y directions based on room arg.
		; This doesn't exactly need to be a macro since it's only used once but it is for consistency's sake.
		; Differences from colored door macro: link instruction and pre instruction setting code
macro GreyDoorSetup()
{
	DoorGRYInvertedHSetup:
		JSR InvertRoomArgH
		
	DoorGRYNormalHSetup:
		TYX
		LDA #!GRYHDoorTile : STA !RAMPLMVars,x                 ; set door tile
		LDA #DoorGRYHUnlockedClosing : STA !RAMPLMLinkInstrs,x ; set door link instruction
		BRA ?maingrysetup
		
	DoorGRYInvertedVSetup:
		JSR InvertRoomArgV
		
	DoorGRYNormalVSetup:
		JSR InvertRoomArgH
		TYX
		LDA #!GRYVDoorTile : STA !RAMPLMVars,x                 ; set door tile
		LDA #DoorGRYVUnlockedClosing : STA !RAMPLMLinkInstrs,x ; set door link instruction
		
	?maingrysetup:
		LDA #$0000+!GRYHP                                      ; set door HP
		ORA #!DoorSpeedsTableGRYIndex : STA !RAMPLMVars2,x     ; set door speeds table index
		JSR SetGreyDoorPreInst                                 ; set grey door pre instruction
		JMP SharedColoredDoorSetup
}
endmacro
		
		; GreyDoorInstList: Generates instruction list for a grey door.
		; Arguments:
		;    O: The orientation of the door. Valid options are H, V.
macro GreyDoorInstList(O)
{
	; Instruction list - unlocked grey door closing animation (allows samus to shoot to open)
	; We immediately jump here if the grey door unlocks at any time during the normal closing animation
	DoorGRY<O>UnlockedClosing:
		dw !InstSetLink, ?hit
		dw !InstSetPre, !GotoLinkIfShotGRY
		dw InstDrawNoCapDoor<O> : db $00, !TTshotbyte|!EndAnimSpIndex;this shows up for more than 1 frame in actuality because door transitions run PLM handler for 1 frame
		dw !InstClosSFX : db !ClosSound
		dw InstDrawDoor<O>    : db !DoorGRY<O>Frame1Offset, !TTshotbyte|!ClosSpeedIndex
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame2Offset, !TTshotbyte|!ClosSpeedIndex
		dw InstDrawDoor<O>    : db !DoorGRY<O>Frame3Offset, !TTshotbyte|!ClosSpeedIndex
		dw !InstGoto, ?flash

	; Instruction List - grey door closing animation
	DoorGRY<O>Close:
		dw InstDrawNoCapDoor<O> : db $00, !TTsolidbyte|!EndAnimSpIndex;this shows up for more than 1 frame in actuality because door transitions run PLM handler for 1 frame
		dw !InstClosSFX : db !ClosSound
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame1Offset, !TTsolidbyte|!ClosSpeedIndex
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame2Offset, !TTsolidbyte|!ClosSpeedIndex
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame3Offset, !TTsolidbyte|!ClosSpeedIndex
	
	; Instruction List - main, includes door opening animation
	DoorGRY<O>Main:
		dw !InstSetLink, DoorGRY<O>Unlock
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame4Offset, !TTsolidbyte|!EndAnimSpIndex
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame4Offset, !TTsolidbyte|!EndAnimSpIndex
		dw !InstSleep
	DoorGRY<O>Unlock:
		dw !InstSetLink, ?hit
		dw !InstSetPre, !GotoLinkIfShotGRY
	?flash:
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame4Offset, !TTshotbyte|!GryBSpeedIndex
		dw InstDrawDoor<O>    : db !DoorGRY<O>Frame4Offset, !TTshotbyte|!GryGSpeedIndex
		dw !InstGoto, ?flash
	?hit:
		dw InstNewDoorHit : dw ?open ; set room argument door and goto ?open if door HP is zero
		dw !InstDHitSFX : db !DHitSound
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame4Offset, !TTshotbyte|!GryBSpeedIndex
		dw !InstGoto, ?flash
	?open:
		dw !InstOpenSFX : db !OpenSound
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame3Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame2Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawDoor<O> : db !DoorGRY<O>Frame1Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawNoCapDoor<O> : db $00, !TTairbyte|!EndAnimSpIndex
		dw !InstDelete
}
endmacro
		
		; GreyDoorPLMEntry: Generates a PLM entry for a grey door.
		; Arguments:
		;    O: The orientation of the door. Valid options are H, V.
		;    I: Whether or not the door is inverted (i.e. flipped). Valid options are Normal, Inverted.
macro GreyDoorPLMEntry(O, I)
{
	print "PLM Entry - GRY door facing <O> at ", pc
	dw DoorGRY<I><O>Setup, DoorGRY<O>Main, DoorGRY<O>Close
}
endmacro
		
		; AllGreyDoorPLMEntries: Generates four PLM entries for grey doors.
macro AllGreyDoorPLMEntries()
{
	%GreyDoorPLMEntry(H, Normal);left
	%GreyDoorPLMEntry(H, Inverted);right
	%GreyDoorPLMEntry(V, Normal)
	%GreyDoorPLMEntry(V, Inverted)
}
endmacro
	}
	
	;=====BLUE DOORS=====
	{
		; BlueDoorSetup: Generates setup ASM for blue doors.
		; NOTE: This setup ASM determines whether the door is flipped in X or Y directions based on the tile flips in the level data.
macro BlueDoorSetup()
{
	DoorBLUHClosedSetup:  ; this PLM spawns as a shot reaction
		JSR BLUDoorCheckPB : BCS ?ret
		
	DoorBLUHClosingSetup: ; this PLM spawns when you exit a blue door
		TYX
		LDA #!BLUHDoorTile : STA !RAMPLMVars,x ; set door tile
		BRA ?mainblusetup
		
	DoorBLUVClosedSetup:  ; this PLM spawns as a shot reaction
		JSR BLUDoorCheckPB : BCS ?ret
		
	DoorBLUVClosingSetup: ; this PLM spawns when you exit a blue door
		TYX
		LDA #!BLUVDoorTile : STA !RAMPLMVars,x ; set door tile
		
	?mainblusetup:
		LDA #!DoorSpeedsTableBLUIndex : STA !RAMPLMVars2,x ; set door speeds table index
		LDX !RAMPLMBlockIndices,y             ;\
		LDA !LevelDataL1Arr,x                 ;) Get tile flip bits from level data
		AND #$0C00                            ;/
		ORA !RAMPLMVars,y : STA !RAMPLMVars,y ; Apply tile flips to PLM door tile in !RAMPLMVars,y
	?ret:
		RTS
}
endmacro
		
		; BlueDoorInstList: Generates instruction list for a blue door.
		; Note: Any door PLM that jumps to DoorBLU<O>Main or DoorBLU<O>Close needs to have all BLUDoorSpeeds at the beginning of it's DoorSpeedsTable.
		; See InstDrawDoor for details.
		; Arguments:
		; 	O: The orientation of the door. Valid options are H, V.
macro BlueDoorInstList(O)
{
	; Instruction List - Blue door opening animation
	DoorBLU<O>Main:
		dw !InstOpenSFX : db !OpenSound
		dw InstDrawDoor<O> : db !DoorBLU<O>Frame3Offset, !TTairbyte|!OpenSpeedIndex ; we could use InstDrawBLUDoor but in this case it's the same with slightly higher execution time
		dw InstDrawDoor<O> : db !DoorBLU<O>Frame2Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawDoor<O> : db !DoorBLU<O>Frame1Offset, !TTairbyte|!OpenSpeedIndex
		dw InstDrawNoCapDoor<O> : db $00, !TTairbyte|!EndAnimSpIndex
		dw !InstDelete
		
	; Instruction List - Blue door closing
	DoorBLU<O>Close:
		; okay so the below 3 lines of code give us a setup where:
		;  if the door PLM completes it's closing animation without getting shot, it deletes itself and spawns correct blue door tile BTS
		;  if it is interrupted by getting shot, it jumps to the blue door opening animation.
		dw !InstSetLink : dw DoorBLU<O>Main
		dw !InstSetPre : dw !GotoLinkIfShotGRY
		dw !InstSetBTS : db $44 ; PLM tile BTS = 44h (generic shot trigger)
		dw InstDrawNoCapDoor<O> : db $00, !TTshotbyte|!EndAnimSpIndex
		dw !InstClosSFX : db !ClosSound
		dw InstDrawDoor<O> : db !DoorBLU<O>Frame1Offset, !TTshotbyte|!ClosSpeedIndex
		dw InstDrawDoor<O> : db !DoorBLU<O>Frame2Offset, !TTshotbyte|!ClosSpeedIndex
		dw InstDrawDoor<O> : db !DoorBLU<O>Frame3Offset, !TTshotbyte|!ClosSpeedIndex
		
	; Instruction list - closed blue door (also jumped to by eye doors)
	DoorBLU<O>Closed:
		dw InstSetBLUDoorBTS
		dw InstDrawBLUDoor<O> : db !DoorBLU<O>Frame4Offset, !TTshotbyte|!EndAnimSpIndex ; DrawBLUDoor needed instead of DrawDoor since other doors may jump here
		dw !InstDelete
}
endmacro
		
		; BlueDoorPLMEntry: Generates a PLM entry for a closed blue door.
		; Arguments:
		;    O: The orientation of the door. Valid options are H, V.
macro BlueDoorPLMEntry(O)
{
	print "PLM Entry - closed BLU door facing <O> at ", pc
	DoorBLU<O>ClosedPLMEntry:
	dw DoorBLU<O>ClosedSetup, DoorBLU<O>Main, DoorBLU<O>Close
}
endmacro
		
		; AllBlueDoorPLMEntries: Generates four PLM entries for closed blue doors.
macro AllClosedBlueDoorPLMEntries()
{
	%BlueDoorPLMEntry(H)
	%BlueDoorPLMEntry(V)
}
endmacro
		
		; ClosingBlueDoorPLMEntry: Generates a PLM entry for a closing blue door.
		; Arguments:
		;    O: The orientation of the door. Valid options are H, V.
macro ClosingBlueDoorPLMEntry(O)
{
	print "PLM Entry - Closing BLU door facing <O> at ", pc
	DoorBLU<O>ClosingPLMEntry:
	dw DoorBLU<O>ClosingSetup, DoorBLU<O>Close
}
endmacro
		
		; AllClosingBlueDoorPLMEntries: Generates four Closing Blue Door PLM entries.
macro AllClosingBlueDoorPLMEntries()
{
	%ClosingBlueDoorPLMEntry(H)
	%ClosingBlueDoorPLMEntry(V)
}
endmacro
	}
	
	;=====EYE DOORS=====
	{
		; EyeDoorSetup: Generates setup ASM for an eye door.
		; NOTE: This setup ASM determines whether the blue door it draws is flipped in X or Y directions based on room arg.
macro EyeDoorSetup()
{
	DoorEYESetupEdge:
		JSR DeletePLMAndAbortSetupIfRoomArg ; this call won't return here if room argument is set
		JMP !SetupEyeDoorEdge ; normal eye door edge setup
		
	DoorEYERSetupEye:
		JSR InvertRoomArgH
		
	DoorEYELSetupEye:
		JSR !SetupEyeDoorEye ; normal eye door eye setup
		TYX
		LDA #!BLUHDoorTile : STA !RAMPLMVars,x             ; set door tile
		
	?maineyesetup:
		LDA #$0000+!EYEHP                                  ; set door HP
		ORA #!DoorSpeedsTableEYEIndex : STA !RAMPLMVars2,x ; set door speeds table index
		JMP SharedColoredDoorSetup
}
endmacro
		
		; EyeDoorInstList: Generates instruction list for an eye door.
		; Note: This instruction list uses several vanilla draw instructions. Eye doors are pretty unique, they don't fit as well into the new system.
		; Their "door tile" variable with my new system is just set to a blue door.
		; Arguments:
		;    D: The direction of the door. Valid options are L, R.
macro EyeDoorInstList(D)
{
	; Instruction List - eye door eye
	EyeDoorEye<D>Main:
	{
		dw !InstSetLink, .hit
		dw !InstSetPre, !GotoLinkIfShotEYE
	.sleep
		dw $0004, DrawSolidEYE<D>f1
		dw !InstGotoIfSamusDistance : db $06, $04 : dw .wake ; Go to .wake if Samus is within 06h columns and 04h rows of PLM
		dw !InstGoto, .sleep
	.wake
		dw !InstGotoIfSamusDistance : db $01, $04 : dw .hide ; Go to .hide if Samus is within 01h columns and 04h rows of PLM
	;shoot
		dw $0008, DrawSolidEYE<D>f2
		dw $0040, DrawShotEYE<D>f3
		dw !InstShootEyeDoorProj, !EyeDoor<D>ProjectileArg
		dw $0020, DrawShotEYE<D>f3
		dw !InstShootEyeDoorProj, !EyeDoor<D>ProjectileArg
		dw $0020, DrawShotEYE<D>f3
		dw !InstShootEyeDoorProj, !EyeDoor<D>ProjectileArg
		dw $0040, DrawShotEYE<D>f3
		dw $0006, DrawSolidEYE<D>f2
		dw $0060, DrawSolidEYE<D>f1
		; fixed a vanilla quirk where if you leave eye door activation range after it shoots, it displays anim frame 2 (eye partially open) for 6 frames randomly.
		; fix was done by cutting out unnecessary instructions.
		dw !InstGoto, .sleep
	.hide
		dw $0004, DrawSolidEYE<D>f1
		dw !InstGoto, .wake
	.hit
		dw !InstEyeHitSFX : db !EyeHitSound
		dw !InstSpawn2EyeDoorSmoke
		dw !InstSpawn2EyeDoorSmoke
		dw InstNewDoorHit : dw .die ; Decrement door HP; Set room argument door and go to .die if HP <= 0
		dw $0002, DrawSolidEYE<D>f4
		dw $0002, DrawSolidEYE<D>f3
		dw !InstSpawn2EyeDoorSmoke
		dw $0002, DrawSolidEYE<D>f4
		dw $0002, DrawSolidEYE<D>f3
		dw $0002, DrawSolidEYE<D>f4
		dw !InstSpawn2EyeDoorSmoke
		dw $0002, DrawSolidEYE<D>f3
		dw $0004, DrawSolidEYE<D>f2
		dw $0008, DrawSolidEYE<D>f1
		dw !InstSpawnEyeDoorSweat, !EyeDoor<D>SweatArg
		dw $0040, DrawSolidEYE<D>f1
		;vanilla quirk (not fixed by default): eye doors will fire at you no matter how far away you are from them after they are hit.
		;normally, they only fire if you're close.
		;to fix, change the below line to
		;dw !InstGoto, .sleep
		dw !InstGoto, .wake
	.die
		dw !InstSetPre, !GotoLinkIfShotGRY
		dw !InstSetLink, .openbluedoor ; if samus shoots the door, open
		dw !InstSpawnEyeDoorSmoke
		dw !InstSpawnEyeDoorSmoke
		dw !InstSpawn2EyeDoorSmoke
		dw !InstSpawn2EyeDoorSmoke
		dw !InstMovePLMUpAndMake<D>BlueDoor ; also sets blue door BTS and below copy tiles BTS
		dw !InstSetBTS : db $44 ; top of door tile BTS = 44 (shot block with BTS 44 is generic shot detector)
		dw InstSetDoorHealth : db $0A ; we are using door health RAM as an animation timer
	.deadflash
		dw !EDeadEYEDelay, DrawShotEYE<D>FULL
		dw !EDeadBLUDelay, DrawShotDoor<D>BLUf4
		dw InstNewDoorHit, .drawbludoorandend ; okay so this is confusing but, since I am using door health as a timer, this has nothing to do with when samus shoots the door. this instr simply decrements door health (aka timer) and jumps to the argument addr when it is zero.
		dw !InstGoto, .deadflash
	.drawbludoorandend
		; InstNewDoorHit clears pre-inst so we don't have to do that here
		dw !InstGoto, DoorBLUHClosed
	.openbluedoor
		dw !InstClearPre
		dw InstSetBLUDoorBTS
		dw !InstGoto, DoorBLUHMain ; opening blue door
	}
	
	; Instruction List - eye door top
	EyeDoorTop<D>Main:
	{
	.wait
		dw !InstGotoIfSamusDistance : db $06, $10 : dw .start ; Go to .start if Samus is within 06h columns and 10h rows of PLM
		dw $0008, DrawSpikeEYE<D>TopEdgef1
		dw !InstGoto, .wait
	.start
		dw !InstSetLink, .die
		dw !InstSetPre, !GotoLinkIfRoomArgDoor
	.anim
		dw $0008, DrawSpikeEYE<D>TopEdgef1
		dw $0008, DrawSpikeEYE<D>TopEdgef2
		dw $0008, DrawSpikeEYE<D>TopEdgef3
		dw $0008, DrawSpikeEYE<D>TopEdgef2
		dw !InstGotoIfSamusDistance : db $06, $10 : dw .anim ; Go to .anim if Samus is within 06h columns and 10h rows of PLM
		dw !InstGoto, .wait
	.die
		dw !InstDelete
	}
	
	; Instruction List - eye door bottom (nearly identical to top)
	EyeDoorBtm<D>Main:
	{
	.wait
		dw !InstGotoIfSamusDistance : db $06, $10 : dw .start ; Go to .start if Samus is within 06h columns and 10h rows of PLM
		dw $0008, DrawSpikeEYE<D>BtmEdgef1
		dw !InstGoto, .wait
	.start
		dw !InstSetLink, .die
		dw !InstSetPre, !GotoLinkIfRoomArgDoor
	.anim
		dw $0008, DrawSpikeEYE<D>BtmEdgef1
		dw $0008, DrawSpikeEYE<D>BtmEdgef2
		dw $0008, DrawSpikeEYE<D>BtmEdgef3
		dw $0008, DrawSpikeEYE<D>BtmEdgef2
		dw !InstGotoIfSamusDistance : db $06, $10 : dw .anim ; Go to .anim if Samus is within 06h columns and 10h rows of PLM
		dw !InstGoto, .wait
	.die
		dw !InstDelete
	}
	
	EyeDoor<D>END: ;this is included to reset sublabel namespace after this macro
}
endmacro
		
		; EyeDoorPLMEntry: Generates a PLM entry for an eye door.
		; Arguments:
		;    D: The direction of the door. Valid options are L, R.
macro EyeDoorPLMEntry(D)
{
	print "PLM Entry - EYE door eye facing <D> at ", pc
	dw DoorEYE<D>SetupEye,  EyeDoorEye<D>Main						;eye door eye
	print "PLM Entry - EYE door top facing <D> at ", pc
	dw DoorEYESetupEdge, EyeDoorTop<D>Main, EyeDoorTop<D>Main	;eye door top edge
	print "PLM Entry - EYE door btm facing <D> at ", pc
	dw DoorEYESetupEdge, EyeDoorBtm<D>Main						;eye door bottom edge
}
endmacro
		
		; AllEyeDoorPLMEntries: Generates two PLM entries for eye doors.
macro AllEyeDoorPLMEntries()
{
	%EyeDoorPLMEntry(R);right
	%EyeDoorPLMEntry(L);left
	;if you want to add vertical eye doors, this would be the starting point :)
	;(you would also have to repoint where this macro writes though)
}
endmacro
	}
	
}

;================PLM DRAW INSTRUCTIONS================
{
	org !EyeDoorDrawInstsLoc
	;====EYE DOOR====
	{ 
		;$84:9BF7
		DrawSolidEYELFULL:
			dw $8004, $84AA, $84CC, $8CCC, $8CAA
			dw $0000
			
		;$84:9C03
		DrawSolidEYELf1:
			dw $8002, $84CC, $8CCC
			dw $0000
			
		;$84:9C0B
		DrawSolidEYELf2:
			dw $8002, $84CB, $8CCB
			dw $0000
			
		;$84:9C13
		DrawShotEYELf3:
			dw $8002, $C4CA, $DCCA
			dw $0000
			
		;$84:9C1B
		DrawSolidEYELf4:
			dw $8002, $84CD, $8CCD
			dw $0000
			
		;$84:9C23
		DrawSolidEYELf3:
			dw $8002, $84CA, $8CCA
			dw $0000
			
		;$84:9C2B 
		DrawSpikeEYELTopEdgef1:
			dw $0001, $A4AA
			dw $0000
			
		;$84:9C31
		DrawSpikeEYELTopEdgef2:
			dw $0001, $A4AB
			dw $0000
			
		;$84:9C37
		DrawSpikeEYELTopEdgef3:
			dw $0001, $A4AC
			dw $0000
			
		;$84:9C3D
		DrawSpikeEYELBtmEdgef1:
			dw $0001, $ACAA
			dw $0000
			
		;$84:9C43
		DrawSpikeEYELBtmEdgef2:
			dw $0001, $ACAB
			dw $0000
			
		;$84:9C49
		DrawSpikeEYELBtmEdgef3:
			dw $0001, $ACAC
			dw $0000
			
		;$84:9C4F
		DrawSolidEYERFULL:
			dw $8004, $80AA, $80CC, $88CC, $88AA
			dw $0000
			
		;$84:9C5B
		DrawSolidEYERf1:
			dw $8002, $80CC, $88CC
			dw $0000
			
		;$84:9C63
		DrawSolidEYERf2:
			dw $8002, $80CB, $88CB
			dw $0000
			
		;$84:9C6B
		DrawShotEYERf3:
			dw $8002, $C0CA, $D8CA
			dw $0000
			
		;$84:9C73
		DrawSolidEYERf4:
			dw $8002, $80CD, $88CD
			dw $0000
			
		;$84:9C7B
		DrawSolidEYERf3:
			dw $8002, $80CA, $88CA
			dw $0000
			
		;$84:9C83
		DrawSpikeEYERTopEdgef1:
			dw $0001, $A0AA
			dw $0000
			
		;$84:9C89
		DrawSpikeEYERTopEdgef2:
			dw $0001, $A0AB
			dw $0000
			
		;$84:9C8F
		DrawSpikeEYERTopEdgef3:
			dw $0001, $A0AC
			dw $0000
			
		;$84:9C95
		DrawSpikeEYERBtmEdgef1:
			dw $0001, $A8AA
			dw $0000
			
		;$84:9C9B
		DrawSpikeEYERBtmEdgef2:
			dw $0001, $A8AB
			dw $0000
			
		;$84:9CA1
		DrawSpikeEYERBtmEdgef3:
			dw $0001, $A8AC
			dw $0000
	}
	
	org !DrawInstsLoc;$84A677
	;====NEW DRAW INSTRS====
	{
		;$84:A9A7
		DrawSolidDoorLBLUf4:
			dw $8004, $800C, $D02C, $D82C, $D80C
			dw $0000
			
		;$84:A9E3
		DrawSolidDoorRBLUf4:
			dw $8004, $840C, $D42C, $DC2C, $DC0C
			dw $0000
			
		DrawShotDoorLBLUf4:
			dw $8004, $C00C, $D02C, $D82C, $D80C
			dw $0000
			
		DrawShotDoorRBLUf4:
			dw $8004, $C40C, $D42C, $DC2C, $DC0C
			dw $0000
			
		DrawShotEYELFULL:
			dw $8004, $C4AA, $D4CC, $DCCC, $DCAA
			dw $0000
			
		DrawShotEYERFULL:
			dw $8004, $C0AA, $D0CC, $D8CC, $D8AA
			dw $0000
	}
	print "beginning of newly free space at old door draw instructions: ", pc
	warnpc $84AA98
	print "end       of newly free space at old door draw instructions: 84aa97"
	
}

;=============DOOR PLM INSTRUCTION LISTS==============
{
	;=====TORIZO DOOR=====
	; Almost an exact clone of Grey Door Facing Right, but with different closing speeds and other tiny changes to the instruction list.
	; Flows into the regular grey door instruction list.
	{
		org !TorizoDoorCloseInstListLoc
		TorizoDoorClose: ; gets run instead of DoorGRYHClose, only if bombs haven't already been collected.
		.loop1
			dw InstDrawNoCapDoorH : db $00, !TTairbyte|!EndAnimSpIndex
			dw !InstGotoIfNotHaveBombs, .loop1
			dw InstDrawNoCapDoorH : db $00, !TTairbyte|!TorizoDSpIndex
			dw !InstClosSFX : db !ClosSound
			dw InstDrawDoorH : db !DoorGRYHFrame1Offset, !TTsolidbyte|!TorizoClosSpeedIndex ;\
			dw InstDrawDoorH : db !DoorGRYHFrame2Offset, !TTsolidbyte|!TorizoClosSpeedIndex ;) close door at torizo door closing speed instead of normal grey door closing speed
			dw InstDrawDoorH : db !DoorGRYHFrame3Offset, !TTsolidbyte|!TorizoClosSpeedIndex ;/
			dw !InstGoto, DoorGRYHMain
		
		print "beginning of newly free space at torizo door closing instruction list: ", pc
		warnpc $84BA70
		print "end       of newly free space at torizo door closing instruction list: 84ba6f"
		
		print "beginning of newly free space at torizo door main instruction list (this patch writes nothing here): 84ba7f"
		print "end       of newly free space at torizo door main instruction list (this patch writes nothing here): 84baf4"
	}
	
	;=====EYE DOORS=====
	{
		org !EyeDoorInstListLoc
			%EyeDoorInstList(L)
			%EyeDoorInstList(R)
		print "beginning of newly free space at eye door instruction lists: ", pc
		warnpc $84DA8D
		print "end       of newly free space at eye door instruction lists: 84da8c"
	}
	
	; WRITE ALL NEW INSTRUCTION LISTS AND DATA STARTING HERE
	org !GRYInstListLoc
	
	;=====GREY DOORS=====
	{
		%GreyDoorInstList(H)
		%GreyDoorInstList(V)
	}
	
	;=====COLORED DOORS=====
	{
		%ColoredDoorInstList(H)
		%ColoredDoorInstList(V)
	}
	
	;=====BLUE DOORS=====
	{
		%BlueDoorInstList(H)
		%BlueDoorInstList(V)
	}
	
}

;====================PLM SETUPS======================
{
	%GreyDoorSetup()
	
	%ColoredDoorSetup(YLW)
	%ColoredDoorSetup(GRN)
	%ColoredDoorSetup(RED)
	
	; Jumped to by all colored doors, grey doors, and eye doors. Common setup.
	SharedColoredDoorSetup:
	{
		LDA #$0000 : STA !RAMPLMTimers,y                            ; clear door shot status
		LDA !RAMPLMRoomArgs,y : AND #$6000 : LSR #3                 ; get tile flips from room arg
		ORA !RAMPLMVars,y : STA !RAMPLMVars,y                       ; set door flips
		LDA !RAMPLMRoomArgs,y : AND #$81FF : STA !RAMPLMRoomArgs,y  ; zero out flips, grey door instruction index, and unused bit from room arg
		
		JSR DeletePLMAndAbortSetupIfRoomArg ; if room argument door is set, we will not return back from this call.
		
		JMP !SetupNormalColoredDoor                                 ; vanilla colored door setup
	}
	
	%BlueDoorSetup()
	
	%EyeDoorSetup()
	
}

;==============NEW PLM INSTRS+FUNCTIONS==============
{
	; Instruction: InstDrawDoor. Draws 4 tiles (1 door) by creating a new PLM Draw Instruction in RAM and manually calling the PLM draw routine
	; Uses the PLM block stored in $1E17 for base tile ID AND for base x-flip.
	; Arguments:
	;    TileOffset (1 byte at [[Y]]): offset from base door tile to draw
	;    TileType+DelayIndex (1 byte at [[Y + 1]]): Highest nybble needs to contain block type to draw; lowest nybble is 00 if using CLROpenDelay, 02 if using CLRClosDelay
	{
		; !RAMDPCustomPLMDrawInstructionLocation: Location in RAM where a custom PLM draw instruction will be made
		; $0D bytes starting at this location are used.
		
		; While it is being made, the map of the data looks like this:
		; !RAMDPCustomPLMDrawInstructionLocation+$00: # of tiles to draw and direction to draw tiles
		; !RAMDPCustomPLMDrawInstructionLocation+$02;tile 1
		; !RAMDPCustomPLMDrawInstructionLocation+$04;tile 2
		; !RAMDPCustomPLMDrawInstructionLocation+$06;tile 3
		; !RAMDPCustomPLMDrawInstructionLocation+$08;tile 4
		; !RAMDPCustomPLMDrawInstructionLocation+$0A;offset in TTB between tile 1 and tile 2
		; !RAMDPCustomPLMDrawInstructionLocation+$0C;flip mask between top half and bottom half of door
		
		; When the routine finishes:
		; !RAMDPCustomPLMDrawInstructionLocation+$0A;terminator for draw instruction
		; !RAMDPCustomPLMDrawInstructionLocation+$0C;unused
	InstDrawDoorH:
		LDA #!HDoorTileDist : STA !RAMDPCustomPLMDrawInstructionLocation+$0A ; used by below routine. Offset in CRE TTB to add.
		LDA #$0800          : STA !RAMDPCustomPLMDrawInstructionLocation+$0C ; used by below routine. Flip mask.
		LDA #$8004          : STA !RAMDPCustomPLMDrawInstructionLocation+$00 ; draw inst # of tiles to draw
		BRA InstDrawDoor
		
	InstDrawDoorV:
		LDA #!VDoorTileDist : STA !RAMDPCustomPLMDrawInstructionLocation+$0A ; used by below routine. Offset in CRE TTB to add.
		LDA #$0400          : STA !RAMDPCustomPLMDrawInstructionLocation+$0C ; used by below routine. Flip mask.
		LDA #$0004          : STA !RAMDPCustomPLMDrawInstructionLocation+$00 ; draw inst # of tiles to draw
		
	InstDrawDoor:
		; part 1: build main draw instruction
		
		LDA $0000,y : AND #$00FF                             ; get tile offset
		STA !RAMDPCustomPLMDrawInstructionLocation+$02       ;
		INY : LDA $0000,y : XBA : AND #$F000                 ; get tile type for first tile
		ORA !RAMDPCustomPLMDrawInstructionLocation+$02       ;
		CLC : ADC !RAMPLMVars,x                              ; A = level data to draw (tile+offset and tile type)
		      STA !RAMDPCustomPLMDrawInstructionLocation+$02 ; first tile in draw inst
		PHA : LDA !RAMDPCustomPLMDrawInstructionLocation+$00
		BMI +
		PLA : AND #$0FFF : ORA #!TTcpyH : BRA ++             ; change tile type to copy tile
	+	PLA : AND #$0FFF : ORA #!TTcpyV
	++
		CLC : ADC !RAMDPCustomPLMDrawInstructionLocation+$0A ; add tile offset
		      STA !RAMDPCustomPLMDrawInstructionLocation+$04 ; second tile in draw inst
		      EOR !RAMDPCustomPLMDrawInstructionLocation+$0C ; flip tile
		      STA !RAMDPCustomPLMDrawInstructionLocation+$06 ; third tile in draw inst
		SEC : SBC !RAMDPCustomPLMDrawInstructionLocation+$0A ; subtract tile offset
		      STA !RAMDPCustomPLMDrawInstructionLocation+$08 ; fourth tile in draw inst
		      STZ !RAMDPCustomPLMDrawInstructionLocation+$0A ; terminator
				
		; part 2: load animation delay
		
		PHX
		LDA !RAMPLMVars2,x : XBA : AND #$00FF : ASL : TAX
		LDA DoorSpeedsTables,x : PHA
		
		; top of stack holds the start offset of the table to read
		
		LDA $0000,y : INY : AND #$000F : CMP #$000F : BNE +
		LDA #!EndAnimDelay : BRA ++
	+	ASL
		
		; A = offset into door properties for time delay
		
		; load value from door properties table
		
		CLC : ADC $01,s : TAX ; X = address of value to read in door properties table
		
		LDA $840000,x ; load value from door properties for time delay
		
	++	PLX : PLX
		STA !RAMPLMInstTimers,x	;store value into instruction timer
		
		; part 3: execute draw instruction
		
		LDA #$0000+!RAMDPCustomPLMDrawInstructionLocation : STA !RAMPLMDrawInstPtrs,x
		TYA : STA !RAMPLMInstListPointers,x
		JSR !FuncProcessPLMDrawInst
		LDX !RAMPLMID
		JSL !FuncLCalcPLMBlockCoords
		JSR !FuncDrawPLM ; parts of DP RAM get overwritten before this call. Make sure your pointer to PLM draw instruction is untouched.
		
		PLA : RTS ; return from processing this PLM this frame
		
		DoorSpeedsTables:
			dw GRYDoorSpeeds, YLWDoorSpeeds, GRNDoorSpeeds, REDDoorSpeeds, BLUDoorSpeeds, EYEDoorSpeeds
			
		GRYDoorSpeeds:
			dw !GRYOpenDelay
			dw !GRYClosDelay
			dw !FlashGRYBDelay
			dw !FlashGRYGDelay
			dw !TorizoDoorDelay
			dw !TorizoClosDelay
			
		YLWDoorSpeeds:
			dw !YLWOpenDelay
			dw !YLWClosDelay
			dw !DHitBLUDelay
			dw !DHitCLRDelay
			
		GRNDoorSpeeds:
			dw !GRNOpenDelay
			dw !GRNClosDelay
			dw !DHitBLUDelay
			dw !DHitCLRDelay
			
		REDDoorSpeeds:
			dw !REDOpenDelay
			dw !REDClosDelay
			dw !DHitBLUDelay
			dw !DHitCLRDelay
			
		BLUDoorSpeeds:
			dw !BLUOpenDelay
			dw !BLUClosDelay
			
		EYEDoorSpeeds:
			dw !BLUOpenDelay ;\
			dw !BLUClosDelay ;) the eye door specifically needs the blue door speeds first because it jumps to the blue door instruction list
			
	}
	
	; Instruction: Draws a horizontal blue door
	InstDrawBLUDoorH:
	{
		LDA   #!BLUHDoorTile             ; Set new (temporary) base door tile to use
		PEA.w DrawCustomDoorReturnAddr-1 ;\
		PEA.w DrawCustomDoorReturnAddr-1 ;) Set return address after drawing (for DrawCustomDoor)
		PEA.w InstDrawDoorH-1            ;) Set function to goto to draw H door (for DrawCustomDoor)
		BRA   DrawCustomDoor             ;) Draw custom door
	}
	
	; Instruction: Draws a vertical blue door
	InstDrawBLUDoorV:
	{
		LDA   #!BLUVDoorTile
		PEA.w DrawCustomDoorReturnAddr-1
		PEA.w DrawCustomDoorReturnAddr-1
		PEA.w InstDrawDoorV-1
		BRA   DrawCustomDoor
	}
	
	; Instruction: Draws a horizontal door without a door cap
	InstDrawNoCapDoorH:
	{
		LDA   #!NoCapHDoorTile
		PEA.w DrawCustomDoorReturnAddr-1
		PEA.w DrawCustomDoorReturnAddr-1
		PEA.w InstDrawDoorH-1
		BRA   DrawCustomDoor
	}
	
	; Instruction: Draws a vertical door without a door cap
	InstDrawNoCapDoorV:
	{
		LDA   #!NoCapVDoorTile
		PEA.w DrawCustomDoorReturnAddr-1
		PEA.w DrawCustomDoorReturnAddr-1
		PEA.w InstDrawDoorV-1
		;BRA   DrawCustomDoor
	}
	
	; Function: Draws a custom door tile other than the one stored in !RAMPLMVars,x
	; uses $1E69 to store old PLM variable and $1E67 to store input arg
	; Arguments:
	;    A: Base offset of door tile to draw
	;    !RAMPLMVars,x: Flip bits used in custom door to draw
	DrawCustomDoor:
	{
		STA $1E67                                 ; store custom tile in $1E67
		LDA !RAMPLMVars,x : STA $1E69             ; use $1E69 to temporarily store original !RAMPLMVars,x value
		AND #$0C00 : ORA $1E67 : STA !RAMPLMVars,x; preserve tile flips, load custom tile from $1E67
		RTS                                       ; JSR InstDrawDoor<O>
	DrawCustomDoorReturnAddr:
		LDA $1E69 : STA !RAMPLMVars,x             ; restore !RAMPLMVars,x from $1E69
		PLA : RTS
	}
	
	; Instruction: Decrement door HP; if door HP <= 0, clear PLM pre-instruction, set PLM room argument door, and goto [[Y]]
	; Replaces $848A91
	InstNewDoorHit:
	{
		SEP #$20
		LDA !RAMPLMVars2,x ;remaining door HP
		DEC
		STA !RAMPLMVars2,x
		REP #$20
		BMI +
		BEQ +
		INY : INY
	.rt	RTS
		
	+	PHX
		LDA !RAMPLMRoomArgs,x
		BMI +
		JSL !FuncLBitIndexToByteIndexAndBitmask
		LDA !DoorBitflagArr,x
		ORA !RAMBitIndexToByteIndexAndBitmaskResult ; Set PLM room argument door
		STA !DoorBitflagArr,x
		
	+	PLX
		ORA #$8000
		STA !RAMPLMRoomArgs,x ; PLM room argument |= 8000h
		LDA #.rt
		STA !RAMPLMPreInsts,x ; Clear PLM pre-instruction
		JMP !InstGoto ; Goto [[Y]]
	}
	
	; Function: Delete shot detection PLM if hit with a power bomb if grey/blue doors are configured to not react to power bombs
	BLUDoorCheckPB:
	{
		CLC : RTS : skip !BlueDoorsReactToPBs
		LDX !ProjectileIndex   ;\
		LDA !ProjectileTypes,x ;|
		AND #$0F00             ;) If current projectile is power bomb:
		CMP #$0300             ;|
		BNE +                  ;/
		LDA #$0000             ;\
		STA !RAMPLMIDs,y       ;) Delete PLM
		SEC : RTS
	+	CLC : RTS
	}
	
	; Instruction: Set BLU door tile BTS from flip bits in !RAMPLMVars,x
	InstSetBLUDoorBTS:
	{
		;PLMVars,x will be doorTile|flips
		PHX : PHY
		LDA !RAMPLMVars,x : TAY : AND #$0C00 : ASL #4 : BMI ++ : ASL : BPL +++
		;x flip only
		TYA : AND #$03FF : CMP #!BLUVDoorTile : BEQ +
		LDY #$0041 : BRA .setBTS ;horizontal X flip door (assume R)
	+++	LDY #$0040 : BRA .setBTS ;no flip blue door      (assume L)
	+	LDY #$0042 : BRA .setBTS ;vertical X flip door   (assume U)
	++	LDY #$0043               ;Y flip blue door       (assume D)
	
		;BTS value to set is now in Y.
	.setBTS
		LDA !RAMPLMBlockIndices,x : LSR : TAX
		TYA : SEP #$20 : STA $7F6402,x : REP #$20
		PLY : PLX : RTS
	}
	
	; Function: Set grey door pre-instruction
	; Gets pre-instruction index from room argument, then clears those bits from room argument
	; Replaces instruction $84BE3F
	SetGreyDoorPreInst:
	{
		PHX
		LDA !RAMPLMRoomArgs,y		 ;\
		XBA : AND #$001C : LSR : TAX ;) Set grey door pre-inst from room arg
		LDA .preinsts,x				 ;|
		STA !RAMPLMPreInsts,y		 ;/
		
		LDA !RAMPLMRoomArgs,y		 ;\
		AND #$E3FF					 ;) mask out grey door pre inst index bits from PLM room arg
		STA !RAMPLMRoomArgs,y		 ;/
		PLX : RTS
		
		.preinsts
		dw !GotoLinkIfBossDead
		dw !GotoLinkIfMiniBossDead
		dw !GotoLinkIfTorizoDead
		dw !GotoLinkIfEnemiesDead
		dw !GotoLinkNever
		dw !GotoLinkIfTourianStatue
		dw !GotoLinkIfAnimals
	}
	
	; Function: Deal [A] extra damage to a door PLM with ID [X] during door hit
	DealExtraDoorDamage:
	{
		PHP : SEP #$20 : PHA
		LDA !RAMPLMVars2,x
		SEC : SBC $01,s
		STA !RAMPLMVars2,x
		PLA : PLP : RTS
	}
	
	; Function: Invert door [Y] X flip bit in PLM room arg
	InvertRoomArgH:
		LDA !RAMPLMRoomArgs,y : EOR #$2000 : STA !RAMPLMRoomArgs,y : RTS
	
	; Function: Invert door [Y] Y flip bit in PLM room arg
	InvertRoomArgV:
		LDA !RAMPLMRoomArgs,y : EOR #$4000 : STA !RAMPLMRoomArgs,y : RTS
	
	; Function: delete PLM [Y] and abort PLM setup if the room argument door is set
	DeletePLMAndAbortSetupIfRoomArg:
	{
		LDA !RAMPLMRoomArgs,y
		BMI +                           ; if door is set to always respawn, return
		AND #$01FF : JSL !FuncLBitIndexToByteIndexAndBitmask
		LDA !DoorBitflagArr,x : AND !RAMBitIndexToByteIndexAndBitmaskResult
		BEQ +                           ; if the bit is not set, return
		TYX                             ; else,
		STZ !RAMPLMIDs,x : PLA : RTS    ; delete PLM and abort setup
	+	RTS
	}
	
	; Instruction: Set door health to [[Y]]
	InstSetDoorHealth:
	{
		PHP
		LDA $0000,y
		SEP #$20
		STA !RAMPLMVars2,x
		PLP : INY : RTS
	}
	
	; Pre-Instruction: Go to link instruction if shot with a (super) missile, super missile damage = !SuperMissileEyeDoorDamage
	InstGotoLinkIfShotEye:
	{
		LDA !SuperMissileEyeDoorDamage-$01 : STA $00
		JMP InstGotoLinkIfShotRed
	}
	
}

print "beginning of newly free space at door instruction lists: ", pc
warnpc $84C54E
print "end       of newly free space at door instruction lists: 84c54d"

;====================PLM ENTRIES======================
{
org !PLMEntriesLoc
	%AllGreyDoorPLMEntries()
	%AllColorDoorPLMEntries(YLW)
	%AllColorDoorPLMEntries(GRN)
	%AllColorDoorPLMEntries(RED)
	%AllClosedBlueDoorPLMEntries()
	%AllClosingBlueDoorPLMEntries()
	
org !TorizoPLMEntryLoc
	print "PLM Entry - Torizo door facing H at ", pc
	dw DoorGRYInvertedHSetup, DoorGRYHMain, TorizoDoorClose
	
org !EyeDoorPLMEntriesLoc
	%AllEyeDoorPLMEntries()
}

;=================BLUE DOOR POINTERS==================
{
	org $8FE68A+$08 ; DOOR CLOSING PLMS SPAWNED BY $82E8EB DURING ROOM TRANSITION
	{
		dw DoorBLUHClosingPLMEntry ; 4: Blue door closing facing right
		dw DoorBLUHClosingPLMEntry ; 5: Blue door closing facing left
		dw DoorBLUVClosingPLMEntry ; 6: Blue door closing facing down
		dw DoorBLUVClosingPLMEntry ; 7: Blue door closing facing up
	}
	
	org $949EA6+$80 ; PLMS TO SPAWN WHEN SHOOTING A SHOT BLOCK, BTS 40-44h
	{
		dw DoorBLUHClosedPLMEntry
		dw DoorBLUHClosedPLMEntry
		dw DoorBLUVClosedPLMEntry
		dw DoorBLUVClosedPLMEntry
	}
}

;==NEW PLM INSTRS 2 - OVERWRITE NOW-UNUSED ROUTINES===
; IMPORTANT NOTICE!
;  If any of these instructions give you patch conflicts with other patches,
;  it is completely safe to repoint these.
;  Just change the define which defines where the function will be rewritten.
;  They are in their current locations to take advantage of space gained by routines which are now unused in $84,
;  or serve to rewrite existing routines in-place.
{
	org !GotoLinkIfShotRED+$840000
	; Pre-Instruction: Go to link instruction if shot with a (super) missile, super missile damage = !SuperMissileRedDoorDamage
	{
		LDA !SuperMissileRedDoorDamage-$01 : STA $00
	}
	
	; Pre-instruction: Go to link instruction if shot with a (super) missile, super missile damage = [$00]
	; Arguments:
	;    $00: amount of damage that super missiles should do to the door.
	InstGotoLinkIfShotRed:
	{
		LDA !RAMPLMTimers,x     ; RAM PLM timer used as a shot status
		STZ !RAMPLMTimers,x     ; clear shot status
		BEQ .ret                ; if not shot, return (Z flag not affected by STZ)
		AND #$0F00
		CMP #$0200
		BEQ .super              ; if shot with super, goto .super
		CMP #$0100
		BEQ GotoLinkBecauseShot ; if shot with missile, goto GotoLinkBecauseShot
	
	.dud
		LDA #$0057 : JSL !FuncLQueueSoundLib2MaxSounds6 ; play dud sound
	.ret
		RTS
		
	.super
		LDA $00
		JSR DealExtraDoorDamage
	
	GotoLinkBecauseShot:
		LDA !RAMPLMLinkInstrs,x : STA !RAMPLMInstListPointers,x
		LDA #$0001 : STA !RAMPLMInstTimers,x ; inst timer = 1
		RTS
	}
	warnpc $84BD89
	
	org !GotoLinkIfShotGRY+$840000-$02
	BRK #$00 ; intentionally crash the game if anyone tries to run vanilla version of this routine (should never happen)
	
	; Pre-instruction: Go to link instruction if shot with anything (except a power bomb if blue/grey doors are set to not react to them)
	InstGotoLinkIfShotGRY: ;note that this label is not directly referenced, instead the above define is.
	{
		LDA !RAMPLMTimers,x ; RAM PLM timer used as a shot status
		STZ !RAMPLMTimers,x ; clear shot status
		BEQ .ret            ; if not shot, return (Z flag not affected by STZ)
		
		BRA .hit : skip !BlueDoorsReactToPBs
		AND #$0F00 ;\
		CMP #$0300 ;) If hit with non-power bomb projectile, goto link instruction
		BNE .hit   ;/
	.ret
		RTS
		
	.hit
		JMP GotoLinkBecauseShot
	}
	warnpc $848A92
}

; *wipes sweat off of forehead*



