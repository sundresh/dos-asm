; Accesses the Program Segment Prefix
; Currently just prints out the command line args

org 0x100

dos_psp:
.offset					equ	0
.command_line_string_len		equ	0x080
.command_line_string			equ	0x081

start:
	call	get_first_arg
	mov	cx, ax
	mov	ah, 0x40	; Write to file handle
	mov	bx, 0x01	; stdout
	int	0x21
	mov	ah, 0x00
	int	0x21

get_first_arg:
	; Args: none
	; Returns:
	;   ax = first arg string length (0 if no args)
	;   dx = first arg string start address
	push	bx

	; Find first non-whitespace char in command line string
	xor	ax, ax
	mov	al, [dos_psp.command_line_string_len]
	mov	dx, dos_psp.command_line_string
	mov	bx, ax
	call	skip_whitespace
	; Check if no non-whitespace char was found
	xchg	ax, bx					; ax = [dos_psp.command_line_string_len]
							; bx = start of first arg
	add	ax, dos_psp.command_line_string		; ax = command line string end
	sub	ax, bx					; ax = length of remaining string
	jz	.no_arg
	; Find first whitespace char after first non-whitespace char
	mov	dx, bx
	call	find_whitespace
	; At this point, bx = start of first arg, ax = end of first arg
	sub	ax, bx					; ax = length of first arg
	mov	dx, bx					; dx = start of first arg
	pop	bx
	ret
.no_arg:
	xor	ax, ax
	xor	dx, dx
	pop	bx
	ret

skip_whitespace:
	; Args:
	;   ax = string length
	;   dx = string start address
	; Returns:
	;   ax = address of first non-whitespace char in string (or end of string if none)
	push	bx

	mov	cx, ax
	mov	bx, dx
	; Loop until cx = 0 or [bx] is non-whitespace
.loop:
	mov	al, [bx]
	inc	bx
	cmp	al, ' '
	sete	dl
	cmp	al, `\n`
	sete	ah
	or	dl, ah
	cmp	al, `\r`
	sete	ah
	or	dl, ah
	cmp	al, `\t`
	sete	ah
	or	dl, ah
	loopne	.loop
	; Loop ended
	; If cx is nonzero, the loop exited because [bx] was not whitespace, so undo extra `inc bx`
	test	cx, cx
	jz	.skip_dec
	dec	bx
.skip_dec:
	mov	ax, bx

	pop	bx
	ret

find_whitespace:
	; Args:
	;   ax = string length
	;   dx = string start address
	; Returns:
	;   ax = address of first whitespace char in string (or end of string if none)
	push	bx

	mov	cx, ax
	mov	bx, dx
	; Loop until cx = 0 or [bx] is non-whitespace
.loop:
	mov	al, [bx]
	inc	bx
	cmp	al, ' '
	sete	dl
	cmp	al, `\n`
	sete	ah
	or	dl, ah
	cmp	al, `\r`
	sete	ah
	or	dl, ah
	cmp	al, `\t`
	sete	ah
	or	dl, ah
	loope	.loop
	; Loop ended
	; If cx is nonzero, the loop exited because [bx] was whitespace, so undo extra `inc bx`
	test	cx, cx
	jz	.skip_dec
	dec	bx
.skip_dec:
	mov	ax, bx

	pop	bx
	ret
