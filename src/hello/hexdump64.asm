hexdump:
	; Prints data in hexadecimal, with lines of the form:
	;   0x[64-bit hex address]: [16 hex bytes, e.g., 1a b2 3c d4 ...]
	;
	; rax = number of bytes
	; rdx = data start address
	;
	; Requires print_string and move_cursor_to_next_line
	push	rbx
	push	rsi
	push	rdi
	sub	rsp, 80		; rsp = Line buffer

	mov	rsi, rdx	; esi = Next byte
	and	rsi, ~15	; Round esi down to a multiple of 16
	mov	rbx, rdx
	sub	rbx, rsi
	add	rbx, rax	; ebx = Num bytes remaining
.lines_loop:
	cmp	rbx, 0
	je	.all_lines_done
	mov	rdi, rsp	; edi = Next byte to write in line buffer
	; Format address on left side of line
	mov	[rdi], word "0x"
	add	rdi, 2
	mov	rax, rsi
	mov	rdx, rdi
	call	u64_to_hex
	add	rdi, 16
	mov	[rdi], word ":"
	add	rdi, 2
.bytes_loop:
	; Format byte as a space followed by two hex digits
	mov	[rdi], byte ' '
	inc	rdi
	mov	al, [rsi]
	call	u8_to_hex
	mov	[rdi], ax
	add	rdi, 2
	; Loop bounds checks
	dec	rbx
	test	rbx, rbx
	jz	.all_lines_done
	inc	rsi
	test	rsi, 15		; Start a new line at each multiple of 16
	jnz	.bytes_loop
	; Print the line
	mov	rax, rdi
	sub	rax, rsp
	mov	rdx, rsp
	call	print_string
	call	move_cursor_to_next_line
	jmp	.lines_loop
.all_lines_done:
	cmp	rdi, rsp
	je	.all_done
	; Print the incomplete last line
	mov	rax, rdi
	sub	rax, rsp
	mov	rdx, rsp
	call	print_string
	call	move_cursor_to_next_line
.all_done:

	add	rsp, 80
	pop	rdi
	pop	rsi
	pop	rbx
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
	and	ah, 0x0f	; ah = Low order 4 bits
	movzx	ecx, ah
	mov	ah, [.hex_digit_to_char + ecx]
	movzx	ecx, al
	mov	al, [.hex_digit_to_char + ecx]
	ret
.hex_digit_to_char	db	"0123456789abcdef"



u64_to_hex:
	; Input:
	; 	rax = Input 64 bits
	; 	rdx = Output address--must have at least 8 bytes available
	push	rbx
	push	r8

	mov	rbx, rax
	bswap	rbx
	mov	ecx, 8
.loop:
	mov	al, bl
	mov	r8, rcx
	call	u8_to_hex
	mov	rcx, r8
	mov	[rdx], ax
	shr	rbx, 8
	add	rdx, 2
	loop	.loop

	pop	r8
	pop	rbx
	ret
