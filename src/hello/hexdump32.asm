hexdump:
	; Prints data in hexadecimal, with lines of the form:
	;   0x[32-bit hex address]: [16 hex bytes, e.g., 1a b2 3c d4 ...]
	;
	; eax = number of bytes
	; edx = data start address
	;
	; Requires print_string and move_cursor_to_next_line
	push	ebx
	push	esi
	push	edi
	sub	esp, 80		; esp = Line buffer

	mov	esi, edx	; esi = Next byte
	and	esi, ~15	; Round esi down to a multiple of 16
	mov	ebx, edx
	sub	ebx, esi
	add	ebx, eax	; ebx = Num bytes remaining
.lines_loop:
	cmp	ebx, 0
	je	.all_lines_done
	mov	edi, esp	; edi = Next byte to write in line buffer
	; Format address on left side of line
	mov	[edi], word "0x"
	add	edi, 2
	mov	eax, esi
	mov	edx, edi
	call	u32_to_hex
	add	edi, 8
	mov	[edi], word ":"
	add	edi, 2
.bytes_loop:
	; Format byte as a space followed by two hex digits
	mov	[edi], byte ' '
	inc	edi
	mov	al, [esi]
	call	u8_to_hex
	mov	[edi], ax
	add	edi, 2
	; Loop bounds checks
	dec	ebx
	test	ebx, ebx
	jz	.all_lines_done
	inc	esi
	test	esi, 15		; Start a new line at each multiple of 16
	jnz	.bytes_loop
	; Print the line
	mov	eax, edi
	sub	eax, esp
	mov	edx, esp
	call	print_string
	call	move_cursor_to_next_line
	jmp	.lines_loop
.all_lines_done:
	cmp	edi, esp
	je	.all_done
	; Print the incomplete last line
	mov	eax, edi
	sub	eax, esp
	mov	edx, esp
	call	print_string
	call	move_cursor_to_next_line
.all_done:

	add	esp, 80
	pop	edi
	pop	esi
	pop	ebx
	ret


u8_to_hex:
	; Input:
	;   al = Input byte
	; Output:
	;   al = High order hex digit
	;   ah = Low order hex digit
	; The output order is intentionally reversed so you can directly copy it into memory.
	mov	ah, al
	shr	al, 4		; al = High order 4 bits
	and	al, 0x0f
	and	ah, 0x0f	; ah = Low order 4 bits
	cmp	al, 9
	ja	.first_hex_digit_is_a_letter
	add	al, '0'
	jmp	.format_second_hex_digit
.first_hex_digit_is_a_letter:
	add	al, 'a' - 0x0a
.format_second_hex_digit:
	cmp	ah, 9
	ja	.second_hex_digit_is_a_letter
	add	ah, '0'
	ret
.second_hex_digit_is_a_letter:
	add	ah, 'a' - 0x0a
	ret


u32_to_hex:
	; Input:
	; 	eax = Input 32 bits
	; 	edx = Output address--must have at least 8 bytes available
	push	ebx

	mov	ebx, eax
	; Highest order byte
	shr	eax, 24
	call	u8_to_hex
	mov	[edx], ax
	; Second highest order byte
	mov	eax, ebx
	shr	eax, 16
	call	u8_to_hex
	mov	[edx+2], ax
	; Third highest order byte
	mov	eax, ebx
	shr	eax, 8
	call	u8_to_hex
	mov	[edx+4], ax
	; Lowest order byte
	mov	eax, ebx
	call	u8_to_hex
	mov	[edx+6], ax

	pop	ebx
	ret
