#include <stdbool.h>
#include <stddef.h>
#include "drivers/terminal.h"
#include "shell/commands.h"

static bool kstreq(const char* a, const char* b)
{
	if (!a || !b) {
		return false;
	}

	for (size_t i = 0; a[i] != '\0' || b[i] != '\0'; i++) {
		if (a[i] != b[i]) {
			return false;
		}
	}

	return true;
}

static int command_echo(const char* const* args)
{
	if (!args || !args[0]) {
		terminal_putchar('\n');
		return 0;
	}

	for (size_t i = 0; args[i] != NULL; i++) {
		if (i > 0) {
			terminal_putchar(' ');
		}
		terminal_writestring(args[i]);
	}

	terminal_putchar('\n');
	return 0;
}

int commands_execute(const char* command, const char* const* args)
{
	if (!command) {
		return -1;
	}

	if (kstreq(command, "echo")) {
		return command_echo(args);
	}

	return -1;
}
