; Prints out the contents of the first file passed on the command line if it exists and is <= 32kB

org 0x100

dos_psp:
.offset					equ	0
.command_line_string_len		equ	0x080
.command_line_string			equ	0x081

start:
	call	get_first_arg
	mov	cx, file_contents_buf.len
	mov	bx, file_contents_buf
	call	read_file_contents
	jc	.error
.print:
	mov	cx, ax				; cx = String length
	mov	dx, bx				; dx = String start address
	mov	bx, 0x01			; bx = stdout
	mov	ah, 0x40			; Write to file handle
	int	0x21
	jmp	.exit
.error:
	mov	cx, error_reading_file_str.len	; cx = String length
	mov	dx, error_reading_file_str	; dx = String start address
	mov	bx, 0x01			; bx = stdout
	mov	ah, 0x40			; Write to file handle
	int	0x21
.exit:
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
	dec	bx
.loop:
	inc	bx
	mov	al, [bx]
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
	dec	bx
.loop:
	inc	bx
	mov	al, [bx]
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
	mov	ax, bx

	pop	bx
		ret

read_file_contents:
	; Args:
	;   ax = file path length
	;   dx = address of file path
	;   cx = buffer length
	;   bx = address of buffer
	; TODO: Use ecx & ebx so we can copy a larger file to a higher address in chunks.
.BPO_buf_addr		equ	0	; Offsets from bp
.BPO_file_path_len	equ	-2
.BPO_buf_len		equ	-4
.BPO_file_path_addr	equ	-6
.BPO_file_len		equ	-8
.SPO_file_path_copy	equ	0	; Offset from sp
	push	bp
	push	bx
	mov	bp, sp
	push	ax
	push	cx
	push	dx
	sub	sp, 2
	push	byte 0		; Terminating null for copy of file path
	sub	sp, ax

	; Copy file path string onto the stack (terminating null byte pushed above)
	mov	si, dx
	mov	di, sp
	mov	cx, ax
	rep movsb
	; Open file
	mov	ax, 0x3d00	; Open file read-only
	mov	dx, sp		; File path (null-terminated)
	int	0x21
	jc	.err		; Else ax = file handle
	; Get file length
	; - Seek to end & get file length
	mov	bx, ax		; bx = Open file handle
	xor	cx, cx		; dx:cx = Seek offset 0 from end
	xor	dx, dx
	mov	ax, 0x4202	; Seek file handle from end
	int	0x21
	jc	.err_close_bx	; Else dx:ax = file length
	; - Compare file length to buffer length
	test	dx, dx
	jnz	.err_close_bx	; File length >= 64kB > buffer length
	mov	cx, [bp+.BPO_buf_len]
	cmp	ax, cx
	ja	.err_close_bx	; 64kB > File length > buffer length
	; - Save file length to stack
	mov	[bp+.BPO_file_len], ax
	; - Seek back to beginning (already set: bx = file handle)
	xor	cx, cx		; dx:cx = Seek offset 0 from beginning
	xor	dx, dx
	mov	ax, 0x4200	; Seek file handle from beginning
	int	0x21
	jc	.err_close_bx
	; Read contents (already set: bx = file handle)
	mov	cx, [bp+.BPO_file_len]
	mov	dx, [bp+.BPO_buf_addr]
	mov	ah, 0x3f	; Read from file with handle
	int	0x21
	jc	.err_close_bx
	cmp	ax, cx		; Double check that the requested number of bytes were read
	jne	.err_close_bx
	; Close file (already set: bx = file handle)
	mov	ah, 0x3e	; Close file with handle
	int	0x21
	; Return length read into buffer
	mov	ax, [bp+.BPO_file_len]
	cmp	sp, 0		; Clear CF to indicate not an error.
.exit:
	mov	sp, bp
	pop	bx
	pop	bp
	ret
.err_close_bx:
	; Close file (already set: bx = file handle)
	mov	ah, 0x3e	; Close file with handle
	int	0x21
.err:
	xor	ax, ax
	cmp	sp, 0xffff	; Set CF to indicate an error.
	jmp	.exit

%macro dstr 1
			db	%1
.len			equ	%strlen(%1)
%endmacro

error_reading_file_str	dstr	"Error reading file"

file_contents_buf:
.len			equ	32768
