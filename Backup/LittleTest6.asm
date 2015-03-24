;====================================================================================================
;    LittleTest PIC12F1822 sample project
;
;    History:
; LittleTest6   3/23/2015     Interupt-On-Change, reading a quadrature encoder.
; LittleTest5   3/16/2015     The stepper is moving fast.
; LittleTest4   3/2/2015	The beginnings of motion control.
; LittleTest3   2/23/2015	Using the CCP to output pulses
; LittleTest2   2/16/2015	ISR blinking LED
; LittleTest1   2/9/2015	A blinking LED
;
;====================================================================================================
;====================================================================================================
;
;  Pin 1 VDD (+5V)		+5V
;  Pin 2 RA5		Direction Reverse LED
;  Pin 3 RA4		System LED Active High
;  Pin 4 RA3/MCLR*/Vpp (Input only)	Vpp
;  Pin 5 RA2		Direction Forward LED
;  Pin 6 RA1/ICSPCLK		ICSPCLK, A
;  Pin 7 RA0/ICSPDAT		ICSPDAT, B
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
;
	endc
;
;
LED_Time	EQU	.100
;
#Define	FWD_Flag	Flags,0
FWD_Bit	EQU	0
#Define	REV_Flag	Flags,1
REV_Bit	EQU	1
;
#Define	LED_Bit	LATA,4
#Define	Quad_A	PORTA,1
#Define	Quad_B	PORTA,0
#Define	LED_Forward	LATA,2
#Define	LED_Reverse	LATA,5
;
Param70	EQU	0x70
Param71	EQU	0x71
ISRScratch	EQU	0x72
#Define	myByte	Param70
#Define	_C	0x03,C

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
;------------------------------------------
;
ISR_IOC:
	BANKSEL	IOCAF
	BTFSS	IOCAF,IOCAF1
	GOTO	ISR_IOC_End
;
	BCF	IOCAF,IOCAF1
	BANKSEL	PORTA
	BTFSS	Quad_B
	GOTO	ISR_IOC_DoFWD
	BCF	FWD_Flag
	BSF	REV_Flag
	GOTO	ISR_IOC_End
;
ISR_IOC_DoFWD	BSF	FWD_Flag
	BCF	REV_Flag
;
ISR_IOC_End:
;
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
	MOVLW	B'11001011'
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
;
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
;	MOVLW	CCP1CON_Run
;	MOVWF	CCP1CON
;	
	BANKSEL	PIE1	;Enable Interupts
	BSF	PIE1,TMR2IE
;	bsf	PIE1,CCP1IE
;------------------------
; Enable Interupt-On-Change
;
	BANKSEL	IOCAP
	BSF	IOCAP,IOCAP1
	BSF	INTCON,IOCIE
;-----------------------
	BSF	INTCON,PEIE
	BSF	INTCON,GIE
;
;
MainLoop	CLRWDT
	BANKSEL	Flags
	MOVF	Flags,W
	BANKSEL	LATA
	BTFSS	WREG,FWD_Bit
	BCF	LED_Forward
	BTFSC	WREG,FWD_Bit
	BSF	LED_Forward
	
	BTFSS	WREG,REV_Bit
	BCF	LED_Reverse
	BTFSC	WREG,REV_Bit
	BSF	LED_Reverse
;
;
;
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
;	include	StepperLib.inc
;
	END
;
	