Nodever2's Door Transitions

--- WHAT IS IT: ---
 A patch for Super Metroid that improves door transition animations by adding animation curves, and allowing customization options.

--- HOW TO USE: ---
 1. Applying the patch
  You'll need:
   - The patch itself - this is included in this zip file, "Nodever2_Door_Transitions_v1.asm"
   - "Super Metroid (JU) [!].smc" or "Super Metroid (JU) [!].sfc" (smc and sfc files are the same thing). This is known as the "vanilla" or unmodified game.
   - asar, the SNES assembler, i.e. the tool you use to apply this patch to the Super Metroid game.
     I developed this patch with this version of asar (v1.90pre): https://github.com/thedopefish/asar/releases/tag/metconst6
     (click asar_windows_x86.zip to download the windows version)
     asar is a command line tool. If you run the following command, asar will give more information about how to use it:
     asar -h
     If windows tells you that the command is not recognized as an internal or external command, operable program or batch file, you're using the command line wrong.
     Feel free to ask around the Metroid Construction discord or forums for assistance.
     Discord: https://discord.gg/xDwaaqa
     Forums: https://forum.metroidconstruction.com/index.php
     In addition to the normal command to apply the patch, I personally use the following of asar's optional command line flags/options when assembling the patch: --no-title-check --fix-checksum=off

 2. Customizing the patch
  You can open the patch with a text editor such as Notepad, and several customization options can be found in the VARIABLES/CONSTANTS section near the top.
  All of these options are in hexadecimal (denoted with a $ prefix), not decimal.
  Decimal (base 10) goes like this:     1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, ...
  Hexadecimal (base 16) goes like this: 1, 2, 3, 4, 5, 6, 7, 8, 9,  A,  B,  C,  D,  E,  F, 10, 11, ...
  
  After changing these, you'll have to apply the patch to the ROM again for the changes to take effect.
  
  * Freespace Options
    > This patch uses unused space in the game file (aka freespace) that could potentially conflict with other patches if you use them
      (by default, none of the ones listed in Extras conflict with this one). If you need to change the addresses that are used, you can change
      !Freespace80, !FreespaceAnywhere, and the related constants.
  * RAM usage
    > This patch also uses a few RAM addresses that are normally unused in Super Metroid - you can customize which ones this patch uses in case there are conflicts with other patches.
  * ScreenFadeDelay
    > This is how fast the screen fades to/from black at the beginning or end of the transition. Lower numbers make it faster.
  * TransitionLength
    > This is how long the door transition takes. Lower numbers make it faster. Don't use values that are too small - I recomend using $0018 or greater.
  * TransitionAnimation
    > Set this to 1, 2, or 3 to make the door transition animate differently.
  * ReportFreespaceAndRamUsage
    > The patch by default prints the RAM and freespace it uses to the console when assembling - set this to 0 to turn that off.

--- EXTRAS: ---
 * Kejardon_decompression_optimization.asm - This is another patch you can apply in the same way you applied mine. It makes loading rooms faster. It was made by kejardon with fixes from Maddo.
 * SPC Transfer Optimization by total - This patch makes loading music faster. Get it here: https://patrickjohnston.org/ASM/ROM%20data/Super%20Metroid/Other's%20work/total%20SPC%20transfer%20optimisation.asm
 * Full Door Cap PLM Rewrite by Nodever2 - This makes door caps better, you can't bonk on them anymore and various other improvements. Get it here: https://metroidconstruction.com/resource.php?id=562

--- VERSION HISTORY: ---
 2025-11-07 v1.0: Initial release.
   * Known Issues:
      > I got stuck in the ceiling after leaving Mother Brain's room - was able to get out and not get softlocked
      > Escape timer flickers during horizontal door transitions
      > Can see flickering of door tubes when moving down an elevator room that has door tubes -> confirmed this is an issue in vanilla, so I'm leaving it for now.

--- CREDITS: ---
 * Nodever2 - Main developer
 * P.JBoy   - Keeper of the commented Super Metroid bank logs, without which this patch would not have been possible. https://patrickjohnston.org/bank/index.html
 * Tundain  - Gave me the idea of how we can tell whether to position the door DMA (a.k.a. black flickering) on the top or bottom of the screen