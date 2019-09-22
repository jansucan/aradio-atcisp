; Firmware pre kalibraciu PWM generatoru RST napatia zariadenia pre
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

	acall	rst5v
	clr	grnled		; zasviet zelenu LED
	
; pri testovani PWM generatoru RST napatia simuluj cinnost ostatnych signalov. 
; Nastavuj na ostatnych vyvodoch patice AT89Cx051 rozne logicke urovne po rozny
; cas. Pseudonahodne hodnoty ziskavaj z neprazdnych bajtov pamate programu.
	mov	dptr,#0		; vyberaj bajty od zaciatku pamate programu
	clr	f0
loop:	mov	a,dph		; vyberaj len bajty z neprazdnej oblasti pamate
	cjne	a,#high (lastinst),next
	mov	a,dpl
	cjne	a,#low (lastinst),next
	mov	dptr,#0
	cpl	f0		; kazdy druhy priechod ziskanu hodnotu zneguj
	
next:	mov	a,#0		; vyber bajt
	movc	a,@a+dptr
	
	jb	f0,nocpl
	cpl	a
nocpl:	mov	pdata,a
	subb	a,b		; odcitaj hodnotu ziskanu z predchadzajuceho
				; bajtu
	rrc	a		; rozkopiruj bity na jednotlive vyvody
	mov 	rdy,c
	rrc	a
	mov 	xtal,c
	rrc	a
	mov 	prog,c
	rrc	a
	mov 	m0,c
	rrc	a
	mov 	m1,c
	rrc	a
	mov 	m2,c	
	rrc	a
	mov	vccsw,c
	acall	pause		; cakaj
	mov	b,a		; uloz aktualnu hodnotu
	inc	dptr		; dalsi bajt
	ajmp	loop

pause:	mov	r2,a
	mov	r1,b
	djnz	r1,$
	djnz	r2,$-2
	ret
	
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

; ----------------------------------------------------------------------	
; adresa bajtu za poslednou instrukciou tohoto programu
lastinst:

	end
