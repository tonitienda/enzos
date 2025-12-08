#include <stdbool.h>
#include <stddef.h>
#include "drivers/keyboard.h"
#include "drivers/terminal.h"

static size_t kstrlen(const char* str)
{
        size_t len = 0;
        while (str[len]) {
                len++;
        }
        return len;
}

static bool has_prefix(const char* text, const char* prefix)
{
        for (size_t i = 0; prefix[i] != '\0'; i++) {
                if (text[i] != prefix[i]) {
                        return false;
                }
        }
        return true;
}

static void print_prompt(void)
{
        terminal_writestring("$ ");
}

static void handle_command(const char* input)
{
        if (kstrlen(input) == 0) {
                return;
        }

        if (has_prefix(input, "echo ")) {
                terminal_writestring(input + 5);
                terminal_putchar('\n');
                return;
        }

        terminal_writestring("Unknown command\n");
}

void enzos_shell(void)
{
        char input[128];
        size_t length = 0;

        keyboard_initialize();
        print_prompt();

        while (true) {
                char c = keyboard_getchar();

                if (c == '\n') {
                        terminal_putchar('\n');
                        input[length] = '\0';
                        handle_command(input);
                        length = 0;
                        print_prompt();
                        continue;
                }

                if (length < sizeof(input) - 1) {
                        input[length++] = c;
                        terminal_putchar(c);
                }
        }
}
