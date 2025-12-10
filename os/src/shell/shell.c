#include <stdbool.h>
#include <stddef.h>
#include "drivers/keyboard.h"
#include "drivers/terminal.h"
#include "fs.h"
#include "shell/commands.h"
#include "shell/shell.h"

static char* capture_buffer = NULL;
static size_t capture_capacity = 0;
static size_t capture_length = 0;
static bool capture_active = false;

void shell_capture_output_begin(char* buffer, size_t capacity)
{
	capture_buffer = buffer;
	capture_capacity = capacity;
	capture_length = 0;

	if (capture_buffer && capture_capacity > 0) {
		capture_buffer[0] = '\0';
	}

	capture_active = true;
}

void shell_capture_output_end(void)
{
	capture_active = false;
	capture_buffer = NULL;
	capture_capacity = 0;
	capture_length = 0;
}

void shell_output_char(char c)
{
	if (capture_active && capture_buffer && capture_capacity > 0) {
		if (capture_length + 1 < capture_capacity) {
			capture_buffer[capture_length++] = c;
			capture_buffer[capture_length] = '\0';
		}
		return;
	}

	terminal_putchar(c);
}

void shell_output_string(const char* data)
{
	size_t i = 0;

	if (!data) {
		return;
	}

	while (data[i] != '\0') {
		shell_output_char(data[i]);
		++i;
	}
}

void shell_print_path(FSNode* node)
{
	FSNode* stack[32];
	int depth = 0;

	while (node && depth < 32) {
		stack[depth++] = node;
		node = node->parent;
	}

	for (int i = depth - 1; i >= 0; --i) {
		FSNode* current = stack[i];

		if (!current->parent) {
			shell_output_char('/');
			if (i == 0) {
				return;
			}
			continue;
		}

		shell_output_string(current->name);
		if (i > 0) {
			shell_output_char('/');
		}
	}
}

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

		char delimiter = input[i];
		input[write_pos] = '\0';

		if (delimiter == ' ') {
			++i;
		}
	}

	return argc;
}

static int find_redirect_index(char* argv[], size_t argc)
{
	for (size_t i = 0; i < argc; i++) {
		if (argv[i][0] == '>' && argv[i][1] == '\0') {
			return (int)i;
		}
	}

	return -1;
}

static void dispatch_command(char* argv[], size_t argc)
{
	if (!argv[0]) {
		return;
	}

	if (commands_execute(argv[0], (const char* const*)&argv[1]) == -1) {
		shell_output_string("Command ");
		shell_output_string(argv[0]);
		shell_output_string(" not found.\n");
	}
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

	int redirect_index = find_redirect_index(argv, argc);
	if (redirect_index != -1) {
		char* filename;
		char buffer[1024];
		FSNode* cwd;
		FSNode* file;

		if ((size_t)redirect_index + 1 >= argc) {
			shell_output_string("redirection: missing file\n");
			return;
		}

		filename = argv[redirect_index + 1];
		argv[redirect_index] = NULL;

		shell_capture_output_begin(buffer, sizeof(buffer));
		dispatch_command(argv, (size_t)redirect_index);
		shell_capture_output_end();

		cwd = fs_get_cwd();
		file = fs_lookup(cwd, filename);
		if (!file) {
			file = fs_create_file(cwd, filename);
		}

		if (!file || fs_write(file, buffer) != 0) {
			shell_output_string("redirection: failed to write file\n");
		}

		return;
	}

	dispatch_command(argv, argc);
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
