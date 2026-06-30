//#include <stdio.h>

// To compile, use something like:
// cc -S -O3 -masm=intel -m32 -nostdlib -ffreestanding -fno-pie -no-pie -fno-asynchronous-unwind-tables hexdump32.c
#include <stddef.h>
#include <stdint.h>
// Define types here because I don't have -m32 versions of the above headers installed
//typedef unsigned char uint8_t;
//typedef unsigned int uint32_t;
//typedef uint32_t size_t;
//typedef uint32_t uintptr_t;

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
    u8_to_hex(x >> 24, buf);
    u8_to_hex((x >> 16) & 0xff, buf+2);
    u8_to_hex((x >> 8) & 0xff, buf+4);
    u8_to_hex(x & 0xff, buf+6);
}

// Prints data in hexadecimal, with lines of the form:
//   0x[32-bit hex address]: [16 hex bytes, e.g., 1a b2 3c d4 ...]
void hexdump(size_t len, uint8_t *data) {
    char output_buf[80] = "0x";
    uint8_t *in_ptr = (uint8_t *) (((uintptr_t) data) & ~0x0f);
    while (in_ptr < data+len) {
        // "0x"
        char *out_ptr = output_buf + 2;
        // "0x12345678"
        u32_to_hex((uintptr_t) in_ptr, out_ptr);
        out_ptr += 8;
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
        print_string(out_ptr - output_buf, output_buf);
        move_cursor_to_next_line();
    }
}
/*
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
*/