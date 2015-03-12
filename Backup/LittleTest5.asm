;====================================================================================================
;    LittleTest PIC12F1822 sample project
;
;    History:
;
; LittleTest4   3/2/2015	The beginnings of motion control.
; LittleTest3   2/23/2015	Using the CCP to output pulses
; LittleTest2   2/16/2015	ISR blinking LED
; LittleTest1   2/9/2015	A blinking LED
;
;====================================================================================================
;====================================================================================================
;
;  Pin 1 VDD (+5V)		+5V
;  Pin 2 RA5		CCP1/Step
;  Pin 3 RA4		System LED Active High
;  Pin 4 RA3/MCLR*/Vpp (Input only)	Vpp
;  Pin 5 RA2		Direction
;  Pin 6 RA1/ICSPCLK		ICSPCLK
;  Pin 7 RA0/ICSPDAT		ICSPDAT
;  Pin 8 VSS (Ground)		Ground
;
;====================================================================================================
;
	list	p=12f1822,r=hex,w=0	; list directive to define processor
;
	nolist
	include	p12f1822.inc	; processor specific variable definitions
	list
;
	__CONFIG _CONFIG1,_FOSC_INTOSC & _WDTE_ON & _MCLRE_OFF & _IESO_OFF
;
;
;
; INTOSC oscillator: I/O function on CLKIN pin
; WDT enabled
; PWRT disabled
; MCLR/VPP pin function is digital input
; Program memory code protection is disabled
; Data memory code protection is disabled
; Brown-out Reset enabled
; CLKOUT function is disabled. I/O or oscillator function on the CLKOUT pin
; Internal/External Switchover mode is disabled
; Fail-Safe Clock Monitor is enabled
;
	__CONFIG _CONFIG2,_WRT_OFF & _PLLEN_ON & _LVP_OFF
;
; Write protection off
; 4x PLL disabled
; Stack Overflow or Underflow will cause a Reset
; Brown-out Reset Voltage (Vbor), low trip point selected.
; Low-voltage programming Disabled ( allow MCLR to be digital in )
;  *** must set apply Vdd before Vpp in ICD 3 settings ***
;
; '__CONFIG' directive is used to embed configuration data within .asm file.
; The lables following the directive are located in the respective .inc file.
; See respective data sheet for additional information on configuration word.
;
;OSCCON_Value	EQU	b'01110010'	;8MHz
OSCCON_Value	EQU	b'11110000'	;32MHz
;T2CON_Value	EQU	b'01001110'	;T2 On, /16 pre, /10 post
T2CON_Value	EQU	b'01001111'	;T2 On, /64 pre, /10 post
PR2_Value	EQU	.125
;
; 0.5uS res counter from 8MHz OSC
CCP1CON_Run	EQU	b'00001010'	;interupt but don't change the pin
CCP1CON_Clr	EQU	b'00001001'	;Clear output on match
CCP1CON_Set	EQU	b'00001000'	;Set output on match
;T1CON_Val	EQU	b'00000001'	;PreScale=1,Fosc/4,Timer ON
T1CON_Val	EQU	b'00100001'	;PreScale=4,Fosc/4,Timer ON
;
CCP1CON_Value	EQU	0x00	;CCP1 off
;
	cblock	0x20
;
	LED_Count
;
	Timer1Lo		;1st 16 bit timer
	Timer1Hi		; one second RX timeiout
;
	Timer2Lo		;2nd 16 bit timer
	Timer2Hi		;
;
	Timer3Lo		;3rd 16 bit timer
	Timer3Hi		;GP wait timer
;
	Timer4Lo		;4th 16 bit timer
	Timer4Hi		; debounce timer
;
	Flags
;
; Stepper Driver Variables
	MotorFlagsX
	MinSpeedX
	MaxSpeedX
	CurSpeedX
	StepsToGoXLo
	StepsToGoXHi
	CurrentPositionX:2
;
	endc
;MotorFlags Bits
InMotion	EQU	0	;Set while motor is moving
InPosition	EQU	1	;Set when move is done, clear to start move
RevDirection	EQU	2	;Clr to got forward, Set to go reverse dir
;
#Define	StartedIt	Flags,0
;
LED_Time	EQU	.100
#Define	Dir_Bit	LATA,2	
#Define	LED_Bit	LATA,4
#Define	Step_Bit	LATA,5
Param70	EQU	0x70
Param71	EQU	0x71
ISRScratch	EQU	0x72
#Define	myByte	Param70
#Define	_C	0x03,C
kStepTime	EQU	.500

	ORG	0x0000	;Reset Vector
	goto	Start
	
;****************************************************************
	ORG	0x0004	;ISR
	MOVLB	0
; Timer 2
	BTFSS	PIR1,TMR2IF
	GOTO	TMR2_End
;Decrement timers until they are zero
; 
	call	DecTimer1	;if timer 1 is not zero decrement
; 
	call	DecTimer2
; GP, Wait loop timer
	call	DecTimer3
; 
	call	DecTimer4
;
	BANKSEL	LATA
	BCF	LED_Bit
	MOVLB	0
	DECFSZ	LED_Count,F
	GOTO	TMR2_Done
	MOVLW	LED_Time
	MOVWF	LED_Count
	BANKSEL	LATA
	BSF	LED_Bit
	
	MOVLB	0
TMR2_Done	BCF	PIR1,TMR2IF
TMR2_End:
;
;===========================================
;
IRQ_MotorMove	MOVLB	0	;bank 0
	BTFSS	PIR1,CCP1IF	;CCP1 match?
	GOTO	IRQ_MotorMove_End	; No
			; Yes, it's time...
	BTFSS	MotorFlagsX,InMotion	;Did we just move?
	GOTO	IRQ_MM_NoMove	; No
	MOVLW	0x01
	BTFSS	MotorFlagsX,RevDirection	;Moving Reverse?
	GOTO	IRQ_MM_Fwd	; No
; Decrement the position	
	SUBWF	CurrentPositionX,F	; Yes, Dec pos
	CLRW
	SUBWFB	CurrentPositionX+1,F
	GOTO	IRQ_MM_StepsToGo
; Increment the position
IRQ_MM_Fwd	ADDWF	CurrentPositionX,F
	CLRW
	ADDWFC	CurrentPositionX+1,F
;
IRQ_MM_StepsToGo:
; Decrement step counter
	MOVLW	StepsToGoXHi
	CALL	DecTimer
	MOVF	StepsToGoXHi,W
	IORWF	StepsToGoXLo,W
	SKPNZ		;Was that the last step?
	BSF	MotorFlagsX,InPosition	; Yes, move done
;
;	
IRQ_MM_NoMove:
	BANKSEL	CCP1CON
	CLRF	CCP1CON	;reset the CCP
;
	BANKSEL	LATA
	BCF	Step_Bit	;output off
;
	BANKSEL	CCP1CON
; set the time for the next step
	MOVLW	CurSpeedX
	MOVWF	FSR1L
	CLRF	FSR1H
	MOVF	INDF1,W
	CALL	GetStepTimeHi
	MOVWF	ISRScratch
	MOVF	INDF1,W
	CALL	GetStepTimeLo
	ADDWF	CCPR1L,F
	MOVF	ISRScratch,W
	ADDWFC	CCPR1H,F
;
;If InPosition then Idle else Pulse next cylcle
	MOVLW	MotorFlagsX
	MOVWF	FSR1L
	BTFSC	INDF1,InPosition	;InPosition?
	GOTO	IRQ_MotorMove_1	; Yes
	MOVLW	CCP1CON_Set	; No, we are moving
	BSF	INDF1,InMotion	;This cycle will output a pulse
	GOTO	IRQ_MotorMove_2
;
IRQ_MotorMove_1	MOVLW	CCP1CON_Run	;Idle the CCP w/o pulses
	BCF	INDF1,InMotion	;Not moving
IRQ_MotorMove_2	MOVWF	CCP1CON
;
;	
	BANKSEL	MotorFlagsX		
	BTFSS	MotorFlagsX,InMotion	;Moving?
	GOTO	IRQ_MM_GoSlow	; No
; Calculate time of next step
	BTFSC	MotorFlagsX,InPosition	;Last Step
	GOTO	IRQ_MM_GoSlow	; Yes, set slowest speed
	MOVF	StepsToGoXHi,F
	SKPZ		;>= 256 steps to go?
	GOTO	IRQ_MM_IncSpd
;
; if StepsToGoXLo>(CurSpeedX-MinSpeedX) then IRQ_MM_IncSpd else IRQ_MM_DecSpd
	MOVF	MinSpeedX,W
	SUBWF	CurSpeedX,W	;W=CurSpeedX-MinSpeedX
	MOVWF	ISRScratch
	MOVF	StepsToGoXLo,W
	SUBWF	CurSpeedX,W	;W=CurSpeedX-StepsToGoXLo
	BTFSS	STATUS,C	;StepsToGoXLo>=CurSpeedX?
	GOTO	IRQ_MM_IncSpd	; Yes
;
IRQ_MM_DecSpd	MOVF	CurSpeedX,W
	SUBWF	MinSpeedX,W
	SKPZ		;At slowest?
	DECF	CurSpeedX,F	; No, go slower
	GOTO	IRQ_MotorMove_3	
;	
IRQ_MM_IncSpd	MOVF	MaxSpeedX,W
	SUBWF	CurSpeedX,W
	SKPZ		;MaxSpeedX=CurSpeedX?
	INCF	CurSpeedX,F	; No, CurSpeedX++
	GOTO	IRQ_MotorMove_3
;
IRQ_MM_GoSlow	MOVF	MinSpeedX,W
	MOVWF	CurSpeedX
;	
IRQ_MotorMove_3	BCF	PIR1,CCP1IF
IRQ_MotorMove_End:
;
	RETFIE
;
;*******************************************************************
;
;*******************************************************************
;	
Start:
	CLRWDT
	BANKSEL	OSCCON	;Setup OSC
	MOVLW	OSCCON_Value
	MOVWF	OSCCON
	
	BANKSEL	T2CON	;Setup T2 for 100/s
	MOVLW	T2CON_Value
	MOVWF	T2CON
	BANKSEL	PR2
	MOVLW	PR2_Value
	MOVWF	PR2
	
	MOVLB	0x00	;Setup Port A
	MOVLW	0x10
	MOVWF	PORTA
	MOVLB	0x03
	CLRF	ANSELA
	MOVLB	0x01
	MOVLW	B'00001011'
	MOVWF	TRISA
;
;-----------------------------------------
; Init RAM
;
; wait 5 seconds before doing anything
	BANKSEL	Timer4Hi
	MOVLW	Low .500
	MOVWF	Timer4Lo
	MOVLW	High .500
	MOVWF	Timer4Hi
; init flags (boolean variables) to false
	CLRF	Flags
; init motor variables
	CLRF	MotorFlagsX
	BSF	MotorFlagsX,InPosition	;Don't move
;
	CLRF	MaxSpeedX
	CLRF	MinSpeedX
	CLRF	CurSpeedX
	CLRF	StepsToGoXLo
	CLRF	StepsToGoXHi
;
;---------------------------------------------
; setup timer 1 for 0.5uS/count
;
	BANKSEL	T1CON	; bank 0
	MOVLW	T1CON_Val
	MOVWF	T1CON
	bcf	T1GCON,TMR1GE
; Setup ccp1
	BANKSEL	APFCON
	BSF	APFCON,CCP1SEL	;RA5
	BANKSEL	CCP1CON
	CLRF	CCP1CON
	MOVLW	CCP1CON_Run
	MOVWF	CCP1CON
;	
	BANKSEL	PIE1	;Enable Interupts
	BSF	PIE1,TMR2IE
	bsf	PIE1,CCP1IE
;
	BSF	INTCON,PEIE
	BSF	INTCON,GIE
;
;
MainLoop	CLRWDT
;
	BANKSEL	Timer4Hi
	MOVF	Timer4Hi,W
	IORWF	Timer4Lo,W
	SKPZ
	GOTO	NOTZERO
;
	BTFSC	StartedIt
	GOTO	AlreadyDid
	BSF	StartedIt
; Start a 1 inch (2000 steps) move max speed = a46 (87.8 in/min)
;	MOVLW	.95	;195.4 in/min good
;	MOVLW	.102	;a102 209.8 in/min
	MOVLW	.95
	MOVWF	MaxSpeedX
DoItAgain	MOVLW	Low .6000
	MOVWF	StepsToGoXLo
	MOVLW	High .6000
	MOVWF	StepsToGoXHi
	BCF	MotorFlagsX,InPosition	;move it
;
;
AlreadyDid:
	BTFSS	MotorFlagsX,InPosition	;there yet?
	GOTO	NotYet
	BANKSEL	LATA
	MOVLW	0x04
	XORWF	LATA,F
	MOVLW	MotorFlagsX
	MOVWF	FSR0L
	CLRF	FSR0H
	BCF	INDF0,RevDirection
	BTFSC	Dir_Bit
	BSF	INDF0,RevDirection
;
	MOVLB	0x00
	BCF	StartedIt
	MOVLW	.200
	MOVWF	Timer4Lo
;
NotYet:
NOTZERO:
	goto	MainLoop
	
;=========================================================================================================
; Decrement routine for 16 bit timers
;
DecTimer4	movlw	Timer4Hi
	goto	DecTimer
DecTimer3	movlw	Timer3Hi
	goto	DecTimer
DecTimer2	movlw	Timer2Hi
	goto	DecTimer
DecTimer1	movlw	Timer1Hi
;DecTimer
; entry: FSR=Timer(n)Hi
DecTimer	MOVWF	FSR0
	MOVIW	FSR0--	;TimerNHi
	IORWF	INDF0,W	;TimerNLo
	SKPNZ
	RETURN
	MOVLW	0x01
	SUBWF	INDF0,F	;TimerNLo
	INCF	FSR0,F
	MOVLW	0x00
	SUBWFB	INDF0,F	;TimerNHi
	RETURN
;
	include	StepperLib.inc
;
	END
;
	