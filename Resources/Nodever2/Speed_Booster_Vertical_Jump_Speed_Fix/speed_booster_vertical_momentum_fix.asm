;code by Nodever2
lorom

;This simple code overwrites part of the routine that makes samus jump. Uses no free space.
;It seems that the original intent of the routine was: if samus has speed booster, add half of her X speed to her Y speed when she jumps.
;however, there were two issues in the vanilla code:
;1) The code adds half of her X speed, but not half of her X subpixel speed, to her Y speed and Y subpixel speed respectively.
;2) After adding to her Y subpixel speed, the carry is discarded before adding to her Y speed.
;   this means that if (samus X subpixel speed) + (samus Y subpixel speed) >= 1 pixel/frame, then her final speed will be 1 pixel/frame less than it should be.
;in vanilla, this was often easily noticeable when jumping with speed booster without high jump, and would often result in jumps being lower than jumping without
;speed booster.


;anyway, this code fixes both of those problems.
org $909927
LDA $0B44		;\
ROR				;|use carry from previous LSR
CLC				;|
ADC $0B2C		;} Samus Y subspeed += [Samus X subspeed]/2
STA $0B2C		;/
LDA $0B2E		;