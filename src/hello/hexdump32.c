// To compile to asm, use something like:
//   cc -S -Os -masm=intel -m32 -nostdlib -ffreestanding -fno-pie -no-pie -fno-asynchronous-unwind-tables hexdump32.c
// To compile for testing:
//   cc -DTEST hexdump32.c -o hexdump32.test
#include <stddef.h>
#include <stdint.h>
#ifdef TEST
#include <stdio.h>
#endif

extern void print_string(size_t len, const char *str);
extern void move_cursor_to_next_line();

const char hex_digit_chars[] = "0123456789abcdef";

char u4_to_hex(uint8_t n) {
    return hex_digit_chars[n & 0x0f];
}

void u8_to_hex(uint8_t x, char *buf) {
    buf[0] = u4_to_hex(x >> 4);
    buf[1] = u4_to_hex(x & 0x0f);
}

void u32_to_hex(uint32_t x, char *buf) {
    for (int i = 0; i < sizeof(x); i++) {
        u8_to_hex((x >> 8*(sizeof(x) - i - 1)) & 0xff, buf+(2*i));
    }
}

void u64_to_hex(uint64_t x, char *buf) {
    for (int i = 0; i < sizeof(x); i++) {
        u8_to_hex((x >> 8*(sizeof(x) - i - 1)) & 0xff, buf+(2*i));
    }
}

void ptr_to_hex(void *p, char *buf) {
#if UINTPTR_MAX == 0xffffffff
    u32_to_hex((uintptr_t) p, buf);
#elif UINTPTR_MAX == 0xffffffffffffffffULL
    u64_to_hex((uintptr_t) p, buf);
#else
    #error "Unknown pointer size or unsupported architecture"
#endif
}

// Prints data in hexadecimal, with lines of the form:
//   0x[32-bit hex address]: [16 hex bytes, e.g., 1a b2 3c d4 ...]
void hexdump(size_t len, uint8_t *data) {
    char out_buf[80] = "0x";
    // Address of the nearest multiple of 16 bytes at or before data
    uint8_t *in_ptr = (uint8_t *) (((uintptr_t) data) & ~0x0f);
    while (in_ptr < data+len) {
        // "0x"
        char *out_ptr = out_buf + 2;
        // "0x12345678"
        ptr_to_hex(in_ptr, out_ptr);
        out_ptr += 2*sizeof(uintptr_t);
        // "0x12345678:"
        *out_ptr = ':';
        out_ptr++;
        // Append hex bytes to output
        for (int i = 0; (i < 16) && (in_ptr < data+len); i++) {
            *out_ptr++ = ' ';
            if (in_ptr >= data) {
                u8_to_hex(*in_ptr, out_ptr);
                out_ptr += 2;
            } else {
                *out_ptr++ = ' ';
                *out_ptr++ = ' ';
            }
            in_ptr++;
        }
        print_string(out_ptr - out_buf, out_buf);
        move_cursor_to_next_line();
    }
}

#ifdef TEST
extern void print_string(size_t len, const char *str) {
    for (int i = 0; i < len; i++) {
        putchar(str[i]);
    }
}

extern void move_cursor_to_next_line() {
    putchar('\n');
}

int main(int argc, char **argv) {
    hexdump(17, (uint8_t *) argv);
}
#endif
