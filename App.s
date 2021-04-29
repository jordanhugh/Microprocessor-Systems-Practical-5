		AREA	InitialisationAndMain, CODE, READONLY
		IMPORT	main
		EXPORT	start
start

; Setup GPIO
;IO1DIR equ		0xE0028018
;IO1SET	equ		0xE0028014
;IO1CLR	equ		0xE002801C
;IO1PIN equ 	0xE0028010

		ldr		r1,	=IO1DIR
		ldr		r2,=0x000f0000				;select P1.19--P1.16
		str		r2,[r1]						;make them outputs
		ldr		r1,=IO1SET
		str		r2,[r1]						;set them to turn the LEDs off
		ldr		r2,=IO1CLR

; Setup User Mode
Mode_USR equ	0x10

; Definitions  -- references to 'UM' are to the User Manual.
; Timer Stuff -- UM, Table 173
T0		equ 	0xE0004000					; Timer 0 Base Address
T1		equ 	0xE0008000
IR		equ 	0						
TCR		equ 	4						
MCR		equ 	0x14						
MR0		equ 	0x18

TimerCommandReset equ 2
TimerCommandRun	equ 1
TimerModeResetAndInterrupt equ 3
TimerResetTimer0Interrupt equ 1
TimerResetAllInterrupts	equ 0xFF

; VIC Stuff -- UM, Table 41
VIC		equ 0xFFFFF000				
IntEnable	equ 0x10					
VectAddr	equ 0x30					
VectAddr0	equ 0x100
VectCtrl0	equ 0x200

Timer0ChannelNumber equ	4					; UM, Table 63
Timer0Mask	equ 1 <<Timer0ChannelNumber		; UM, Table 63
IRQslot_en	equ 5							; UM, Table 58

; Initialisation code
; Initialise the VIC
		ldr 	r0, =VIC					; looking at you, VIC!

		ldr 	r1, =irqhan
		str 	r1, [r0, #VectAddr0] 		; associate our interrupt handler with Vectored Interrupt 0

		mov 	r1, #Timer0ChannelNumber+(1<<IRQslot_en)
		str 	r1, [r0, #VectCtrl0] 		; make Timer 0 interrupts the source of Vectored Interrupt 0

		mov 	r1, #Timer0Mask
		str 	r1, [r0, #IntEnable]		; enable Timer 0 interrupts to be recognised by the VIC

		mov 	r1, #0
		str 	r1, [r0, #VectAddr]   		; remove any pending interrupt (may not be needed)

; Initialise Timer 0
		ldr 	r0, =T0						; looking at you, Timer 0!

		mov 	r1, #TimerCommandReset
		str 	r1, [r0, #TCR]

		mov 	r1, #TimerResetAllInterrupts
		str 	r1, [r0, #IR]

		ldr 	r1, =(14745600/200) - 1	 	; 5 ms = 1/200 second
		str 	r1, [r0, #MR0]

		mov 	r1, #TimerModeResetAndInterrupt
		str 	r1, [r0, #MCR]

		mov 	r1, #TimerCommandRun
		str 	r1, [r0, #TCR]
		
; Setup Stack for each Thread
		ldr 	r0, =0x00000000
		ldr 	r1, =0x00000000
		ldr 	r2, =0x00000000
		ldr 	r3, =0x00000000
		ldr 	r4, =0x00000000
		ldr 	r5, =0x00000000
		ldr 	r6, =0x00000000
		ldr 	r7, =0x00000000
		ldr		r8, =0x00000000
		ldr 	r9, =led_thread
		
		ldr 	r10, =led_sp
		ldr 	r11, [r10]
		stmfd 	r11!, {r0-r8, r9}
		str 	r11, [r10]
		
		ldr 	r9, =calc_thread

		ldr 	r10, =calc_sp
		ldr 	r11, [r10]
		stmfd 	r11!, {r0-r8, r9}
		str 	r11, [r10]
		
		msr		cpsr_c, #Mode_USR
loop	b	 	loop



led_thread
;GPIO Setup
IO0DIR	equ		0xE0028008
IO0SET	equ		0xE0028004
IO0CLR	equ		0xE002800C
	
		ldr 	r0, =IO0DIR
		ldr 	r1, =0x00260000				; Select P0.17, P0.18, P0.21
		str 	r1, [r0]					; Make them outputs
		ldr 	r0, =IO0SET
		str 	r1, [r0]					; Set them to turn the LEDs off
		ldr 	r1, =IO0CLR
		
; From here, initialisation is finished, so it should be the main body of the main program
		ldr 	r5, =timer
		ldr 	r7, [r5]
		add		r7, r7, #(1000/5)
wh1		ldr 	r2, =leds
		mov 	r4, #8
		ldr 	r3, [r2], #4
		str 	r3, [r1]
dowh1	ldr 	r5, =timer
		ldr 	r6, [r5]
		cmp 	r6, r7
		bcc 	endif4
		mov		r7, r6
		add		r7, r7, #(1000/5)
		str 	r6, [r5]
		sub 	r4, r4, #1
		str 	r3, [r0]
		ldr 	r3, [r2], #4
		str 	r3, [r1]
endif4	cmp 	r4, #0
		bne 	dowh1
		b 		wh1	
; Main program execution will never drop below the statement above.



calc_thread
;Setup GPIO
IO1DIR		equ		0xE0028018
IO1SET		equ		0xE0028014
IO1CLR		equ		0xE002801C
IO1PIN  	equ     0xE0028010
	
; Setup Buttons
incr		equ     20
decr   		equ     21
addit   	equ     22
subtr   	equ     23
clear   	equ     -22
allclear	equ     -23
        
; Setup State Machine States
initial_state   equ     0
getnum_state    equ     1
getop_state     equ     2     

; Setup Calculator Operators
op     	equ     0
op_add 	equ     1
op_sub  equ     2			
	
;Press Times
regpress  	equ     20000    			; Short press time
longpress  	equ     200000  			; Long press time

; Initialise the LEDs
		ldr		r1,	=IO1DIR				;
		ldr		r2,	=0x000f0000			; Select P1.19--P1.16
		str		r2, [r1]				; Set as outputs

clear_all
		mov     r1, #initial_state   	; Set r1 to initial state
		mov     r2, #0                  ; Set all registers to 0
		mov     r3, #0                  ;
		mov     r4, #op              	;
		mov     r0, #0					;
		bl      update_leds         	; Set all LEDS off
	
main_loop
		bl      getbut                 	; Get the next key
		mov     r5, #initial_state		; 
		cmp     r1, r5					; Check if in initial state
		bne     get_number				; If not, get number

		mov     r5, #incr				; 
		cmp     r5, r0           		; If "+" was not pressed
		beq     elseifincr              ; Else branch if it was pressed
		mov     r5, #decr				; If "-" was not pressed
		cmp     r5,r0                  	; Else branch back to the beginning of main_loop 
		bne     main_loop              	;
		sub     r3, #1                  ; x = x - 1
		mov     r0, r3                  ; 
		mov     r1, #getnum_state   	; Change from initial to getnum state
		b       update_leds				; Update LEDS
elseifincr
		add     r3, #1                  ;
		mov     r0, r3					;
		mov     r1, #getnum_state		;
		b       update_leds				;

get_number
		mov     r5, #getnum_state		;
		cmp     r1, r5					;
		bne     get_operator			;

		mov     r5, #incr				;
		cmp     r5, r0					;
		bne     elseifneg0        		;
		add     r3, #1           		;
		mov     r0, r3           		;
		b       update_leds				;
elseifneg0
		mov     r5, #decr				;
		cmp     r5, r0					;
		bne     elseifsub0        		;
		sub     r3, #1					;
		mov     r0, r3					;
		b       update_leds				;
elseifsub0
		mov     r5, #subtr				;
		cmp     r5, r0					;
		bne     elseifadd0        		;
		bl      complete_operation		;
		mov     r4, #op_sub      		;
		mov     r1, #getop_state		;
		b       main_loop				;
elseifadd0
		mov     r5, #addit				;
		cmp     r5, r0					;
		bne     elseifclear0        	;
		bl      complete_operation		;
		mov     r4, #op_add      		;  
		mov     r1, #getop_state		;
		b       main_loop				;
elseifclear0
		mov     r5,#clear				;
		cmp     r5,r0					;
		bne     elseifallclear0        	;
		mov     r3,#0					;
		mov     r0,r3					;
		b       update_leds				;
elseifallclear0
		mov     r5, #allclear			;
		cmp     r5, r0					;
		bne     main_loop      			;
		b       clear_all				;
get_operator
		mov     r5, #getop_state		;
		cmp     r1, r5					;
		bne     main_loop      			;
		mov     r5, #incr				;
		cmp     r5, r0					;
		bne     elseifneg1        		;
		mov     r1,#getnum_state		;
		mov     r3,#0           		;
		mov     r0,r3					;
		b       update_leds				;
elseifneg1
		mov     r5,#decr				;
		cmp     r5,r0					;
		bne     elseifsub1        		;
		mov     r1,#getnum_state		;
		mov     r3,#0           		;
		mov     r0,r3					;
		b       update_leds				;
elseifsub1
		mov     r5,#subtr				;
		cmp     r5,r0					;
		bne     elseifadd1        		;
		mov     r4,#op_sub				;
		b       main_loop				;
elseifadd1
		mov     r5,#addit				;
		cmp     r5,r0					;
		bne     elseifclear1        	;
		mov     r4,#op_add				;
		b       main_loop				;
elseifclear1
		mov     r5,#allclear			;
		cmp     r5,r0					;
		bne     main_loop      			;
		b       clear_all       		;  
stop	b		stop

complete_operation
		stmfd   sp!, {r0, lr}			;
		mov     r0, #op					;
		cmp     r4, r0					;
		bne     elseifadd2				;
		mov     r2, r3					;
		b       elseiferror2			;
elseifadd2   	mov     r0, #op_add		;
		cmp     r4, r0					;
		bne     elseifsub2				;
		add     r2, r3					;
		b       elseiferror2			;
elseifsub2   	mov     r0, #op_sub		;
		cmp     r4, r0					;
		bne     elseiferror2			;
		sub     r2, r3					;
elseiferror2   
		mov	r0, r2						;
		bl	update_leds					;
		ldmfd   sp!, {r0, lr}			;
		bx      lr						;

update_leds 
		stmfd   sp!, {r1-r2, lr}		;
		ldr		r2, =0x000f0000			; Select P1.19--P1.16
		ldr		r1, =IO1SET				;
		str		r2, [r1]				; Set the bit -> turn off the LED
		mov     r2, r0					;
		and     r2, #0xF      			; Remove any carry
		ldr		r1, =revbits			;
		add		r1, r2					;
		ldr		r2, [r1]				;
		mov		r2, r2, lsl #16        	;
		ldr		r1, =IO1CLR				;
		str     r2, [r1]         		; Clear the bit -> turn on the LED
		ldmfd   sp!, {r1-r2, lr}		;
		bx      lr						;

getbut  		
		stmfd	sp!, {r1-r8, lr}		;
		ldr     r1, =0x00f00000 		; Mask all keys
		ldr     r2, =IO1PIN     		;
		ldr     r8, =regpress			; Checks if the button was pressed for a short time
nobutpress  							;
		mov     r3, #0          		; Number of keys pressed
checkallbuts0							;
		ldr     r4, =buts				;
		mov     r5, #4					; Number of buttons
		ldr     r6, [r2]				;
		and     r6, r6, r1      		; Mask everything except for buttons
checkallbuts1							;
		ldr     r7, [r4]				;
		add     r4, #8          		; Check next button
		cmp     r6, r7          		; 
		beq     countpress          	;
		subs    r5, #1					;
		bne     checkallbuts1    		; Check if any other buttons were pressed
		b       nobutpress      		; Return if no button was pressed
countpress								;
		add     r3, #1					;
		cmp     r3, r8           		; Checks if the button was pressed for long enough
		bne     checkallbuts0			;
		sub     r4, #4           		; Point to Index
		ldr     r0,[r4]        	 		; Load index into R0
		ldr     r5, =longpress			;
keepcounting0  							;
		mov     r4, #0					;
keepcounting1							;
		ldr     r6,[r2]					;
		and     r6, r6, r1        		; Mask everything except for buttons
		cmp     r6, r7           		; 
		bne     endif0          		; 
		cmp     r3, r5           		; Check if its a long press
		beq		endif1					;
		add   	r3, #1           		; Keep counting otherwise...
endif1	b       keepcounting0      		; Keep counting...
endif0  cmp     r6, r1           		; 
		bne     nobutpress      		; Start again
		add     r4, #1           		;       
		cmp     r4, r8           		; Check if reg time has elapsed
		bne     keepcounting1       	; Keep counting...
		cmp     r3, r5           		;
		bne     endif2					;
		rsb     r0, #0           		;
endif2  ldmfd	sp!, {r1-r8, lr}		;
		bx      lr						;



		AREA	InterruptStuff, CODE, READONLY	
irqhan	sub		lr, lr, #4				
; this is the body of the interrupt handler
		
; here you'd put the unique part of your interrupt handler
; all the other stuff is "housekeeping" to save registers and acknowledge interrupts

; Increment Timer for LED Thread
		ldr		r9, =timer
		ldr		r10, [r9]
		add		r10, r10, #1
		str		r10, [r9]
		cmp		r10, #1
		beq		else00
		
; Swap Thread and Load in Registers and Address of Other Thread
		ldr		r9, =thread
		ldr		r10, [r9]
		cmp		r10, #0
		bne		else11
		ldr		r11, =led_sp
		ldr 	r12, [r11]
		stmfd 	r12!, {r0-r8, lr}
		str 	r12, [r11]
		ldr		r11, =calc_sp
		ldr 	r12, [r11]
		ldmfd 	r12!, {r0-r8, lr}
		str 	r12, [r11]
		ldr		sp, [r11]
		stmfd	sp!, {lr}					; the lr will be restored to the pc
		ldr		r10, =1
		b 		endif11
else11	ldr		r11, =calc_sp
		ldr 	r12, [r11]
		stmfd 	r12!, {r0-r8, lr}
		str 	r12, [r11]
		ldr		r11, =led_sp
		ldr 	r12, [r11]
		ldmfd 	r12!, {r0-r8, lr}
		str 	r12, [r11]
		ldr		sp, [r11]
		stmfd	sp!, {lr}					; the lr will be restored to the pc			
		ldr 	r10, =0
endif11	str		r10, [r9]
		b		endif00
else00	ldr		r9, =thread
		ldr 	r10, =1
		str		r10, [r9]
		ldr		r11, =calc_sp
		ldr 	r12, [r11]
		ldmfd 	r12!, {r0-r8, lr}
		str 	r12, [r11]
		ldr		sp, [r11]
		stmfd	sp!, {lr}					; the lr will be restored to the pc	
endif00		
		
; this is where we stop the timer from making the interrupt request to the VIC
; i.e. we 'acknowledge' the interrupt

		ldr 	r9, =T0
		mov 	r10, #TimerResetTimer0Interrupt
		str 	r10, [r9, #IR]	   			; remove MR0 interrupt request from timer

; here we stop the VIC from making the interrupt request to the CPU:
		ldr 	r9, =VIC
		mov 	r10, #0
		str 	r10, [r9, #VectAddr]		; reset VIC
		ldmfd  	sp!, {pc}^			
		


		AREA 	LEDS, DATA, READONLY
leds	dcd		0x00000000
		dcd 	0x00020000
		dcd 	0x00200000
		dcd 	0x00040000
		dcd 	0x00220000
		dcd 	0x00060000
		dcd 	0x00240000
		dcd 	0x00260000
		
		
		
		AREA	CALC, DATA, READONLY
revbits	dcb		0x0     				; 0
		dcb		0x8						; 1
		dcb		0x4						; 2
		dcb		0xc						; 3
		dcb		0x2						; 4
		dcb		0xa						; 5
		dcb		0x6						; 6
		dcb		0xe						; 7
		dcb		0x1						; 8
		dcb		0x9						; 9
		dcb		0x5						; A
		dcb		0xd						; B
		dcb		0x3						; C
		dcb		0xb						; D
		dcb		0x7						; E
		dcb		0xf						; F
		
buts	dcd		0x00700000, 23			; 0111
		dcd		0x00B00000, 22			; 1011
		dcd		0x00D00000, 21			; 1101
		dcd		0x00E00000, 20			; 1110



		AREA 	INTERRUPT, DATA, READWRITE
thread	dcd 	0x00000000
led_sp 	dcd 	0x40002048
calc_sp	dcd 	0x40001024
timer	dcd 	0x00000000



		END
		
		
		
/*		
; Interrupt PIO Setup
IO1DIR	equ		0xE0028018
IO1SET	equ		0xE0028014
IO1CLR	equ		0xE002801C
	
		ldr		r0, =IO1DIR
		ldr		r1, =0x000f0000					;select P1.19--P1.16
		str		r1, [r0]						;make them outputs
		ldr 	r0, =IO1SET
		str 	r1, [r0]						; Set them to turn the LEDs off
		ldr 	r1, =IO1CLR
*/

/*
; Interrupt test code
		ldr		r10, =IO1SET
		ldr		r11, =IO1CLR
		
		mov		r9, r9, lsl #16
		str 	r9, [r11]
		
		ldr 	r12, =40000  				;new time variable added to show that the code is unique.
wh4		subs 	r12, r12, #1
		bne		wh4
		
		str		r9, [r10]
		mov		r9, r9, lsr #16
;End Test
*/

/*
; Practical 1 & Stack
;IO1DIR	equ		0xE0028018
;IO1SET	equ		0xE0028014
;IO1CLR	equ		0xE002801C

		;ldr	r1, =IO1DIR
		;ldr	r2, =0x000f0000				;select P1.19--P1.16
		;str	r2, [r1]					;make them outputs
		ldr		r1, =IO1SET
		;str	r2, [r1]					;set them to turn the LEDs off
		ldr		r2, =IO1CLR

; r1 points to the SET register
; r2 points to the CLEAR register

		ldr		r5,=0x00100000				; end when the mask reaches this value
wloop	ldr		r3,=0x00010000				; start with P1.16.
floop	str		r3,[r2]	   					; clear the bit -> turn on the LED
		
		;delay for about a half second
		stmfd 	sp!, {r3}
		ldr 	r3, =4000000  				;new time variable added to show that the code is unique.
dloop	subs 	r3, r3, #1
		bne		dloop
		ldmfd 	sp!, {r3}

		str		r3, [r1]					;set the bit -> turn off the LED
		mov		r3, r3, lsl #1				;shift up to next bit. P1.16 -> P1.17 etc.
		cmp		r3, r5
		bne		floop
		b		wloop
*/