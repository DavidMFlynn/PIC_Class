;====================================================================================================
;
;    Filename:      uLEDTest.asm
;    Date:          4/1/2015
;    File Version:  1.0
;
;    Author:        David M. Flynn
;    Company:       Oxford V.U.E., Inc.
;    E-Mail:        dflynn@oxfordvue.com
;    Web Site:      http://www.oxfordvue.com/
;
;====================================================================================================
;    History:
;
; 1.0   4/1/2015	Simple LED blinker. This program sets all pins to outputs and makes them blink.
;	Every pin except RA5 which is an input only pin blinks.
;
;====================================================================================================
;====================================================================================================
;
;   Pin 1 (RA2/AN2) 
;   Pin 2 (RA3/AN3) 
;   Pin 3 (RA4/AN4) 
;   Pin 4 (RA5/MCLR*) 
;   Pin 5 (GND) Ground
;   Pin 6 (RB0) 
;   Pin 7 (RB1/AN11/SDA1) 
;   Pin 8 (RB2/AN10/RX) 
;   Pin 9 (RB3/CCP1) 
;
;   Pin 10 (RB4/AN8/SLC1) 
;   Pin 11 (RB5/AN7) 
;   Pin 12 (RB6/AN5/CCP2)
;   Pin 13 (RB7/AN6)
;   Pin 14 (Vcc) +5 volts
;   Pin 15 (RA6)
;   Pin 16 (RA7) 
;   Pin 17 (RA0)
;   Pin 18 (RA1)
;
;====================================================================================================
;
;
	list	p=16f1847,r=hex,W=0	; list directive to define processor
	nolist
	include	p16f1847.inc	; processor specific variable definitions
	list
;
	__CONFIG _CONFIG1,_FOSC_INTOSC & _WDTE_OFF & _MCLRE_OFF & _IESO_OFF
;
;
; INTOSC oscillator: I/O function on CLKIN pin
; WDT disabled
; PWRT disabled
; MCLR/VPP pin function is digital input
; Program memory code protection is disabled
; Data memory code protection is disabled
; Brown-out Reset enabled
; CLKOUT function is disabled. I/O or oscillator function on the CLKOUT pin
; Internal/External Switchover mode is disabled
; Fail-Safe Clock Monitor is enabled
;
	__CONFIG _CONFIG2,_WRT_OFF & _PLLEN_OFF & _LVP_OFF
;
; Write protection off
; 4x PLL disabled
; Stack Overflow or Underflow will cause a Reset
; Brown-out Reset Voltage (Vbor), low trip point selected.
; Low-voltage programming enabled
;
; '__CONFIG' directive is used to embed configuration data within .asm file.
; The lables following the directive are located in the respective .inc file.
; See respective data sheet for additional information on configuration word.
;
	constant	oldCode=0
	constant	useRS232=0
;
#Define	_C	STATUS,C
#Define	_Z	STATUS,Z
;========================================================================================
;================================================================================================
;***** VARIABLE DEFINITIONS
; there are 256 bytes of ram, Bank0 0x20..0x7F, Bank1 0xA0..0xEF, Bank2 0x120..0x16F
; there are 256 bytes of EEPROM starting at 0x00 the EEPROM is not mapped into memory but
;  accessed through the EEADR and EEDATA registers
;================================================================================================
;  Bank0 Ram 020h-06Fh 80 Bytes
;
Bank0_Vars	udata	0x20 
;
;
;=======================================================================================================
;  Common Ram 70-7F same for all banks
;      except for ISR_W_Temp these are used for paramiter passing and temp vars
;=======================================================================================================
;
	cblock	0x70
	Param70
	Param71
	Param72
	Param73
	Param74
	Param75
	Param76
	Param77
	Param78
	Param79
	Param7A
	Param7B
	Param7C
	Param7D
	Param7E
	Param7F
	endc
;
;==============================================================================================
;============================================================================================
;
;
	ORG	0x000	; processor reset vector
	CLRF	STATUS
	CLRF	PCLATH
  	goto	start	; go to beginning of program
;
;===============================================================================================
; Interupt Service Routine
;
; we loop through the interupt service routing every 0.008192 seconds
;
;
	ORG	0x004	; interrupt vector location
	CLRF	BSR	; bank0
;
;
;-----------------------------------------------------------------
;
	retfie		; return from interrupt
;
;
;==============================================================================================
;==============================================================================================
;
start	MOVLB	0x01	; select bank 1
	bsf	OPTION_REG,NOT_WPUEN	; disable pullups on port B
	bcf	OPTION_REG,TMR0CS	; TMR0 clock Fosc/4
	bcf	OPTION_REG,PSA	; prescaler assigned to TMR0
	bsf	OPTION_REG,PS0	;111 8mhz/4/256=7812.5hz=128uS/Ct=0.032768S/ISR
	bsf	OPTION_REG,PS1	;101 8mhz/4/64=31250hz=32uS/Ct=0.008192S/ISR
	bsf	OPTION_REG,PS2
;
	MOVLB	0x01	; bank 1
	MOVLW	b'01110000'
	MOVWF	OSCCON
	movlw	b'00010111'	; WDT prescaler 1:65536 period is 2 sec (RESET value)
	movwf	WDTCON 	
;	
	MOVLB	0x03	; bank 3
	CLRF	ANSELA	;Digital I/O
	CLRF	ANSELB	;Digital I/O
;
	MOVLB	0x00	;Bank 0
; setup data ports
	MOVLW	0xFF
	MOVWF	PORTB	;init port B
	MOVWF	PORTA
	MOVLB	0x01	; bank 1
	CLRF	TRISA
	CLRF	TRISB
;
	MOVLB	0x02
;
;=========================================================================================
;=========================================================================================
;  Main Loop
;
;=========================================================================================
MainLoop	CLRWDT
;
	MOVLW	0xFF
	XORWF	LATA,F
	XORWF	LATB,F
;
Loop1	NOP
	DECFSZ	Param78,F
	GOTO	Loop1
	DECFSZ	Param79,F
	GOTO	Loop1
;
	goto	MainLoop
;
;=========================================================================================
;=========================================================================================

;
;
	END
;
