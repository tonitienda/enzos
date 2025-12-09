#include "keyboard.h"

#if defined(__linux__) && !defined(ALLOW_HOST_TOOLCHAIN)
#error "You are not using a cross-compiler, you will most certainly run into trouble"
#endif

#if !defined(__i386__)
#error "This tutorial needs to be compiled with a ix86-elf compiler"
#endif

#define KEYBOARD_DATA_PORT 0x60
#define KEYBOARD_STATUS_PORT 0x64

static bool shift_pressed = false;

static inline uint8_t inb(uint16_t port)
{
        uint8_t result;
        __asm__ __volatile__("inb %1, %0" : "=a"(result) : "Nd"(port));
        return result;
}

static char base_keymap[128] = {
        [0x01] = '\033', /* Escape */
        [0x02] = '1',
        [0x03] = '2',
        [0x04] = '3',
        [0x05] = '4',
        [0x06] = '5',
        [0x07] = '6',
        [0x08] = '7',
        [0x09] = '8',
        [0x0A] = '9',
        [0x0B] = '0',
        [0x0C] = '-',
        [0x0D] = '=',
        [0x0E] = '\b',
        [0x0F] = '\t',
        [0x10] = 'q',
        [0x11] = 'w',
        [0x12] = 'e',
        [0x13] = 'r',
        [0x14] = 't',
        [0x15] = 'y',
        [0x16] = 'u',
        [0x17] = 'i',
        [0x18] = 'o',
        [0x19] = 'p',
        [0x1A] = '[',
        [0x1B] = ']',
        [0x1C] = '\n',
        [0x1E] = 'a',
        [0x1F] = 's',
        [0x20] = 'd',
        [0x21] = 'f',
        [0x22] = 'g',
        [0x23] = 'h',
        [0x24] = 'j',
        [0x25] = 'k',
        [0x26] = 'l',
        [0x27] = ';',
        [0x28] = '\'',
        [0x29] = '`',
        [0x2B] = '\\',
        [0x2C] = 'z',
        [0x2D] = 'x',
        [0x2E] = 'c',
        [0x2F] = 'v',
        [0x30] = 'b',
        [0x31] = 'n',
        [0x32] = 'm',
        [0x33] = ',',
        [0x34] = '.',
        [0x35] = '/',
        [0x39] = ' ',
};

static char shifted_keymap[128] = {
        [0x02] = '!',
        [0x03] = '@',
        [0x04] = '#',
        [0x05] = '$',
        [0x06] = '%',
        [0x07] = '^',
        [0x08] = '&',
        [0x09] = '*',
        [0x0A] = '(',
        [0x0B] = ')',
        [0x0C] = '_',
        [0x0D] = '+',
        [0x10] = 'Q',
        [0x11] = 'W',
        [0x12] = 'E',
        [0x13] = 'R',
        [0x14] = 'T',
        [0x15] = 'Y',
        [0x16] = 'U',
        [0x17] = 'I',
        [0x18] = 'O',
        [0x19] = 'P',
        [0x1A] = '{',
        [0x1B] = '}',
        [0x1E] = 'A',
        [0x1F] = 'S',
        [0x20] = 'D',
        [0x21] = 'F',
        [0x22] = 'G',
        [0x23] = 'H',
        [0x24] = 'J',
        [0x25] = 'K',
        [0x26] = 'L',
        [0x27] = ':',
        [0x28] = '"',
        [0x29] = '~',
        [0x2B] = '|',
        [0x2C] = 'Z',
        [0x2D] = 'X',
        [0x2E] = 'C',
        [0x2F] = 'V',
        [0x30] = 'B',
        [0x31] = 'N',
        [0x32] = 'M',
        [0x33] = '<',
        [0x34] = '>',
        [0x35] = '?',
};

static char translate_scancode(uint8_t scancode)
{
        char translated = 0;

        if (shift_pressed && shifted_keymap[scancode] != 0) {
                translated = shifted_keymap[scancode];
        } else {
                translated = base_keymap[scancode];
        }

        if (translated >= 'a' && translated <= 'z' && shift_pressed) {
            translated = translated - ('a' - 'A');
        }

        return translated;
}

static void handle_modifier_keys(uint8_t scancode)
{
        if (scancode == 0x2A || scancode == 0x36) {
                shift_pressed = true;
        }

        if (scancode == 0xAA || scancode == 0xB6) {
                shift_pressed = false;
        }
}

void keyboard_initialize(void)
{
        shift_pressed = false;
}

char keyboard_getchar(void)
{
        while (true) {
                while ((inb(KEYBOARD_STATUS_PORT) & 0x01) == 0) {
                }

                uint8_t scancode = inb(KEYBOARD_DATA_PORT);
                handle_modifier_keys(scancode);

                if (scancode & 0x80) {
                        continue; /* Ignore key releases. */
                }

                char translated = translate_scancode(scancode);
                if (translated != 0) {
                        return translated;
                }
        }
}
