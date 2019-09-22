; Firmware pre testovanie kontaktov patice AT89Cx051 zariadenia pre
; programovanie mikrokontrolerov AT89Cx051 seriovym ISP programatorom

; Verzia 1.0
	
; Copyright (C) 2012 Jan Sucan <sucan@runbox.com>

; Permission is hereby granted, free of charge, to any person obtaining
; a copy of this software and associated documentation files (the
; "Software"), to deal in the Software without restriction, including
; without limitation the rights to use, copy, modify, merge, publish,
; distribute, sublicense, and/or sell copies of the Software, and to
; permit persons to whom the Software is furnished to do so, subject to
; the following conditions:

; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.

; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
; IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
; CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
; TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
; SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

; ------------------------------------------------------------------------------
; hardware
; ------------------------------------------------------------------------------
grnled 	equ	p0.1		; zelena LED
redled	equ	p0.0		; cervena LED
button	equ	p1.0		; ovladacie tlacidlo

rdy	equ	p0.2		; signaly pre AT89Cx051
xtal	equ	p0.3
prog 	equ	p0.4
m0 	equ	p0.5
m1 	equ	p0.6
m2 	equ	p0.7
pdata	equ	p2
rstsw	equ	p3.5		; spinanie RST napatia
vccsw	equ	p3.6		; spinanie napajacieho napatia
	
; ------------------------------------------------------------------------------
; konstanty a premenne
; ------------------------------------------------------------------------------
dtctlim	equ	500		; hranicny pocet dobrych stavov pre vyhodnotenie
				; stlacenia alebo uvolnenia tlacidla

; konstanty casovacov pri taktovacej frekvencii 24 MHz v jednotkach 0,5 us 
period  equ     530		; perioda PWM signalu
volt    equ     18		; aktivna polperioda PWM signalu (pre 5 V)
				; odmeranie casu 0,5 ms
halfmsl	equ	low (0ffffh - 1000)
halfmsh	equ	high (0ffffh - 1000)

; ------------------------------------------------------------------------------
; kod programu
; ------------------------------------------------------------------------------
	cseg
	
	org	00h
	ajmp	main		; hlavny program
	
	org	0bh
	ajmp	rstpwm		; obsluha casovaca PWM generatoru
	
; ------------------------------------------------------------------------------
; hlavny program
; ------------------------------------------------------------------------------
main:	setb	grnled		; zhasni obe LED
	setb	redled

	mov	tmod,#00010001b	; dva 16 bitove casovace

	setb	ea		; povol vsetky prerusenia

loop:	setb	redled		; 1. stav testovania
	clr	grnled
	
	setb	vccsw
	mov	a,#01010101b
	acall	putbyte
	clr	m2
	setb	m1
	clr	m0
	setb	prog
	clr	xtal
	setb	rdy
	acall	rst0v

	acall	press		; cakaj na stlacenie tlacidla
	acall	release		; cakaj na uvolnenie tlacidla

	clr	redled		; 2. stav testovania
	setb	grnled

	clr	vccsw
	mov	a,#10101010b
	acall	putbyte
	setb	m2
	clr	m1
	setb	m0
	clr	prog
	setb	xtal
	clr	rdy
	acall	rst12v

	acall	press		; cakaj na stlacenie tlacidla
	acall	release		; cakaj na uvolnenie tlacidla
		
	ajmp	loop
	
; ------------------------------------------------------------------------------
; obsluzne podprogramy
; ------------------------------------------------------------------------------
; obsluha casovaca PWM generatoru
rstpwm: clr	tr0		; zastav casovac pre konzistentnu zmenu hodnoty
	jbc	rstsw,rstpwm_low
	setb	rstsw
        mov     tl0,#low (0ffffh - volt)
        mov     th0,#high (0ffffh - volt)
rstpwm_exit:
	setb	tr0		; znovu spust casovac 
        reti
rstpwm_low:
        mov     tl0,#low (0ffffh - period + volt)
        mov     th0,#high (0ffffh - period + volt)
	ajmp	rstpwm_exit
	
; nastavenie RST = 0 V
rst0v:	clr     et0		; nepotrebuje obsluhu casovaca 0
	clr	rstsw
	mov	r0,#low (580)	; cakaj >286,5 ms na dosiahnutie napatia 0,5 V
	mov	r1,#high (580)
        ajmp    rstwait

; nastavenie RST = 5 V
rst5v:	jbc	rstsw,rst5v_down
	setb	rstsw		; pull-up impulz
	mov	r0,#low (11)	; cakaj 5,5 ms
	mov	r1,#high (11)
        ajmp    rst5v_l0
rst5v_down:			; pull-down impulz
	mov	r0,#low (159)	; cakaj 79,5 ms
	mov	r1,#high (159)
rst5v_l0:
	acall	wait
	setb    et0		; povol prerusenie od casovaca 0
        setb    tf0		; vyvolaj obsluhu prerusenia od casovaca 0
	mov	r0,#low (40)	; cakaj 20 ms na ustalenie napatia 5 V
	mov	r1,#high (40)	
        ajmp    rstwait
	
; nastavenie RST = 12 V
rst12v:	clr     et0		; nepotrebuje obsluhu casovaca 0
	setb	rstsw
	mov	r0,#low (100)	; cakaj >44 ms na dosiahnutie napatia 12 V
	mov	r1,#high (100)	
rstwait:
        acall	wait
        ret

; ------------------------------------------------------------------------------
; cakanie zadaneho poctu 0,5 ms
wait:	cjne	r0,#0,wait_next	; detekuj koniec cakania
	cjne	r1,#0,wait_next
	ret
wait_next:
	dec	r0		; zniz 16 bitove pocitadlo
	cjne	r0,#0ffh,$+4	; detekuj vypozicku
	dec	r1
	clr	tr1		; zastav casovac pre konzistentnu zmenu hodnoty
	clr	tf1	
 	mov	tl1,#halfmsl	; cakaj 0,5 ms
 	mov	th1,#halfmsh
	setb	tr1		; znovu spust casovac
 	jnb	tf1,$
	ajmp	wait

; bitove otocenie bajtu v ACC
rotatebyte:
	mov	r7,#8		; pocet bitov
rotatebyte_l0:
	rlc	a		; MSB do C
	xch	a,r6		; vymen A s R6
	rrc	a		; C do LSB
	xch	a,r6		; vymen A s R6
	djnz	r7,rotatebyte_l0
	xch	a,r6		; otoceny bajt do A
	ret
	
; zapisanie bajtu na datovy port AT89Cx051
putbyte:			
	acall	rotatebyte	; korekcia bitoveho otocenia datovej zbernice
	mov	pdata,a
	ret
	
; detekovanie stlacenia tlacidla
press:	clr	f0
	ajmp	noise
; detekovanie uvolnenia tlacidla
release:		
	setb	f0
noise:	mov	dptr,#0		; pouzi DPTR ako 16 bitove pocitadlo
 	clr	tf1		; analyzuj 10 ms interval
 	mov	tl1,#low (65535 - 20000)
 	mov	th1,#high (65535 - 20000)
detect:	mov	c,button	; porovnaj aktualny stav tlacidla s
				; predpokladanym stavom
	rlc	a
	xch	a,b
	mov	c,f0
	rlc	a
	xrl	a,b
	jb	acc.0,$+4
	inc	dptr		; ak sa rovnaju, zapocitaj dobry stav
	jnb	tf1,detect	; opakuj do skoncenia intervalu
	
	clr	c		; porovnaj pocet dobrych stavov s hranicnou
	mov	a,dpl		; hodnotou
	subb	a,#low (dtctlim)
	mov	a,dph
	subb	a,#high (dtctlim)
	jnc	noise		; ak nebola prekrocena hranicna hodnota
	ret			; analyzuj dalsi interval

	end
