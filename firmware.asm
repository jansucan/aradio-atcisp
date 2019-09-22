; Firmware zariadenia pre programovanie mikrokontrolerov AT89Cx051 seriovym
; ISP programatorom

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
tgtoff  equ     0		; offset dat v pamati programu AT89Cx051
tgtsg1	equ	1eh		; hodnoty bajtov signatury AT89Cx051
tgtsg2	equ	21h
tgtmem	equ	4096		; velkost pamate programu AT89Cx051 v bajtoch

hstmem  equ     4096		; velkost pamate programu AT89S51 v bajtoch
	
erased	equ	0ffh		; hodnota zmazanej bunky pamate programu
nsdelay	equ	40h		; oneskorenie pre osetrenie zakmitov tlacidla

; konstanty casovacov pri taktovacej frekvencii 24 MHz v jednotkach 0,5 us 
period  equ     530		; perioda PWM signalu
volt    equ     18		; aktivna polperioda PWM signalu (pre 5 V)
				; odmeranie casu 0,5 ms
halfmsl	equ	low (0ffffh - 1000)
halfmsh	equ	high (0ffffh - 1000)
		
; kody programovacich modov pre AT89Cx051 
ermode	equ 	00000001b	; zmazanie pamate programu
wrmode	equ	00001110b	; zapis dat do pamate programu
rdmode	equ	00001100b	; citanie pamate programu
lb1mode	equ	00001111b	; zapis 1. uzamykacieho bitu
lb2mode	equ	00000011b	; zapis 2. uzamykacieho bitu
sgnmode	equ	00000000b	; citanie bajtov signatury

        dseg    at 30h
endl:	ds	1		; velkost dat v pamati programu AT89S51
endh:	ds	1

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

	acall	getlength	; ziskaj velkost dat v pamati programu AT89S51
	mov	endl,dpl
	mov	endh,dph

	acall	off		; uved AT89Cx051 do pokojoveho stavu

	clr	redled		; LED indikujuce pohotovostny stav striedavym
				; svitom 
standby:
	mov	a,#120		; dlzka svitu LED je 120 x 10 ms
checkpress:
	jnb	button,noise	; detekuj stlacenie tlacidla
	mov	r0,#low (20)	; v 10 ms intervaloch
	mov	r1,#high (20)
	acall	wait
	djnz	acc,checkpress
	cpl	redled
	cpl	grnled
	ajmp	standby
noise:	mov	r0,#nsdelay	; osetri zakmity
	djnz	r0,$
	jb	button,standby
	
	setb	ea		; povol vsetky prerusenia
	
	clr	grnled		; zasviet obe LED
	clr	redled

; ------------------------------------------------------------------------------
; vyber operacii pre AT89Cx051
; ------------------------------------------------------------------------------
	; acall	signverify	; kontrola bajtov signatury
	acall	erasechip	; zmazanie pamate programu
	acall 	codewrite	; zapis dat do pamate programu
	acall	codeverify	; kontrola dat v pamati programu
	; acall	lockwrite_1	; zapis 1. uzamykacieho bitu
	; acall	lockwrite_2	; zapis 1. a 2. uzamykacieho bitu
; ------------------------------------------------------------------------------
; koniec vyberu operacii pre AT89Cx051
; ------------------------------------------------------------------------------
				; vsetky operacie prebehli v poriadku
	setb	redled		; svieti len zelena LED
	ajmp	$
				; chyba pri vykonavani operacii
fatal:	setb	grnled		; svieti len cervena LED
	ajmp	$

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
	cjne	r0,#0ffh,$+4	; detekuj vypozicku z vrchneho bajtu
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

; ziskanie velkosti dat v pamati programu AT89S51
getlength:
	mov	dptr,#hstmem	; zacni od konca pamate
getlength_next:		
	dec	dpl		; pokracuj smerom k nizsim adresam
	mov	a,dpl		; detekuj vypozicku z vrchneho bajtu
	cjne	a,#0ffh,$+5
	dec	dph	
	mov	a,#0
	movc	a,@a+dptr
	cjne	a,#erased,$+5	; hladaj prvy neprazdny bajt (!= erased)
	ajmp	getlength_next
	inc	dptr		; korektura velkosti (prva adresa je 0)
	ret

; ------------------------------------------------------------------------------
; vypinacia sekvencia pre AT89Cx051
off:	clr	xtal
	acall	rst0v
	clr	vccsw
	ret

; zapinacia sekvencia pre AT89Cx051
on:	rrc	a		; nastav bity operacie
	mov	m0,c
	rrc	a
	mov	m1,c
	rrc	a
	mov	m2,c
	setb	vccsw
	acall	rst0v
	clr	xtal
	acall	rst5v
	setb	prog
	ret

; zapisanie bajtu na datovy port AT89Cx051
putbyte:			
	acall	rotatebyte	; korekcia bitoveho otocenia datovej zbernice
	mov	pdata,a
	ret

; precitanie bajtu z datoveho portu AT89Cx051
getbyte:
	mov	a,pdata
	acall	rotatebyte	; korekcia bitoveho otocenia datovej zbernice
	ret

; zvysenie interneho adresoveho citaca AT89Cx051 a DPTR
nextbyte:
	setb	xtal		; XTAL impulz
	clr	xtal
	inc	dptr		; zaznamenaj pocet
	ret

; nastavenie citaca adries v AT89Cx051 na offset
; citac nie je mozne nastavit priamo hodnotou a tak je nutne nastavit ho na
; danu adresu potrebnym poctom XTAL impulzov 
setoffset:			
	mov	dptr,#0		; pouzi DPTR ako 16 bitove pocitadlo
setoffset_next:
	mov	a,dph		; detekuj pocet impulzov
	cjne	a,#high (tgtoff),setoffset_pulse
	mov	a,dpl
	cjne	a,#low (tgtoff),setoffset_pulse
	ret
setoffset_pulse:
	acall	nextbyte	; zvys citac adries
	ajmp	setoffset_next

; kontrola dosiahnutia konca dat pre spracovanie
isend:
	mov	a,r1		; porovnaj DPTR so zadanou hodnotou
	cjne	a,dph,isend_exit
	mov	a,r0
	cjne	a,dpl,isend_exit
	acall	off	      	; bola dosiahnuta zadana hodnota
	pop	acc	   	; vrat sa do hlavneho programu vynechanim
	pop	acc		; navratovej adresy tohoto podprogramu
isend_exit:
	ret
	
; inicializacia AT89Cx051 pre citanie pamate
compare_init:
	acall	on	
	mov	pdata,#0ffh	; pdata ako vstupy
	ret

; porovnanie bajtu v ACC s dalsim bajtom pamate AT89Cx051	
compare_byte:	
	mov	b,a		; zachovaj ACC
	acall	getbyte		; porovnaj bajt pamate so zadanou hodnotou
	cjne	a,b,compare_error
	acall	nextbyte	; priprav dalsi bajt
	ret			; cakaj na dodanie dalsieho bajtu pre porovnanie
compare_error:			; chyba, data sa nerovnaju
	acall	off
	ajmp	fatal
	
; zmazanie pamate programu AT89Cx051
erasechip:
	mov	a,#ermode
	acall	on
	acall	rst12v
	clr	prog		; 10 ms PROG impulz
	mov	r0,#low (20)
	mov	r1,#high (20)
	acall	wait
	setb	prog
	acall	off
; kontrola zmazania pamate programu AT89Cx051
	mov	a,#rdmode
	acall	compare_init
				; nastav velkost dat pre spracovanie
	mov	r0,#low (tgtmem)
	mov	r1,#high (tgtmem)
	mov	dptr,#0		; pouzi DPTR ako 16 bitove pocitadlo
eraseverify_next:
	acall	isend		; detekuj dosiahnutie konca dat pre zmazanie
	mov	a,#erased	; kazda bunka musi mat prazdnu hodnotu
	acall	compare_byte
	ajmp	eraseverify_next
	
; naprogramovanie pamate programu AT89Cx051
codewrite:
	mov	a,#wrmode
	acall	on
	acall	rst12v
	acall	setoffset  	; nastav offset dat v pamati programu AT89Cx051
	mov	r0,endl		; nastav velkost dat pre zapis
	mov	r1,endh
	mov	dptr,#lastinst	; data v pamati programu AT89S51 zacinaju za
				; poslednou instrukciou
codewrite_next:
	acall	isend		; detekuj dosiahnutie konca dat pre zapis
	mov 	a,#0		; zapis bajt
	movc	a,@a+dptr
	acall	putbyte
	clr	prog		; 1 us PROG impulz
	nop
	setb	prog	
	jnb	rdy,$		; cakaj na skoncenie zapisu
	acall	nextbyte	; priprav dalsi bajt
	ajmp	codewrite_next

; kontrola pamate programu AT89Cx051
; porovna obsah pamate programu od offsetu s obsahom datovej casti pripojenej k
; firmwaru		
codeverify:
	mov	a,#rdmode
	acall	compare_init
	acall	setoffset  	; nastav offset dat v pamati programu AT89Cx051
	mov	r0,endl		; nastav velkost dat pre kontrolu
	mov	r1,endh
	mov	dptr,#lastinst	; data v pamati programu AT89S51 zacinaju za
				; poslednou instrukciou
codeverify_next:
	acall	isend		; detekuj dosiahnutie konca dat pre kontrolu
	mov 	a,#0		; porovnaj bajt
	movc	a,@a+dptr
	acall	compare_byte
	ajmp	codeverify_next
			
; zapis uzamykacich bitov AT89Cx051
lockwrite_1:		
	mov	a,#lb1mode	; zapis 1. uzamykaci bit
	acall	lockwrite
	ret
lockwrite_2:
	acall	lockwrite_1	; automaticky zapis 1. uzamykaci bit potrebny
	mov	a,#lb2mode	; pre zapis 2. uzamykacieho bitu
	acall	lockwrite
	ret
; zapis zvoleneho uzamykacieho bitu
lockwrite:	
	acall	on
	acall	rst12v
	clr	prog		; 1 us PROG impulz
	nop
	setb	prog
	acall	off
	ret

; kontrola bajtov signatury AT89Cx051
signverify:
	mov	a,#sgnmode
	acall	compare_init
	mov	r0,#low (2)	; nastav velkost pamate signatury
	mov	r1,#high (2)
	mov	dptr,#0		; pouzi DPTR ako 16 bitove pocitadlo
	mov	a,#tgtsg1	; skontroluj 1. bajt signatury
	acall	compare_byte
	mov	a,#tgtsg2	; skontroluj 2. bajt signatury
	acall	compare_byte
	acall	isend		; bol dosiahnuty koniec dat signatury
	
; ----------------------------------------------------------------------
; adresa bajtu za poslednou instrukciou tohoto programu
lastinst:
	
	end
