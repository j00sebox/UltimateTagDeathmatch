; Ultimate Tag: Deathmatch


	processor 6502
	include "vcs.h"
	include "macro.h"

;-------------CONSTANTS-------------------

; player colours
RED = $42
BLUE = $72

; player 0 joystick controls
LEFT = %01000000
RIGHT = %10000000
DOWN = %00010000
UP = %00100000

; mask for player on player collisions
PPCOLLISION = %10000000 

; the slower horizontal speeds for the players
NORMAL_RIGHT = $F0
NORMAL_LEFT = $10

; the faster horizontal speeds for the players
FAST_RIGHT = $D0
FAST_LEFT = $20

FASTY_SPEED = $FF
SLOWY_SPEED = $C0
SPRITE_HEIGHT = 8		; height of player sprite
SCREEN_HEIGHT = 192	    ; height of the screen (only drawing on 192 scanlines)

; uninitialized segment for our RAM variables

	SEG.U VARS
	ORG $80

; need to keep track of the y position of players relative to the bottom
P0_YPosFromBot ds 2
P1_YPosFromBot ds 2
P0_Y ds 1	; needed for skipdraw
P1_Y ds 1
P0_X ds 1 ; used to keep track of the players horizontal position
P1_X ds 1
P0_Ptr ds 2	; ptr to current graphic
P1_Ptr ds 2
PlayerIt ds 1 ; stores whihc player is currently it, 0 means player 0 is it, 1 means player 1 is it
AvailableToCollide ds 1 ; checks if enough time has passed for the player to tag the other
; player speeds in different directions
Player0XLSpeed ds 1
Player0XRSpeed ds 1
Player1XLSpeed ds 1
Player1XRSpeed ds 1
Player0YSpeed ds 1
Player1YSpeed ds 1
tagCounter ds 1 ; so players can't tag back immediately only when this counter reaches 0


	SEG CODE

; start of the ROM
	org $F000

Start
	CLEAN_START ; macro provided by macro.h, clears RAM

	lda $0
	sta COLUBK	; start with black background

	; player 0 starts off it so colour accordingly
	lda #RED
	sta COLUP0 
    lda #BLUE
    sta COLUP1

	; collisions should be able to happen at the first
	lda #$80
	sta AvailableToCollide

	; initial y positions for both players
	lda #12
	sta P0_YPosFromBot+1	

	lda #12
	sta P1_YPosFromBot+1	

	; inital x positions
	lda #80
	sta P0_X

	lda #50
	sta P1_X

	lda #>PlayerGraphic ;high byte of graphic location
	sta P0_Ptr+1	; store in high byte of graphic pointer

	lda #>PlayerGraphic ; high byte of graphic location
	sta P1_Ptr+1	; store in high byte of graphic pointer

	; initalize speed according to which player is it
	; the it player moves faster in all directions
	lda #FASTY_SPEED
	sta Player0YSpeed
	lda #SLOWY_SPEED
	sta Player1YSpeed

	lda #FAST_LEFT
	sta Player0XLSpeed
	lda #FAST_RIGHT
	sta Player0XRSpeed

	lda #NORMAL_LEFT
	sta Player1XLSpeed
	lda #NORMAL_RIGHT
	sta Player1XRSpeed


MainLoop ; start of frame
	VERTICAL_SYNC ; macro that does all the VSYNC lines for us
	lda #43
	sta TIM64T ; timer for 43 counts of 64 cycles, this timer will run out after 43x64 = 2752 cycles which is roughly the amount in the vblank time

    lda #<PlayerGraphic 	;low byte of ptr is normal graphic
	sta P0_Ptr		;(high byte already set)

	lda #<PlayerGraphic 	;low byte of ptr is normal graphic
	sta P1_Ptr		;(high byte already set)
	

	; check for player inputs

	lda #LEFT
	bit SWCHA
	bne DoneMoveLeft

	ldx Player0XLSpeed	; move player 0 left

	dec P0_X

	lda #%00001000   ; a 1 in D3 of REFP0 says make it mirror
	sta REFP0	; gives the appearance that the player is looking in a certain direction

DoneMoveLeft

	;joystick pressed right?
	lda #RIGHT
	bit SWCHA
	bne DoneMoveRight

	ldx Player0XRSpeed	; move player 0 right

	inc P0_X

	lda #%00000000
	sta REFP0    	; unmirrored 

DoneMoveRight

    stx HMP0

; for up and down we just inc or dec player 0 y position from bottom
	
	lda #DOWN
	bit SWCHA
	bne DoneMoveDown

	
	clc 
	lda P0_YPosFromBot
	adc <Player0YSpeed
	sta P0_YPosFromBot
	lda P0_YPosFromBot+1
	adc >Player0YSpeed
	sta P0_YPosFromBot+1

DoneMoveDown

	lda #UP
	bit SWCHA
	bne DoneMoveUp

	sec 
	lda P0_YPosFromBot
	sbc <Player0YSpeed
	sta P0_YPosFromBot
	lda P0_YPosFromBot+1
	sbc >Player0YSpeed
	sta P0_YPosFromBot+1

DoneMoveUp

	; for skipDraw, P0_Y needs to be set
	; this will represent what scanlines need to have sprite data drawn
	; so we take the height of the screen plus the height of the sprite and subtract the players position from the bottom 
	lda #SCREEN_HEIGHT + #SPRITE_HEIGHT - #1
	sec 
	sbc P0_YPosFromBot+1 ;subtract integery byte of distance from bottom
	sta P0_Y

	lda #SCREEN_HEIGHT + #SPRITE_HEIGHT - #1
	sec 
	sbc P1_YPosFromBot+1 ;subtract integery byte of distance from bottom
	sta P1_Y


	; we need to addjust the graphic pointer of both players for skip draw so it matches the postion we want to start drawing our sprite
	lda P0_Ptr
	sec 
	sbc P0_YPosFromBot+1
	clc 
	adc #SPRITE_HEIGHT-#1
	sta P0_Ptr	;2 byte

	lda P1_Ptr
	sec 
	sbc P1_YPosFromBot+1	
	clc 
	adc #SPRITE_HEIGHT-#1
	sta P1_Ptr	;2 byte

; cpu veritcal movement
Player1VerticalMovement
	; check if player 1 is it
	; it will have different behaviour based in if it's "it" or not
	lda #1
	bit PlayerIt
	beq .notitv 
.itv
	sec 
	; if player 1 is above player 0 it should move down
	; if it's below then it should move up
	; if it's on the same line then it doesn't need any Y adjustment
	lda P1_Y
	sbc P0_Y
	beq .doneVertical
	bmi .goup
	jmp .godown 
.notitv
	sec 
	; same thing if player 1 is not it except the actions are the opposite
	lda P1_Y
	sbc P0_Y
	beq .doneVertical
	bmi .godown
	jmp .goup 
.goup
	sec 
	lda P1_YPosFromBot
	sbc <Player1YSpeed
	sta P1_YPosFromBot
	lda P1_YPosFromBot+1
	sbc >Player1YSpeed
	sta P1_YPosFromBot+1
	jmp .doneVertical
.godown
	clc 
	lda P1_YPosFromBot
	adc <Player1YSpeed
	sta P1_YPosFromBot
	lda P1_YPosFromBot+1
	adc >Player1YSpeed
	sta P1_YPosFromBot+1
.doneVertical

; cpu hotizontal movement
Player1HorizontalMovement
; same thing as the previous function did to check if player 1 is it
	lda #1
	bit PlayerIt
	beq .notith
.ith
	sec 
	; similar logic as previous to decide if it should go left, right, or not
	lda P1_X
	sbc P0_X
	beq .doneHorizontal
	bmi .goright
	jmp .goleft
.notith
	sec 
	lda P1_X
	sbc P0_X
	beq .doneHorizontal
	bmi .goleft
.goright
	ldx Player1XRSpeed	;move ghost right

    lda #$80
	sta AvailableToCollide

	inc P1_X

	lda #%00000000
	sta REFP1    	;unmirrored P0

	jmp .doneHorizontal

.goleft
	ldx Player1XLSpeed	;move ghost left

    lda #$80
	sta AvailableToCollide

	dec P1_X

	lda #%00001000   ;a 1 in D3 of REFP0 says make it mirror
	sta REFP1

.doneHorizontal

	stx HMP1 ; store player 1 horizontal choice in here

    lda CXPPMM ; check of there is a collision between players
	bit PPCOLLISION
	and AvailableToCollide
	bpl NoTag ; if no collison we skip all the rest
	; make it so no more collisions can happen until the counter is up
	lda #0
	sta AvailableToCollide
	; reset tag counter
	lda #100
	sta tagCounter
	dec PlayerIt ; decrement the playerIt value
	bne .player1It ; if player 1 was it then the new value would be 0 so this wouldn't branch, if player 0 was it then the branch will be triggered
	; player 0 is now it so it gets turned red
	lda #RED
	sta COLUP0
    lda #BLUE
    sta COLUP1

	; adjust speeds to make the "it" player faster
	lda #FASTY_SPEED
	sta Player0YSpeed
	lda #SLOWY_SPEED
	sta Player1YSpeed

	lda #FAST_LEFT
	sta Player0XLSpeed
	lda #FAST_RIGHT
	sta Player0XRSpeed

	lda #NORMAL_LEFT
	sta Player1XLSpeed
	lda #NORMAL_RIGHT
	sta Player1XRSpeed

NoTag

	; clear the collision register 
	sta CXCLR

; check if counter has reached 0
; if it has then collisions will be allowed to happen
updateCounter
	dec tagCounter
	bpl .notzero
	lda #0
	sta tagCounter 
	lda #$80 
	sta AvailableToCollide
.notzero

WaitForVblankEnd
	lda INTIM
	bne WaitForVblankEnd
	ldy #SCREEN_HEIGHT - 1

	sta WSYNC
	sta HMOVE ; move player 0 & 1 horizontally

	sta VBLANK

; scanline loop
; loop for 192 scanlines
ScanLoop
; skipDraw
; skipDraw algorithm is used to move sprites vertically
; it does this by only allowing sprite data to be drawn on the lines that correspond to the sprites current Y position

; draw player sprite 0:
	lda #SPRITE_HEIGHT-1     ; 2
	dcp P0_Y            ; 5 (DEC and CMP)
	bcs .doDraw0        ; 2/3
	lda #0              ; 2
	.byte $2c             ;-1 (BIT ABS to skip next 2 bytes)
.doDraw0:
	lda (P0_Ptr),y      ; 5	get correct sprite data from line y
	sta GRP0            ; 3 = 18 cycles (constant, if drawing or not!)

; draw player sprite 1:
	lda #SPRITE_HEIGHT-1     ; 2
	dcp P1_Y            ; 5 (DEC and CMP)
	bcs .doDraw1        ; 2/3
	lda #0              ; 2
	.byte $2c             ;-1 (BIT ABS to skip next 2 bytes)
.doDraw1:
	lda (P1_Ptr),y      ; 5
	sta GRP1            ; 3 = 18 cycles (constant, if drawing or not!)

	sta WSYNC

	dey 
	bne ScanLoop

	lda #2
	sta WSYNC
	sta VBLANK
	ldx #30
OverScanWait
	sta WSYNC
	dex 
	bne OverScanWait
	jmp  MainLoop

.player1It
	; set the playerIt variable to be 1 and change player 1 to red
	lda #1
	sta PlayerIt
	lda #RED
	sta COLUP1
    lda #BLUE
    sta COLUP0

	lda #FASTY_SPEED
	sta Player1YSpeed
	lda #SLOWY_SPEED
	sta Player0YSpeed

	lda #FAST_LEFT
	sta Player1XLSpeed
	lda #FAST_RIGHT
	sta Player1XRSpeed

	lda #NORMAL_LEFT
	sta Player0XLSpeed
	lda #NORMAL_RIGHT
	sta Player0XRSpeed

	jmp NoTag 


	org $FEC0

; player sprite data
PlayerGraphic
        .byte #%00000000
        .byte #%01111110
        .byte #%01000010
        .byte #%01011010
        .byte #%00001000
        .byte #%00001000
        .byte #%00100100
        .byte #%00000000



	org $FFFC
	.word Start
	.word Start