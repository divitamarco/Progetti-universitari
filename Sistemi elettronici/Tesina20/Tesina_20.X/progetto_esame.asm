
#define SHOW_SLEEP  
list p=16f887
#include <p16f887.inc>
    
; configurazione
    
__CONFIG _CONFIG1, _INTRC_OSC_NOCLKOUT & _CP_OFF & _WDT_OFF & _BOR_OFF & _PWRTE_OFF & _LVP_OFF & _DEBUG_OFF & _CPD_OFF
    
; costanti
    
tmp_max 	EQU	.20
tmr_1s	        EQU	(.65536 - .32774)
tmr_50ms	EQU	(.256 - .195)
note		EQU	.95

		
; variabili
    
	    UDATA_SHR
w_temp		RES		1			
status_temp	RES		1			
pclath_temp	RES		1
temp		RES		1
tmp		RES		1
temperature	RES		1
canSleep	RES		1
counter_led	RES		1
counter_minuto  RES             1
counter_alarm   RES             1
	
; inizio codice
	
RST_VECTOR	CODE 0x0000
		pagesel start
		goto start
		
MAIN		CODE
start
		pagesel INIT_HW
		call INIT_HW
		; inizializzazione stato LED (tutti LED spenti)
		banksel	PORTD			; selezione banco RAM di PORTD
		clrf	PORTD
		;loop minuto
		movlw .60
		movwf counter_minuto
		pagesel	reload_timer
		call	reload_timer
		; abilita interrupt timer1
		banksel	PIE1			; contenente interrupt enable delle periferiche
		bsf	PIE1, TMR1IE		; setta il bit interrupt enable associato al TIMER1
		; Abilita gli interrupt delle periferiche aggiuntive (tra cui timer1)
		bsf	INTCON, PEIE		; attivazione del PERIPHERICAL INTERRUPT ENABLE
		; Abilita gli interrupt globalmente
		bsf	INTCON, GIE		; attivazione del GLOBAL INTERRUPT ENABLE
		; Inizialmente la CPU puo' andare in sleep (finché non avviene interrupt da una sorgente asincrona rispetto al clock interno)
		bsf	canSleep,0
		
main_loop      
		bsf canSleep,0
waitSleep	
		bcf INTCON, GIE
		btfsc canSleep,0		; se = 1 va in sleep, se = 0 aspetta
		goto goSleep
		bsf INTCON, GIE
		goto waitSleep
		
goSleep		
					#ifdef SHOW_SLEEP
					banksel	PORTD
					bcf	PORTD,3		; spegne LED4 prima di sleep
					#endif
		sleep
		bsf INTCON, GIE
		
					#ifdef SHOW_SLEEP
					banksel	PORTD
					bsf		PORTD,3		; accende LED4 dopo risveglio
					#endif
		goto main_loop
		
		
reload_timer
			; ricarica contatore timer1 per ricominciare conteggio.
			; In modalita' asincrona, occorre arrestare il timer prima
			; di aggiornare i due registri del contatore
			banksel	T1CON
			bcf	T1CON, TMR1ON	; arresta timer
			; le funzioni "low" e "high" forniscono il byte meno e piu'
			;  significativo di una costante maggiore di 8 bit
			banksel	TMR1L
			movlw	low  tmr_1s
			movwf	TMR1L
			movlw	high tmr_1s
			movwf	TMR1H
			bcf	PIR1, TMR1IF		; azzera flag interrupt
		        banksel	T1CON
		        bsf	T1CON, TMR1ON		; riattiva timer
			return
				
DELAY		
		movlw tmr_50ms
		banksel	TMR0
		movwf	TMR0			
		bcf	INTCON,T0IF	
wait_delay	
		btfss	INTCON,T0IF		; se il flag di overflow del timer è = 1, salta l'istruzione seguente (interrupt generato)
		goto	wait_delay		; ripeti il loop di attesa (POLLING)
		return
		

INIT_HW	    
		; inizializzazione timer0
		banksel OPTION_REG
		movlw B'00000111' ; bit 0-2 = 111 (prescaler timer0=256), bit3 = 0 (prescaler assegnato a timer0), bit4=0 (low-to-high), bit5=0 (sorgente di clock interna)
		movwf OPTION_REG
		; registro interrupt
		clrf INTCON
		; porte I/O
		banksel	TRISD			; banco di TRISD, stesso banco anche per gli altri registri TRISx
		movlw	B'11111011'		; abilitazione del pin RC2 come output mode per il buzzer
		movwf	TRISC			; copia W (B'11111011') in TRISC -> RC2 COME OUTPUT PER IL BUZZER (impostazione su TRISC perché user_RC2 è uno speaker pin di output, vedere su datasheet della board)
		movlw	0xF0			; carica costante F0 in W
		movwf	TRISD			; primi 4 led in output mode
		; ADC
		banksel ANSELH			; banco di ANSELH
		clrf	ANSELH			; AN8..AN13 disattivati
		; timer1
		banksel	T1CON			; registro di configurazione TIMER1
	        movlw	B'00001110'		; TMR1ON = 0 (spento), TMR1CS = 1 (esterna), T1SYNC = 1 (no sincronizzazione con clock interno), T1OSC = 1 (selezione oscillatore esterno), T1CKPS = 00 (prescaler a 1), TMR1GE = 0 (bit attualmente ignorato)
		movwf	T1CON
		; timer2 
		banksel	T2CON			; registro di configurazione TIMER2
		movlw	B'00000011'		; TMR2ON = 0 (off), TMR2PS = 11 (prescaler a 16), TOTPS = 0000 (post scaler a 1)
		movwf	T2CON
		banksel	CCP1CON			; modulo CAPTURE-COMPARE-PWM a cui dire di lavorare in modalità PWM
		movlw	B'00001100'		; PWM mode CCP1M (bit 3-0) = 1100 (11 modalità pwm, 00 in single output)
		movwf	CCP1CON
		return
		
		
readAdc
		banksel ADCON0
		bsf ADCON0, ADON    ; attiva modulo ADC solo quando viene utilizzato
		movwf temp           ; salva W (canale) in tmp
		bcf STATUS,C	    ; metto il carry a zero che lo shift fa entrare a destra
		rlf temp,f           ; shift di tmp di 2 bit per scrivere
		rlf temp,f           ;  il canale nel registro ADCON0
		movlw B'11000001'   ; abilita gli altri bit necessari per usare
		iorwf temp,w         ;  oscillatore RC (OR tra w e variabile)
		movwf ADCON0        ; scrive registro ADCON0
		bsf ADCON0,GO       ; inizia conversione GO=1 (va settato a parte rispetto agli altri bit del registro)
waitAdc
		btfsc ADCON0,GO	    ; attendo che GO vada a 0
		goto waitAdc
		banksel ADRESH
		movf ADRESH,w      ; copia valore campionato in W (risultato della conversione)
		banksel ADCON0
		bcf ADCON0, ADON   ; disattiva modulo ADC
		return
		
computeTemp
		movwf tmp
		movlw .31
		subwf tmp, f  ; tmp = tmp - 31
		bcf STATUS, C ; metto il carry a zero perché nelle shift a sinistra quello che entra è il contenuto del carry che quindi per non alterare il valore deve essere 0
		rlf tmp, f    ; tmp = tmp * 2 (usando lo shift a sinistra)
		clrf temperature  ; valore iniziale del risultato finale = 0 (conto quante volte il 3 sta nel numero)
loop_div3
		movlw .3
		subwf tmp, w          ; w = tmp - 3
		btfss STATUS, C	      ; per vedere se il risultato è negativo controllo il carry = 0, se =1 il risultato non è negativo
		goto end_div3         ; se risultato negativo (C=0): fine divisione
		movwf tmp             ; tmp = tmp - 3
		incf temperature, f   ; incrementa risultato di 1
		goto loop_div3        ; continua sottrazione
end_div3
		movf temperature, w
		return
	
		; INTERRUPT
		
		
IRQ		CODE	0x0004
INTERRUPT
		; salvataggio di contesto
		movwf	w_temp			; copia W in w_temp
		swapf	STATUS,w		; inverte i nibble di STATUS salvando il risultato in W.
						; Questo trucco permette di copiare STATUS senza alterarlo
						; (swapf e' una delle poche istruzioni che non alterano i bit di stato).
		movwf	status_temp		; copia W (= STATUS) in status_temp (con i nibble invertiti).
		movf	PCLATH,w		; copia il registro PCLATH in W (registro da salvare perche' contiene i
						; bit piu' significativi del program counter, usati da GOTO e CALL,
						; e settati dalla direttiva pagesel).
		movwf	pclath_temp		; copia W (= PCLATH) in pclath_temp.
		
		; CODICE INTERRUPT
test_timer0	
		btfss	INTCON,T0IF		; se il bit T0IF = 1 (c'e' stato un interrupt del timer), salta istruzione seguente e serve interrupt
		goto 	test_timer1		; salta a test successivo
		btfss	INTCON, T0IE		; controlla anche che l'interrupt fosse effettivamente abilitato
		goto	test_timer1
		; avvenuto interrupt timer0: termine Blink/Alarm
		bcf	INTCON, T0IF		; azzera flag interrupt timer
		bcf	INTCON, T0IE		; disabilita interrupt timer
		; Verifichiamo se la PWM e' disattivata :   
		banksel	T2CON
		btfss	T2CON, TMR2ON		; se timer2 attivo, salta
		bsf	canSleep, 0		; altrimenti abilita sleep
		goto	irq_end			; vai a fine routine di interrupt
		
test_timer1
		; testa evento overflow timer1 (TMR1IF + TMR1IE)
		banksel	PIR1
		btfss	PIR1,TMR1IF
		goto	irq_end
		banksel	PIE1
		btfss	PIE1,TMR1IE
		goto	irq_end
		banksel PIR1
		bcf     PIR1,TMR1IF
		decfsz  counter_minuto,f
		goto reload
		; avvenuto overflow timer1
		movlw .25                 
		movwf counter_led
		pagesel loop_blink
		call loop_blink
		movlw .6
		pagesel readAdc
		call readAdc
		pagesel computeTemp
		call computeTemp
		sublw tmp_max			; w = soglia - temperatura
		btfsc STATUS, C			; per vedere se il risultato è negativo controllo il carry = 0, se =1 il risultato non è negativo
		goto reload_counter		; C=1, risultato non negativo, soglia non superata
		movlw .40
		movwf counter_alarm
		pagesel loop_alarm
		goto loop_alarm
		
reload
		pagesel reload_timer
		call reload_timer
		goto irq_end
			
loop_blink
		decfsz counter_led, f
		goto blink_led
		return
		
blink_led
		banksel PORTD
		clrf PORTD
		;accendere
		bsf PORTD, 0
		pagesel DELAY
		call DELAY
		;spegnere
		bcf PORTD, 0
		pagesel DELAY
		call DELAY
		goto loop_blink
		
loop_alarm 
		decfsz counter_alarm, f
		goto delay_alarm
		goto stop_alarm
		
delay_alarm
		pagesel play_alarm
		call play_alarm
		pagesel DELAY
		call DELAY
		pagesel DELAY
		call DELAY
		goto loop_alarm
play_alarm		
		; quando la soglia di temperatura viene superata e quindi il valore letto dal sensore
		; è superiore alla soglia fissata viene fatto suonare un allarme.
		movlw note
		banksel	PR2
		movwf	PR2		; PERIODO
		; per ottenere un'onda quadra con duty-cycle al 50%,
		; occorre settare CCPR1L alla meta' di PR2
		bcf	STATUS, C	; azzera carry per successivo shift
		rrf	PR2, w		; W = PR2 shiftato a destra = meta' (rrleft divide per 2, rrright moltiplica per 2)
		banksel	CCPR1L
		movwf	CCPR1L		; ton
		; attiva timer2 -> suono emesso da buzzer
		banksel	T2CON
		bsf	T2CON, TMR2ON	
		return
		
stop_alarm
		banksel T2CON
		bcf T2CON, TMR2ON
		clrf PORTD
	
reload_counter
		movlw .60
		movwf counter_minuto
		pagesel reload_timer
		call reload_timer
		
irq_end		
		; ripristino di contesto
		movf	pclath_temp,w		
		movwf	PCLATH			
		swapf	status_temp,w	
		movwf	STATUS			
		swapf	w_temp,f		
		swapf	w_temp,w

		retfie	
		
		
		
		END








