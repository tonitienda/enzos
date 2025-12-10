#include <stdbool.h>
#include <stddef.h>
#include "drivers/keyboard.h"
#include "drivers/terminal.h"
#include "shell/commands.h"

static void print_prompt(void)
{
	terminal_writestring("$ ");
}

static size_t tokenize(char* input, char* argv[], size_t max_args)
{
	size_t argc = 0;
	size_t i = 0;

	while (input[i] != '\0' && argc < max_args) {
		while (input[i] == ' ') {
			++i;
		}

		if (input[i] == '\0') {
			break;
		}

		argv[argc++] = &input[i];

		bool in_quotes = false;
		size_t write_pos = i;

		while (input[i] != '\0') {
			char current = input[i];

			if (current == '"') {
				in_quotes = !in_quotes;
				++i;
				continue;
			}

			if (!in_quotes && current == ' ') {
				break;
			}

			input[write_pos++] = current;
			++i;
		}

		input[write_pos] = '\0';

		if (input[i] == ' ') {
			++i;
		}
	}

	return argc;
}

static void handle_command(char* input)
{
	char* argv[8];
	size_t argc;

	argc = tokenize(input, argv, sizeof(argv) - 1);
	if (argc == 0) {
	        return;
	}

	argv[argc] = NULL;

	if (commands_execute(argv[0], (const char* const*)&argv[1]) == -1) {
	        terminal_writestring("Command ");
	        terminal_writestring(argv[0]);
	        terminal_writestring(" not found.\n");
	}
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
