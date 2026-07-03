; Loads the contents of the first file passed on the command line at 1MB if it exists and
; its size is at most 16MB.

org 0x100

dos_psp:
.offset				equ	0
.command_line_string_len	equ	0x080
.command_line_string		equ	0x081

file_contents_buf		equ	0x100000
file_contents_buf.len		equ	0x1000000

start:
	call	enter_unreal_mode
	call	get_first_arg
	; Set up args for read_file_contents
	; Already set from get_first_arg: ax = first arg string length, dx = first arg addr
	mov	ecx, file_contents_buf.len
	mov	ebx, ds
	shl	ebx, 4
	neg	ebx
	add	ebx, file_contents_buf		; bx = Offset of file_contents_buf relative to DS
	call	read_file_contents
	jnc	.exit
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
	;   ecx = buffer length
	;   ebx = address of buffer
	; TODO: Use ecx & ebx so we can copy a larger file to a higher address in chunks.
.BPO_buf_addr		equ	0	; Offsets from bp
.BPO_file_path_len	equ	-2
.BPO_buf_len		equ	-6
.BPO_file_path_addr	equ	-8
.BPO_file_len		equ	-12
.SPO_file_path_copy	equ	0	; Offset from sp
	push	es
	push	bp
	push	ebx
	mov	bp, sp
	push	ax
	push	ecx
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
	; - Consolidate file length in one 32-bit register
	shl	edx, 16
	mov	dx, ax
	; - Compare file length to buffer length
	mov	eax, [bp+.BPO_buf_len]
	cmp	edx, eax
	ja	.err_close_bx
	; - Save file length to stack
	mov	[bp+.BPO_file_len], edx
	; - Seek back to beginning (already set: bx = file handle)
	xor	cx, cx		; dx:cx = Seek offset 0 from beginning
	xor	dx, dx
	mov	ax, 0x4200	; Seek file handle from beginning
	int	0x21
	jc	.err_close_bx
	; Read contents (already set: bx = file handle)
	mov	edi, [bp+.BPO_buf_addr]
	mov	cx, ds
	mov	es, cx
.loop:
	; - Load a chunk of data
	mov	cx, copy_buf.len
	mov	dx, copy_buf
	mov	ah, 0x3f	; Read from file with handle
	int	0x21
	jc	.err_close_bx
	cmp	ax, 0		; Double check that at least one byte was read
	je	.err_close_bx
	; - Copy data to destination buffer
	mov	esi, copy_buf
	xor	ecx, ecx
	mov	cx, ax
	a32 rep movsb
	; - Loop back unless all data has been copied
	mov	eax, [bp+.BPO_buf_addr]
	add	eax, [bp+.BPO_file_len]
	cmp	edi, eax
	jb	.loop
	; Close file (already set: bx = file handle)
	mov	ah, 0x3e	; Close file with handle
	int	0x21
	; Return length read into buffer
	mov	ax, [bp+.BPO_file_len]
	cmp	sp, 0		; Clear CF to indicate not an error.
.exit:
	mov	sp, bp
	pop	ebx
	pop	bp
	pop	es
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

%include "enter_unreal_mode.inc"

copy_buf:
.len			equ	32768
