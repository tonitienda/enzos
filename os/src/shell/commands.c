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

typedef int (*command_handler)(const char* const* args);

struct command_entry {
	const char* name;
	command_handler handler;
};

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

static const struct command_entry command_table[] = {
	{ "echo", command_echo },
};

int commands_execute(const char* command, const char* const* args)
{
	for (size_t i = 0; i < sizeof(command_table) / sizeof(command_table[0]); i++) {
	        if (kstreq(command_table[i].name, command)) {
	                return command_table[i].handler(args);
	        }
	}

	return -1;
}
