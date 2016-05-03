;=========================================================================================
; PIC12F1822/PIC16F1847
; I2C MASTER DRIVER CODE
;
;    Filename:      I2C MASTER.inc
;    Date:          1/9/2016
;    File Version:  1.0.10
;
;    Author:        David M. Flynn
;    Company:       Oxford V.U.E., Inc.
;    E-Mail:        dflynn@oxfordvue.com
;    Web Site:      http://www.oxfordvue.com/
;
;=========================================================================================
;   I2C Master Driver Code for PIC12F1822/PIC16F1847
;
;    History:
;
; 1.0.10  1/9/2016	Fixed race condition in address to receive transition.
; 1.0.9  12/30/2015	First fully functioning multi-master version. Last known bugs are gone.
; 1.0.8  12/21/2015	Added stop if slave address in NACK'd, SSP1CON2,ACKSTAT
; 1.0.7  12/15/2015	Moving toward multi-slaves
; 1.0.6  12/5/2015	Fixed a bug RX_ELEMENTS was used in place of TX_ELEMENTS
; 1.0.5  11/9/2015	Added watchdog to recover from wiring glitch.
; 1.0.4  11/4/2015	Bug fixes.
; 1.0.3  9/7/2015	Added multi-Slave.
; 1.0.2  4/25/2015	First woring version, single master to single slave, no error checking.
; 1.0.1  9/4/2014	Modified for 12F1822
; 1.0   11/23/2013	Adapted from AN734C
;
; Known issues:
;
;=========================================================================================
; Options
;
;   I2C_ADDRESS, TX_ELEMENTS and RX_ELEMENTS must be set and be the same in the slave driver.
;
;
	ifndef useI2CWDT
	constant	useI2CWDT=0
	endif
;=========================================================================================
;=========================================================================================
; What happens next:
;  Sends and receives TX_ELEMENTS/RX_ELEMENTS bytes of data to/from the slave
;
;INITIALIZE_I2C
; start write seq.	Set I2C_Write_Seq_Active, I2C_Init_Start, I2C_Addr_Pending, INDEX_I2C=0
;Idle_I2C
; set start bit	clr I2C_Init_Start
;I2C_WRITE
; send address	clr I2C_Addr_Pending set I2C_INIT_TRANS_DATA
;Idle_I2C
; 	clr I2C_INIT_TRANS_DATA set I2C_TRANS_DATA, I2C_TXLocked
;I2C_WRITE
; send I2C_ARRAY_TX,INDEX_I2C++ until TX_ELEMENTS bytes sent
;	clr I2C_TRANS_DATA set I2C_TRANS_COMPLETE
;Idle_I2C
; send stop bit	clr I2C_TRANS_COMPLETE set I2C_Stop_Asserted
;I2C_WRITE
; 	clr I2C_Write_Seq_Active, I2C_Stop_Asserted, I2C_TXLocked
;
;Idle_I2C
; start read seq.	set I2C_Read_Seq_Active, I2C_Addr_Pending, I2C_Init_Start
;Idle_I2C
; send start bit	clr I2C_Init_Start
;I2C_READ
; send address	clr I2C_Addr_Pending set I2C_INIT_MSTR_REC
;Idle_I2C
; 	clr I2C_INIT_MSTR_REC set I2C_SET_RCEN, I2C_RXLocked, INDEX_I2C=0
;
;I2C_READ
; enable receive	clr I2C_SET_RCEN set I2C_REC_BYTE
;I2C_READ
; read byte	clr I2C_REC_BYTE set I2C_SET_ACKEN
;Idle_I2C
; sent ack	clr I2C_SET_ACKEN, INDEX_I2C++
;	if INDEX_I2C<RX_ELEMENTS then set I2C_SET_RCEN else set I2C_Recd_All
;
;I2C_READ
; 	clr I2C_Recd_All, I2C_RXLocked set I2C_NewRXData, I2C_REC_COMPLETE
;Idle_I2C
; send stop	clr I2C_REC_COMPLETE set I2C_Stop_Asserted
;I2C_READ
; 	clr I2C_Stop_Asserted, I2C_Read_Seq_Active
;
;Idle_I2C
;	call I2C_Start_Write_Seq or I2C_Start_Read_Seq
;=========================================================================================
; Routines:	
;
; Init_I2C	initial setup, call once before starting main event loop
; Idle_I2C	Sequence control, call from main event loop
; I2C_WRITE	called by ISR to handle interupts while writing to slave
; I2C_READ	called by ISR to handle interupts while reading from slave
;
;=========================================================================================
;
;I2C_SlaveCount	EQU	.3
;I2C_ActiveSlaves	EQU	.2
;TX_ELEMENTS30	EQU	.8
;RX_ELEMENTS30	EQU	.8	; number of allowable array elements
;TX_ELEMENTS32	EQU	.8
;RX_ELEMENTS32	EQU	.8	; number of allowable array elements
;TX_ELEMENTS34	EQU	.8
;RX_ELEMENTS34	EQU	.8	; number of allowable array elements
;Note: only upper 7 bits of address are used
;I2C_ADDRESS	EQU	0x30	; slave address
;BRG_VAL	EQU	0x27	; baud rate setting = 100kHz
;I2C_TX_Init_Val	EQU	0xAA	; value to load into transmit array to send to master
;I2C_RX_Init_Val	EQU	0xAA	; value to load into received data array
;
;
;------------------------------------ variables-------------------------------------------
;	Bank 0 Vars
	cblock	0x68
	I2C_Slave_Idx		;0..I2C_SlaveCount-1
	I2C_Temp		;temp var
	INDEX_I2C		; index used to point to array location
;			;   0..RX_ELEMENTS-1	
	I2C_GFlags
	I2C_GFlags2
	endc
;
#Define	I2C_SET_ACKEN	I2C_GFlags,0	; sets up acknowledge sequence
#Define	I2C_Init_Start	I2C_GFlags,1	; used to set bit for start sequence
#Define	I2C_Write_Seq_Active	I2C_GFlags,2	; used for write sequence
#Define	I2C_Stop_Asserted	I2C_GFlags,3	; used to set bit for stop sequence
#Define	I2C_Addr_Pending	I2C_GFlags,4	; bit sets up address transmission
#Define	I2C_INIT_TRANS_DATA	I2C_GFlags,5	; bit sets up data transmission
#Define	I2C_TRANS_DATA	I2C_GFlags,6	; used to monitor transmission
#Define	I2C_TRANS_COMPLETE	I2C_GFlags,7	; set when transmission is complete
#Define	I2C_REC_COMPLETE	I2C_GFlags2,0	; set when reception is complete
#Define	I2C_Read_Seq_Active	I2C_GFlags2,1	; used for read sequence
#Define	I2C_INIT_MSTR_REC	I2C_GFlags2,2	; initializes reception
#Define	I2C_SET_RCEN	I2C_GFlags2,3	; initializes RCEN bit to receive data
#Define	I2C_REC_BYTE	I2C_GFlags2,4	; sets up receive byte sequence
#Define	I2C_Recd_All	I2C_GFlags2,5	; Set when all bytes heve been rec'd waiting for ack before stop
;
	if useI2CWDT
TimerI2C	EQU	Timer1Lo
	endif
;
;	cblock	0xA0
;	I2C_SlaveFlags:I2C_SlaveCount
;	I2C_BytesToRec:I2C_SlaveCount
;	I2C_BytesToSend:I2C_SlaveCount
;	I2C_RX_BuffPtr:I2C_SlaveCount*2
;	I2C_TX_BuffPtr:I2C_SlaveCount*2
;
;I2C_Buffers	
;	I2C_ARRAY_RX30:RX_ELEMENTS	; array to receive from master
;	I2C_ARRAY_TX30:TX_ELEMENTS	; array to transmit to master
;	I2C_ARRAY_RX32:RX_ELEMENTS	; array to receive from master
;	I2C_ARRAY_TX32:TX_ELEMENTS	; array to transmit to master
;
;	endc
;===============
; I2C_SlaveFlags Bits
I2C_TXLocked	EQU	0	; Set/cleared by ISR, data is being sent
I2C_RXLocked	EQU	1	; Set/cleared by ISR, data is being received
I2C_NewRXData	EQU	2	; Set by ISR, The new data is here!
I2C_SlaveNoAck	EQU	3
I2C_NewDataToTX	EQU	4	; set in main to cause send now
;
;
;=========================================================================================
;=========================================================================================
;----------------------------------- interrupt service routine ---------------------------
;
;-----------------------------------------------------------------------------------------
;	MOVLB	0x00
;	btfsc 	PIR1,SSP1IF 	; Is this a SSP interrupt?
;	call	I2C_ISR
;-----------------------------------------------------------------------------------------
;
;-----------------------------------------------------------------------------------------
; I2C Bus Collision
;IRQ_5	MOVLB	0x00
;	btfss	PIR2,BCL1IF
;	bra	IRQ_5_End
;	movlb	0x04	;banksel SSP1BUF						
;	movf	SSP1BUF,W	; clear the SSP buffer
;	movlb	0x00	;banksel PIR2
;	bcf	PIR2,BCL1IF	; clear the SSP interrupt flag	
;
;IRQ_5_End:
;
;=========================================================================================
;=========================================================================================
;	Main
;-----------------------------------------------------------------------------------------
;
;	call	Init_I2C	; set up uC
;
;MainLoop
;	call	Idle_I2C
;=========================================================================================
;
Idle_I2C	movlb	0
	movf	I2C_Slave_Idx,W
	addlw	low I2C_SlaveFlags
	movwf	FSR0L
	movlw	high I2C_SlaveFlags
	movwf	FSR0H
;
	if useI2CWDT
	movf	TimerI2C,W	;Dog dead?
	IORWF	TimerI2C+1,W
	SKPNZ
	goto	Init_I2C	; Yes, get a new one.
	endif
;
	btfss	I2C_Write_Seq_Active	;Is it a write sequence?
	bra	Idle_I2C_Read	; No, try read
;
	btfss	I2C_Init_Start	;Is start bit set?
	bra	Idle_I2C_Write_1	; No, check if transmission ready
	bcf	I2C_Init_Start	; Yes, clear flag, send start bit
	banksel	SSP1CON2
	bsf	SSP1CON2,SEN	; set start enable bit
	movlb	0x00
	return
;
; set up transmit sequence
;
Idle_I2C_Write_1	btfss	I2C_INIT_TRANS_DATA	;Is bit set?
	bra	Idle_I2C_Write_2	; if not, transmit of data complete
;
	bcf	I2C_INIT_TRANS_DATA	; if so, clear bit
	bsf	INDF0,I2C_TXLocked	; lock the data
	return
;
; set up stop sequence
;
Idle_I2C_Write_2	btfss	I2C_TRANS_COMPLETE	;Is transmission complete?
	return		; No, go back to LOOP
;
	bcf	I2C_TRANS_COMPLETE	;Clear transmission complete flag
	bsf	I2C_Stop_Asserted	;Send a stop bit
	banksel	SSP1CON2
	bsf	SSP1CON2,PEN	;Begin stop sequence
	movlb	0x00
	return
;
;=========================================
;  read sequence
;
Idle_I2C_Read	btfss	I2C_Read_Seq_Active	;Read sequence is active?
	goto	I2C_StartSeq	; No, go start something
	btfss	I2C_Init_Start	; Yes, Start bit is next to do?
	bra	Idle_I2C_Read_1	;  No
; Send start bit
	bcf	I2C_Init_Start
	banksel	SSP1CON2
	bsf	SSP1CON2,SEN	;Set SEN bit to begin start sequence
	movlb	0x00
	return
;
; get ready to receive data
;
Idle_I2C_Read_1	btfss	I2C_INIT_MSTR_REC	;Need to Init Receiver?
	bra	Idle_I2C_Read_2	; No
;
	bcf	I2C_INIT_MSTR_REC
	bsf	INDF0,I2C_RXLocked	;Lock the data
	return
;
Idle_I2C_Read_2	btfsc	I2C_REC_BYTE	;Waiting to receive data?
	return		; Yes
;
Idle_I2C_Read_3	btfss	I2C_SET_ACKEN	;Received data needs and ACK?
	bra	Idle_I2C_Read_4	; No
;
	bcf	I2C_SET_ACKEN
;
;W=I2C_BytesToRec(I2C_Slave_Idx)
	movf	I2C_Slave_Idx,W
	addlw	low I2C_BytesToRec
	movwf	FSR1L
	movlw	high I2C_BytesToRec
	movwf	FSR1H
	movf	INDF1,W
;
	subwf	INDEX_I2C,W	
	btfss	_Z	;RX_ELEMENTS=INDEX_I2C, All bytes received?
	bsf	I2C_SET_RCEN	; No, When ack is done read another byte.
	btfsc	_Z	;RX_ELEMENTS<>INDEX_I2C, All bytes received?
	bsf	I2C_Recd_All	; Yes, we are NAK'ing the last byte.
;
	movlw	low SSP1CON2
	movwf	FSR0L
	movlw	high SSP1CON2
	movwf	FSR0H
	BTFSC	I2C_SET_RCEN	;More bytes to receive?
	bcf	INDF0,ACKDT	; Yes, Send ACK
	BTFSC	I2C_Recd_All	;All bytes received?
	bsf	INDF0,ACKDT	; Yes, Send NAK
	bsf	INDF0,ACKEN	;Send ACK or NAK to slave.
	return
;
; finish up read routine
;
Idle_I2C_Read_4	btfss	I2C_REC_COMPLETE	;Receive is completed?
	return		; No
	bsf	I2C_Stop_Asserted	; Yes, send stop
	bcf	I2C_REC_COMPLETE
	banksel	SSP1CON2
	bsf	SSP1CON2,PEN	;Stop bit sequence
	movlb	0
	if useI2CWDT
	BSF	TimerI2C+1,1	;Kick the dog
	endif
	return
;
;==============================================
;
I2C_StartSeq	btfss	INDF0,I2C_NewDataToTX	;Data to TX?
	bra	I2C_Start_Read_Seq	; No
;
;=======================================================
; Stert write opperation
I2C_Start_Write_Seq	clrf	INDEX_I2C
	clrf	I2C_GFlags
	clrf	I2C_GFlags2
	bsf	I2C_Init_Start	; set start bit
	bsf	I2C_Write_Seq_Active	; set WRITE bit
	bsf	I2C_Addr_Pending	; set bit to ready write add seq.
	bcf	INDF0,I2C_NewDataToTX
	return
;
;======================================================
; Start read opperation
I2C_Start_Read_Seq	clrf	INDEX_I2C
	clrf	I2C_GFlags
	clrf	I2C_GFlags2
	bsf	I2C_Init_Start	;Set ToDo's, Start and Address
	bsf	I2C_Addr_Pending
	bsf	I2C_Read_Seq_Active	;This is a read sequence.
	return
;
;=========================================================================================
;	Initialize: Sets up register values
;=========================================================================================
; Entry: none
; Exit: bank0
; Calls: none
; Ram used: none
;
Init_I2C	movlb	0
	clrf	I2C_Slave_Idx
;
Init_I2CTX_L2	movlw	low I2C_BytesToSend
	addwf	I2C_Slave_Idx,W
	movwf	FSR0L
	movlw	high I2C_BytesToSend
	movwf	FSR0H
	movf	INDF0,W
	movwf	INDEX_I2C	;Size of TX buffer 1..n
;
	lslf	I2C_Slave_Idx,W	;x2
	addlw	low I2C_TX_BuffPtr
	movwf	FSR0L
	movlw	high I2C_TX_BuffPtr
	movwf	FSR0H
; for J=0 to TX_ELEMENTS-1
;  I2C_ARRAY_TX(J)=I2C_TX_Init_Val
	moviw	FSR0++
	movwf	FSR1L
	moviw	FSR0++
	movwf	FSR1H
;
	movlw	I2C_TX_Init_Val
Init_I2CTX_L1	movwi	FSR1++
	decfsz	INDEX_I2C,F
	bra	Init_I2CTX_L1
;
	incf	I2C_Slave_Idx,F
	movlw	I2C_SlaveCount
	subwf	I2C_Slave_Idx,W
	SKPZ
	bra	Init_I2CTX_L2
;
	clrf	I2C_Slave_Idx
;
Init_I2CRX_L2	movlw	low I2C_BytesToRec
	addwf	I2C_Slave_Idx,W
	movwf	FSR0L
	movlw	high I2C_BytesToRec
	movwf	FSR0H
	movf	INDF0,W
	movwf	INDEX_I2C	;Size of TX buffer 1..n
;
	lslf	I2C_Slave_Idx,W	;x2
	addlw	low I2C_RX_BuffPtr
	movwf	FSR0L
	movlw	high I2C_RX_BuffPtr
	movwf	FSR0H
; for J=0 to RX_ELEMENTS-1
;  I2C_ARRAY_RX(J)=I2C_RX_Init_Val
	moviw	FSR0++
	movwf	FSR1L
	moviw	FSR0++
	movwf	FSR1H
;
	movlw	I2C_RX_Init_Val
Init_I2CRX_L1	movwi	FSR1++
	decfsz	INDEX_I2C,F
	bra	Init_I2CRX_L1
;
	incf	I2C_Slave_Idx,F
	movlw	I2C_SlaveCount
	subwf	I2C_Slave_Idx,W
	SKPZ
	bra	Init_I2CRX_L2
;
; Clear I2C_SlaveFlags
	movlw	I2C_SlaveCount
	movwf	Param78
	movlw	low I2C_SlaveFlags
	movwf	FSR0L
	movlw	high I2C_SlaveFlags
	movwf	FSR0H
	movlw	0
	bsf	WREG,I2C_SlaveNoAck
Init_I2C_L1	movwi	FSR0++
	decfsz	Param78,F
	bra	Init_I2C_L1
;
	clrf	I2C_Slave_Idx
	clrf	I2C_GFlags
	clrf	I2C_GFlags2
;
;I2C set up
	BANKSEL	SSP1STAT
	bsf	SSP1STAT,SMP	; Slew rate control disabled for standard speed mode
	clrf	SSP1CON1
	movlw	b'00101000'	; Enable serial port, I2C master mode, 7-bit address
	movwf	SSP1CON1
	bsf	SSP1CON3,PCIE	;Enable interrupt on stop bit
;	bsf	SSP1CON3,SCIE	;Enable interrupt on start bit
	bsf	SSP1CON3,SDAHT	; Minimum of 300 ns hold time
	movlw	BRG_VAL	; load the baud rate value
	movwf	SSP1ADD

	movlb	1
	bsf	PIE1,SSP1IE	; enable SSP interrupts
	bsf	PIE2,BCL1IE	; enable SSP interrupts
	movlb	0
	bcf	PIR1,SSP1IF	; clear the SSP interrupt flag
	bcf	PIR2,BCL1IF	; clear the SSP interrupt flag
;
	if useI2CWDT
	bsf	TimerI2C,7
	endif
;
	return
;
;=========================================================================================
; 	Interrupt Service Routine (ISR)
;=========================================================================================
I2C_ISR	bcf 	PIR1,SSP1IF	; clear the SSP interrupt flag
;
	movf	I2C_Slave_Idx,W
	addlw	low I2C_SlaveFlags
	movwf	FSR0L
	movlw	high I2C_SlaveFlags
	movwf	FSR0H
;
	btfsc	I2C_Write_Seq_Active	; is it a write sequence?
	bra	I2C_Write	; if so go here
	goto	I2C_READ	; if not, it is a read sequence
;
; DATA TRANSMISSION SEQUENCE OF EVENTS
;
I2C_Write	btfsc	I2C_TRANS_COMPLETE	;Is transmission complete?
	bra	I2C_Write_End	; Yes, finish transmission
	btfss	I2C_Addr_Pending	; No, Has address been sent?
	bra	I2C_Write_TXData	;  Yes, go start to transmit
;
; Send the Slave Address
	bcf	I2C_Addr_Pending	;  No, send Address
	bsf	I2C_INIT_TRANS_DATA
	call	I2C_GetSlaveAddr
	BANKSEL	SSP1BUF
	BCF	WREG,0	; Set R/W* to Write
	movwf	SSP1BUF
	movlb	0x00
	bsf	I2C_TRANS_DATA	;On next interrupt send data
	return
;
;
I2C_Write_TXData	btfss	I2C_TRANS_DATA	; is transmission complete?
	bra	I2C_Write_End	; if so, go finish sequence
;
	BANKSEL	SSP1CON2
	btfsc	SSP1CON2,ACKSTAT	;ACK* for address or last data sent?
	bra	I2C_Write_NoSlaveACK	; No, Stop now.
	movlb	0
;W=I2C_BytesToSend(I2C_Slave_Idx)
	movf	I2C_Slave_Idx,W
	addlw	low I2C_BytesToSend
	movwf	FSR1L
	movlw	high I2C_BytesToSend
	movwf	FSR1H
	movf	INDF1,W
;
	subwf	INDEX_I2C,W
	btfsc	_C	; did a carry occur after subtraction?
	bra	I2C_Write_1	; if so, array limit reached
;
	call	I2C_Set_TX_PTR
	movf	INDF1,W	; move value into W to load to SSP buffer
	incf	INDEX_I2C,F	; increment INDEX_I2C 'pointer'
	BANKSEL	SSP1BUF
	movwf	SSP1BUF	; load SSP buffer
	btfsc	SSP1CON1,WCOL	; did a write collision occur?
	bcf	SSP1CON1,WCOL	; if so, clear bit
	movlb	0x00
	return
;
;
; is transmission complete?
;
I2C_Write_NoSlaveACK	movlb	0
I2C_Write_1	bcf	I2C_TRANS_DATA	; clear bit
	bsf	I2C_TRANS_COMPLETE	; get ready to end sequence
	return
;
; finish transmit sequence
;
I2C_Write_End	btfss	I2C_Stop_Asserted	; is stop set?
	return		; yes, we're done
	bcf	I2C_Stop_Asserted	; if so, clear stop
	bcf	I2C_Write_Seq_Active	; clear bit to prevent more transmissions
	bcf	INDF0,I2C_TXLocked	; unlock data
	goto	I2C_NextSlave
;
;=========================================================================================
; READ FROM SLAVE SEQUENCE OF EVENTS
;
I2C_READ	btfss	I2C_Addr_Pending	;Address transmitted to slave?
	bra	I2C_READ_1	; Yes
;
; Send Address and read bit to slave
	bcf	I2C_Addr_Pending
	call	I2C_GetSlaveAddr
	BANKSEL	SSP1BUF
	BSF	WREG,0	; Set R/W* to Read 
	movwf	SSP1BUF
	movlb	0x00
	bsf	I2C_INIT_MSTR_REC	;Next ToDo is init receive data.
	bsf	I2C_SET_RCEN	;Enable the receiver at the next interrupt
	return
;
;
I2C_READ_1	btfss	I2C_SET_RCEN	;Setup receiver now?
	bra	I2C_READ_2	; No
;
; Set up master to receive the first byte from the slave.
	bcf	I2C_SET_RCEN
	BANKSEL	SSP1CON2
	btfsc	SSP1CON2,ACKSTAT	;ACK* for address?
	bra	NoSlaveACK	; No, Stop now.
	movlb	0
	bcf	INDF0,I2C_SlaveNoAck	;Address was ACK'd.
	bsf	I2C_REC_BYTE
	BANKSEL	SSP1CON2
	bsf	SSP1CON2,RCEN	;Set RCEN to enable master receive mode
	movlb	0
	return
;
I2C_READ_2	btfss	I2C_REC_BYTE	;Was data received?
	bra	I2C_READ_3	; No
;
; read the data byte from slave and store it in the receive buffer
	bcf	I2C_REC_BYTE
	call	I2C_Set_RX_PTR
	BANKSEL	SSP1BUF
	movf	SSP1BUF,W
	movlb	0
	movwf 	INDF1
	incf	INDEX_I2C,F	;Increment buffer pointer
	bsf	I2C_SET_ACKEN	;Next ToDo is to ACK the data.
	return
;
; Slave didn't ack* the address
;
NoSlaveACK	movlb	0
	bcf	INDF0,I2C_RXLocked	; unlock the data
	bsf	INDF0,I2C_SlaveNoAck	; set error flag
	bsf 	I2C_REC_COMPLETE
	return
;
; get ready to wrap things up
;
I2C_READ_3	btfss	I2C_Recd_All	;All bytes rec'd?
	bra	I2C_READ_End	; No
	bcf	I2C_Recd_All	; Yes
	bcf	INDF0,I2C_RXLocked	;Unlock the data.
	bsf	INDF0,I2C_NewRXData	;New data is ready.
	bsf 	I2C_REC_COMPLETE	;ToDo: receive complete.
	return
;
I2C_READ_End	btfss	I2C_Stop_Asserted	;Stop was sent?
	return		; No
	bcf	I2C_Stop_Asserted	; Yes, clear stop
	bcf	I2C_Read_Seq_Active	; and we are done
	goto	I2C_NextSlave
;
;=========================================================================================
; Entry: none
; Exit: W=SlaveAddress
;
I2C_GetSlaveAddr	movlb	0
	lslf	I2C_Slave_Idx,W	;0..7
	addlw	I2C_ADDRESS
	return
;
;=========================================================================================
; Advance I2C_Slave_Idx to the next slave
;
; Entry: none
; Exit: none
;
I2C_NextSlave	movlb	0
	incf	I2C_Slave_Idx,F
	movlw	I2C_ActiveSlaves
	subwf	I2C_Slave_Idx,W
	SKPNZ
	clrf	I2C_Slave_Idx
	return

;=========================================================================================
; Set FSR1 to point to the tx buffer for slave I2C_Slave_Idx
I2C_Set_TX_PTR	movlb	0
	lslf	I2C_Slave_Idx,W
	addlw	low I2C_TX_BuffPtr
	movwf	FSR1L
	movlw	high I2C_TX_BuffPtr
;
I2C_Set_TX_PTR_E2	movwf	FSR1H
	moviw	FSR1++
	movwf	I2C_Temp
	moviw	FSR1++
	movwf	FSR1H
	movf	I2C_Temp,W
	movwf	FSR1L
;
	movf	INDEX_I2C,W
	addwf	FSR1L,F
	clrw
	addwfc	FSR1H,F
	return
;
;=========================================================================================
; Set FSR1 to point to the rx buffer for slave I2C_Slave_Idx
I2C_Set_RX_PTR	movlb	0
	lslf	I2C_Slave_Idx,W
	addlw	low I2C_RX_BuffPtr
	movwf	FSR1L
	movlw	high I2C_RX_BuffPtr
	bra	I2C_Set_TX_PTR_E2
;
;=========================================================================================
;
;




















