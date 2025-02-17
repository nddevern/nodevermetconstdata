lorom

;Written by Nodever2 on 9-7-2019
;Credits: PJboy for his bank logs, TestRunner and amoeba for their help with VRAM addresses, and DC for his research on animated tiles

;Hello everyone! Welcome to a guide on how to make animated tiles in Super Metroid.
;Please read through all of the information in this document. If you have any questions, feel free to ask.

;---------ABOUT THIS DOCUMENT---------
;This document is an asm file that can be applied directly to your ROM and will add 1 animated tile to Brinstar.
;The comments of this file contain instructions and explanations for everything. They are denoted by a semicolon at the beginning of a comment.

;If you want to understand how animated tiles work, read part 1 and 2. If you just want a template that you can copy and paste, see part 2.
;All hex addresses in this document unless otherwise specified are LoROM addresses.

;THIS GUIDE ASSUMES THAT YOU:
;* Know how to open, edit, and apply an ASM file to a ROM (ASM basics: https://wiki.metroidconstruction.com/doku.php?id=super:asm_lessons)
;* Have set up your tools for editing ASM files. See this webpage for more info: http://wiki.metroidconstruction.com/doku.php?id=super:expert_guides:asm_stylesheet







;The first thing we're going to do is look at the parts of an animated tile.
;The easist way to see what we need is by looking at what the vanilla game does. Remember how spikes are animated in vanilla? We're going to set up a tile that works just like those.
;I'll use vertical spikes as an example, then...

;You should also know that an animated tile has 4 parts:
;1. An entry in the area's animated tiles object list
;2. An object, which is pointed to by the object list and contains pointers for the animated tile's instruction list and the VRAM address, as well as the tile's size info.
;3. Instructions. These tell the tile what graphics to draw, how long to draw it, and in what order. 
;4. Graphics. Animated tiles actually draw graphics from a seperate location in bank $87, not from the tileset itself.

;The animated tiles object list is in bank $83, while all of the other data is in bank $87.

;==================================================================================================================================================================
;======================================================PART 1: STUDYING VANILLA VERTICAL SPIKES ANIMATED TILE======================================================
;==================================================================================================================================================================

;We can essentially observe what the vanilla vertical spikes do, and copy it for our own animated tiles.

;---------BANK $83---------
;THE ANIMATED TILES OBJECT LIST:
;In this bank are the animated tile object lists. Here are all of them, taken from PJ's bank logs:

;vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
; Crateria animated tiles object list
;org $83AC76 :        dw $8257, $8251, $825D, $8263, $824B, $824B, $824B, $824B


; Brinstar animated tiles object list
;org $83AC96 :        dw $8257, $8251, $8281, $824B, $824B, $824B, $824B, $824B


; Norfair animated tiles object list
;org $83ACB6 :        dw $8257, $8251, $824B, $824B, $824B, $824B, $824B, $824B


; Wrecked Ship animated tiles object list
;org $83ACD6 :        dw $8257, $8251, $8275, $827B, $826F, $824B, $824B, $824B


; Maridia animated tiles object list
;org $83ACF6 :        dw $8257, $8251, $8287, $828D, $824B, $824B, $824B, $824B


; Tourian animated tiles object list
;org $83AD16 :        dw $8257, $8251, $824B, $824B, $824B, $824B, $824B, $824B


; Ceres animated tiles object list
;org $83AD36 :        dw $8257, $8251, $824B, $824B, $824B, $824B, $824B, $824B


; Debug animated tiles object list
;org $83AD56 :        dw $8257, $8251, $824B, $824B, $824B, $824B, $824B, $824B
;^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

;Now, these are all pointers to the objects' locations in bank $87.
;For our example, vertical spikes, their objects are at $878257.
;Notice how $8257 happens to be the first value in every list. Spikes are by default in every area's animated tile object list, which probably won't be the case for your custom animated tile.

;Here's another note: See how there are a bunch of pointers to $87824B at the end of every list?
;These represent UNUSED animated tile slots and these pointers can (and will) be replaced by pointers to our custom animated tiles.

;!!!!!!!IMPORTANT!!!!!!!
;These lists only contain 8 animated tile slots. Without modifying other code, EACH AREA CAN ONLY HAVE 8 ANIMATED TILES. Do not add entries to these lists; this will overwrite other stuff in the ROM.
;Just replace ones that are already there.
;Again, $824B entries are unused, it'd be wise to replace those first.





;---------BANK $87---------
;THE ANIMATED TILE OBJECT:
;So we know that the object for vertical spikes is located at $878257 after reading the object list. Let's go to that location and see what we find.


;org $878251 :        dw $816A, $0080, $3880 ; Vertical spikes
;FORMAT:	  Instruction List, Size,  VRAM Address

;So again, this is a list of important values for the animated tile. The first value is a pointer to the animated tile's instruction list in $87. This one is at $87816A.
;The second value is the size of the animation. If you're just animating one tile, it'll be $0080.
;The third value is the VRAM address, which is the address in VRAM that will be animated.

;ABOUT FINDING THE VRAM ADDRESS:
;The way we're going to find this address is by finding out the 8x8 tile's index that you want to animate using the tileset edior of your preferred editor.
;HERE'S SOMETHING IMPORTANT: For an animated tile, all of the tiles that you want to animate need to be right in a row in the tileset!
;The top two tiles need to be just before the bottom two tiles, all in a row. If you're confused, just look at how spikes do it in vanilla and you'll see what I mean.

;USING SMILE RF (guide written for RF version 3.1.09):
;To easiest find the VRAM addres, open your ROM in RF and open the Tileset Editor. In the Tile Table section on the bottom, click on your animated tile.
;In the tile table editor on the top right, your tile should appear. The address of the top left tile (in the case of spikes, $388) is something you need. NOTE: If these four addresses are not consecutive (for the spike it is $388, $389, $38A, $38B) then your tileset is structured incorrectly!
;Multiply this number (in the case of vertical spikes, $388) by $10 to get your VRAM address ($3880).

;USING SMART (guide written for SMART 1.10):
;To easiest find the VRAM addres, open your ROM in SMART and open the Tileset Editor. In the Graphics section on the right, click on the first 8x8 tile of your animated tile.
;In the bottom of the tileset editor, select the Graphics Details tab. The Graphics Tile Number of the top left tile (in the case of spikes, $388) is something you need...
;Multiply this number (in the case of vertical spikes, $388) by $10 to get your VRAM address ($3880).




;THE GRAPHICS:
;Anwyay, now let's look at the next part: The graphics. Open your ROM in a tile editor such as Tile Layer Pro (TLP) and go to $879C04 (PC Address $039C04) to see the vertical spikes.
;This one is made up of THREE 16x16 TILES that are consecutive in the ROM.

;THESE ARE UNCOMPRESSED GRAPHICS IN THE ROM!!!
;EACH 16x16 TILE TAKES UP $80 BYTES.
;REMEMBER that each 16x16 tile is made up of four 8x8 tiles, which I think are $20 bytes each. These are 4bpp graphics.

;Well that was pretty easy.
;Notice how nothing has pointed to $879C04 yet. That's what the instructions do! But I'm getting ahead of myself...



;THE INSTRUCTIONS:
;Last part: The instructions.
;Remember that the animated tile object says the pointer to the instruction list is at $816A. Let's go to $87816A and see what we find.




;org $87816A             
;					  dw $0008, $9C04		;
;					  dw $0008, $9C84		;
;					  dw $0008, $9D04		;<-SEE THE DIAGRAM AT 9C04 (below) IN THIS FILE FOR MORE INFO.
;					  dw $0008, $9C84
;					  dw $80B7, $816A    ;LOOP

;Each of these lines is an instruction.
;The first four lines tell the game what to draw and for how long.
;Let's look at the first line again, the one that says dw $0008, $9C04.
;The $9C04 is a pointer to the graphics in $87. That's how the game knows to look at $879C04 for the first tile.
;Notice how the next tile is $879C84. Remember how we said each 16x16 tile is $80 bytes? So $9C04 is the first tile, $9C84 is the second tile, and $9D04 is the third one.
;Knowing this, we can see that the animation goes: tile 1, tile 2, tile 3, tile 2, repeat.
;
;The first word in the line (the $0008) tells the game how long to draw each tile. Increase this number to slow the animation down, decrease it to speed it up.
;You can make each tile display for a different amount of time as well. There's a lot of customizability here.

;The last line tells the game to loop the animation.
;The $80B7 is just a pointer to code that tells the game to go to an address; $816A is the address it goes to, which happens to be the same address as the beginning of the animation.
;This effectively makes the animation loop.


;Well, that's it.
;Congratulations! You've successfully studied every part of an animated tile!
;I know there's a lot of words up there but it's actually really simple. You'll see!
;Let's make our own now!

;==================================================================================================================================================================
;===============================================================PART 2: MAKING OUR OWN ANIMATED TILE===============================================================
;==================================================================================================================================================================
;All of the code in part 1 was commented out, so it doesn't change your ROM.
;There's code in this part that doesn't have a semicolon in front of it, so it's not commented and will change your ROM if you apply this ASM file.
;Just be aware of that. You can also change this example code to fit your needs.

;ALSO, the code in this section is using Labels. If you don't know how to use labels in assembly, you really, REALLY should come in the Metroid Construction discord and ask us, or find the information yourself on the wiki or something.
;(see labels section of https://bin.smwcentral.net/u/6138/xkas.html)
;It's super important and nobody will judge you for asking.

;---------BANK $83---------
;For this example, the animated tile I want will be in Brinstar. I'm going to edit the animated tile list to contain a pointer to my own animated tile object in $87:

; Brinstar animated tiles object list
;org $83AC96 :        dw $8257, $8251, $8281, $824B, $824B, $824B, $824B, $824B;VANILLA
org $83AC96 :         dw $8257, $8251, $8281, Object, $824B, $824B, $824B, $824B;MODIFIED

;Now that I replaced one of the $824B (unused) entries with a pointer to my own object. Let's create the object now.



;---------BANK $87---------
org $87CA00;THIS CAN BE ANY FREE SPACE IN BANK $87, feel free to change this to suit your needs.
Object:
dw Instruction, $0080, $0280
;FORMAT:	  Instruction List, Size,  VRAM Address

;The instruction list pointer now points to my custom instructions (see below). Note that my VRAM address is almost definitely different from whatever VRAM address you're using.
;It just depends on where in the tileset your tile is. How to find the VRAM address is explained in part 1.

Instruction:            
dw $0010, Graphics
dw $0010, Graphics+#$0080
dw $0010, Graphics+#$0100
dw $0010, Graphics+#$0080
dw $80B7, Instruction

;There are a couple things to note here:
;1. I used a label for my graphics pointer. You may not be able to do this since you probably won't apply your graphics in the same way as I did
;   For more info, READ THE REALLY IMPORTANT INFORMATION BELOW.
;
;2. What do those plus signs mean? Well, it essentially tells the assembler to point to #$0080 tiles AFTER the beginning of the graphics.
;   Since each tile is #$0080 bytes long, that means it'll read the second or third tile.

;See the instructions section in part 1 for more information.





Graphics:
db $C1, $3E, $BE, $41, $5E, $81, $7E, $83, $7E, $87, $7C, $8F, $7B, $9C, $83, $78, $00, $3E, $00, $41, $20, $81, $00, $83, $00, $87, $00, $8F, $00, $9C, $04, $78, $0F, $F0, $77, $98, $61, $BE, $4E, $A1, $3E, $C1, $3E, $C3, $DE, $23, $EE, $1F, $00, $F0, $00, $98, $00, $BE, $10, $A1, $00, $C1, $00, $C3, $00, $23, $00, $1F, $C7, $30, $CF, $30, $8F, $70, $6F, $90, $67, $99, $72, $9F, $70, $BF, $88, $77, $08, $30, $00, $30, $00, $70, $00, $90, $00, $99, $00, $9F, $00, $BF, $00, $77, $C3, $3C, $BD, $42, $5E, $81, $7E, $83, $7E, $83, $7E, $87, $3D, $DE, $01, $FE, $00, $3C, $00, $42, $20, $81, $00, $83, $00, $83, $00, $87, $00, $DE, $00, $FE, $C1, $3E, $B6, $41, $6F, $80, $7F, $80, $7F, $80, $7F, $81, $3E, $C7, $9D, $6E, $00, $3E, $08, $41, $10, $80, $00, $80, $00, $80, $00, $81, $00, $C7, $00, $6E, $E3, $1C, $DD, $22, $36, $C1, $3E, $C3, $3E, $C3, $0C, $FE, $F0, $0E, $99, $06, $00, $1C, $00, $22, $08, $C1, $00, $C3, $00, $C3, $00, $FE, $00, $0E, $60, $06, $81, $7E, $7A, $84, $5B, $84, $7B, $84, $7B, $84, $81, $7E, $E0, $1F, $21, $1E, $00, $7E, $01, $84, $20, $84, $00, $84, $00, $84, $00, $7E, $00, $1F, $00, $1E, $7C, $03, $FE, $03, $FE, $03, $FC, $07, $FD, $0E, $F9, $1E, $70, $FE, $04, $F8, $80, $03, $00, $03, $00, $03, $00, $07, $00, $0E, $00, $1E, $00, $FE, $00, $F8, $C7, $38, $AB, $44, $5D, $82, $7C, $83, $7D, $86, $BA, $4C, $C3, $3C, $F3, $0C, $00, $38, $10, $44, $20, $82, $00, $83, $00, $86, $01, $4C, $00, $3C, $00, $0C, $C3, $3C, $AD, $42, $5E, $81, $3E, $C1, $DE, $23, $EE, $17, $ED, $3E, $E2, $7C, $00, $3C, $10, $42, $20, $81, $00, $C1, $00, $23, $00, $17, $00, $3E, $00, $7C, $C1, $3E, $BC, $43, $5E, $81, $7E, $81, $7E, $83, $7E, $87, $BC, $4F, $C0, $3F, $00, $3E, $00, $43, $20, $81, $00, $81, $00, $83, $00, $87, $00, $4F, $00, $3F, $C3, $FC, $3D, $C2, $7E, $81, $6E, $81, $7E, $83, $7E, $87, $BD, $4E, $02, $7C, $00, $FC, $00, $C2, $00, $81, $10, $81, $00, $83, $00, $87, $00, $4E, $00, $7C
;Woah, what is this? Read to find out!

;!!!!!!!IMPORTANT!!!!!!!
;Above is my actual graphics data. If you apply this code, it will put actual graphics data in your ROM.
;This is absolutely NOT the best way to apply graphics to your ROM, but the reason I did it is so that it's included in this code file so you can see it in action if you want.
;I strongly recommend COMMENTING THE ABOVE LINE (with the db $C1, $3E, etc...) OUT with a semicolon so that it doesn't get added to your ROM once you've learned how this all works.

;So, what is the best way to do this then?
;Open your ROM in a graphics editor such as Tile Layer Pro (TLP) and put the graphics somewhere in $87. These are uncompressed, so one way you could do this is by exporting your tileset in SMILE
;and then dragging the graphics over to freespace in $87. Make sure you're not overwriting any code, and make sure your code doesn't overwrite the graphics once you apply it either.
;Maybe you should put the graphics at the end of the bank so there are no issues with that. You'll also have to change your instructions to point to wherever you put your graphics.



;!!!!!!!IMPORTANT!!!!!!!
;THAT'S ALL, FOLKS! This will successfully create an animated tile in your ROM.
;Now, you might be wondering why your tile isn't actually animated....
;That's a fair question.
;There's one last thing you have to do to activate your animated tile in a given room.

;Open a room in SMILE RF that you want to have the animated tile in. Open the FX editor.
;In the FX Editor, go to the Animated Tiles tab.
;You have to turn on the checkbox that corresponds to your animated tile.
;Which one is that? To find that out we have to take one last look at the animated tiles object list (the one in bank $83).

;org $83AC96 :         dw $8257, $8251, $8281, Object, $824B, $824B, $824B, $824B;MODIFIED

;Here's my modified animated tiles list from above. Remember that the pointer to my custom code was the one that says "Object", which is the fourth one.
;So to activate my animated tile, I'll check the fourth box in the FX editor. (you migth have to repoint your FX / Layer 3 data).
;It says "Unused" because, in vanilla, it was. But it's not anymore!

;NOW your animated tiles should work. You'll have to do this in every room that you want the animation to show up in.
;To see your animation in action, place the tile that you wrote the animated tile code for in the level editor and then test the ROM!

;Thanks for reading! Best of luck with your animatied tiles!