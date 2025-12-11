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
static char history_entries[32][128];
static int history_count = 0;

typedef struct {
        char name[32];
        char expansion[128];
} ShellAlias;

static ShellAlias alias_table[16];
static int alias_count = 0;

static size_t shell_strlen(const char* str)
{
        size_t len = 0;

        if (!str) {
                return 0;
        }

        while (str[len] != '\0') {
                ++len;
        }

        return len;
}

static void shell_strncpy(char* dest, const char* src, size_t max_len)
{
        size_t i;

        if (!dest || !src || max_len == 0) {
                return;
        }

        for (i = 0; i + 1 < max_len && src[i] != '\0'; ++i) {
                dest[i] = src[i];
        }

        dest[i] = '\0';
}

static bool shell_streq(const char* a, const char* b)
{
        size_t i = 0;

        if (!a || !b) {
                return false;
        }

        while (a[i] != '\0' || b[i] != '\0') {
                if (a[i] != b[i]) {
                        return false;
                }
                ++i;
        }

        return true;
}

static void shell_output_number(int number)
{
        char buffer[12];
        int index = 0;
        int temp = number;

        if (number == 0) {
                shell_output_char('0');
                return;
        }

        if (number < 0) {
                shell_output_char('-');
                temp = -temp;
        }

        while (temp > 0 && index < (int)(sizeof(buffer) - 1)) {
                buffer[index++] = (char)('0' + (temp % 10));
                temp /= 10;
        }

        while (index > 0) {
                shell_output_char(buffer[--index]);
        }
}

static void shell_history_record(const char* line)
{
        if (!line) {
                return;
        }

        if (history_count < 32) {
                shell_strncpy(history_entries[history_count++], line, sizeof(history_entries[0]));
                return;
        }

        for (int i = 1; i < 32; ++i) {
                shell_strncpy(history_entries[i - 1], history_entries[i], sizeof(history_entries[0]));
        }

        shell_strncpy(history_entries[31], line, sizeof(history_entries[0]));
}

static void shell_print_history(void)
{
        for (int i = 0; i < history_count; ++i) {
                shell_output_number(i + 1);
                shell_output_char(' ');
                shell_output_string(history_entries[i]);
                shell_output_char('\n');
        }
}

static int shell_alias_set(const char* name, const char* expansion)
{
        if (!name || !expansion) {
                return -1;
        }

        for (int i = 0; i < alias_count; ++i) {
                if (shell_streq(alias_table[i].name, name)) {
                        shell_strncpy(alias_table[i].expansion, expansion, sizeof(alias_table[i].expansion));
                        return 0;
                }
        }

        if (alias_count >= 16) {
                return -1;
        }

        shell_strncpy(alias_table[alias_count].name, name, sizeof(alias_table[alias_count].name));
        shell_strncpy(alias_table[alias_count].expansion, expansion, sizeof(alias_table[alias_count].expansion));
        alias_count++;

        return 0;
}

static const char* shell_alias_lookup(const char* name)
{
        for (int i = 0; i < alias_count; ++i) {
                if (shell_streq(alias_table[i].name, name)) {
                        return alias_table[i].expansion;
                }
        }

        return NULL;
}

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
        size_t read_pos = 0;
        size_t write_pos = 0;

        while (input[read_pos] != '\0' && argc < max_args) {
                bool in_quotes = false;

                while (input[read_pos] == ' ' || input[read_pos] == '\t') {
                        ++read_pos;
                }

                if (input[read_pos] == '\0') {
                        break;
                }

                argv[argc++] = &input[write_pos];

                while (input[read_pos] != '\0') {
                        char current = input[read_pos++];

                        if (current == '"') {
                                in_quotes = !in_quotes;
                                continue;
                        }

                        if (!in_quotes && (current == ' ' || current == '\t')) {
                                break;
                        }

                        if (current == '\\') {
                                char next = input[read_pos];

                                if (next == '\0') {
                                        input[write_pos++] = '\\';
                                        break;
                                }

                                if (next == 'n') {
                                        current = '\n';
                                } else if (next == 't') {
                                        current = '\t';
                                } else {
                                        current = next;
                                }

                                ++read_pos;
                        }

                        input[write_pos++] = current;
                }

                input[write_pos++] = '\0';
        }

        return argc;
}

static int find_redirect_index(char* argv[], size_t argc, bool* append)
{
        for (size_t i = 0; i < argc; i++) {
                if (argv[i][0] == '>') {
                        if (argv[i][1] == '>' && argv[i][2] == '\0') {
                                if (append) {
                                        *append = true;
                                }
                                return (int)i;
                        }

                        if (argv[i][1] == '\0') {
                                return (int)i;
                        }
                }
        }

        return -1;
}

static FSNode* resolve_parent_for_path(const char* path, char* leaf, size_t leaf_size)
{
        char parent_path[128];
        size_t len;
        int last_sep = -1;

        if (!path || !leaf) {
                return NULL;
        }

        len = shell_strlen(path);

        while (len > 1 && path[len - 1] == '/') {
                --len;
        }

        for (size_t i = 0; i < len; ++i) {
                if (path[i] == '/') {
                        last_sep = (int)i;
                }
        }

        if (last_sep == -1) {
                shell_strncpy(leaf, path, leaf_size);
                return fs_get_cwd();
        }

        if ((size_t)last_sep >= len - 1) {
                return NULL;
        }

        if (last_sep == 0) {
                parent_path[0] = '/';
                parent_path[1] = '\0';
        } else {
                size_t copy_len = (size_t)last_sep;

                if (copy_len >= sizeof(parent_path)) {
                        copy_len = sizeof(parent_path) - 1;
                }

                for (size_t i = 0; i < copy_len; ++i) {
                        parent_path[i] = path[i];
                }
                parent_path[copy_len] = '\0';
        }

        shell_strncpy(leaf, path + last_sep + 1, leaf_size);

        {
                FSNode* parent = fs_resolve_path(fs_get_cwd(), parent_path);

                if (parent && fs_is_dir(parent)) {
                        return parent;
                }
        }

        return NULL;
}

static void dispatch_command(char* argv[], size_t argc)
{
	(void)argc;

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
        char* argv[12];
        size_t argc;
        char original[128];

        shell_strncpy(original, input, sizeof(original));

        argc = tokenize(input, argv, sizeof(argv) - 1);
        if (argc == 0) {
                return;
        }

        shell_history_record(original);

        argv[argc] = NULL;

        {
                const char* expansion = shell_alias_lookup(argv[0]);

                if (expansion) {
                        char expanded_line[128];
                        size_t write_pos = 0;

                        for (size_t i = 0; expansion[i] != '\0' && write_pos + 1 < sizeof(expanded_line); ++i) {
                                expanded_line[write_pos++] = expansion[i];
                        }

                        for (size_t i = 1; i < argc; ++i) {
                                size_t arg_len = shell_strlen(argv[i]);

                                if (write_pos + arg_len + 1 >= sizeof(expanded_line)) {
                                        shell_output_string("alias: expansion too long\n");
                                        return;
                                }

                                expanded_line[write_pos++] = ' ';

                                for (size_t j = 0; j < arg_len && write_pos + 1 < sizeof(expanded_line); ++j) {
                                        expanded_line[write_pos++] = argv[i][j];
                                }
                        }

                        expanded_line[write_pos] = '\0';
                        argc = tokenize(expanded_line, argv, sizeof(argv) - 1);
                        argv[argc] = NULL;
                }
        }

        if (shell_streq(argv[0], "history")) {
                shell_print_history();
                return;
        }

        if (shell_streq(argv[0], "alias")) {
                if (argc == 1) {
                        for (int i = 0; i < alias_count; ++i) {
                                shell_output_string(alias_table[i].name);
                                shell_output_string("=");
                                shell_output_char('"');
                                shell_output_string(alias_table[i].expansion);
                                shell_output_char('"');
                                shell_output_char('\n');
                        }
                        return;
                }

                for (size_t i = 1; i < argc; ++i) {
                        const char* entry = argv[i];
                        size_t j = 0;
                        int equal_pos = -1;

                        while (entry[j] != '\0') {
                                if (entry[j] == '=') {
                                        equal_pos = (int)j;
                                        break;
                                }
                                ++j;
                        }

                        if (equal_pos == -1) {
                                shell_output_string("alias: invalid format\n");
                                return;
                        }

                        {
                                char name[32];
                                char expansion[128];
                                size_t name_len = (size_t)equal_pos;

                                if (name_len >= sizeof(name)) {
                                        name_len = sizeof(name) - 1;
                                }

                                for (size_t k = 0; k < name_len; ++k) {
                                        name[k] = entry[k];
                                }
                                name[name_len] = '\0';

                                shell_strncpy(expansion, entry + equal_pos + 1, sizeof(expansion));

                                if (shell_alias_set(name, expansion) != 0) {
                                        shell_output_string("alias: failed to set alias\n");
                                        return;
                                }
                        }
                }

                return;
        }

        if (shell_streq(argv[0], "clear")) {
                terminal_clear_screen();
                terminal_set_cursor(0, 0);
                return;
        }

        {
                bool append = false;
                int redirect_index = find_redirect_index(argv, argc, &append);

                if (redirect_index != -1) {
                        char* filename;
                        char buffer[1024];
                        FSNode* parent;
                        char leaf[32];
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

                        parent = resolve_parent_for_path(filename, leaf, sizeof(leaf));

                        if (!parent) {
                                shell_output_string("redirection: invalid path\n");
                                return;
                        }

                        file = fs_lookup(parent, leaf);
                        if (!file) {
                                file = fs_create_file(parent, leaf);
                        }

                        if (!file) {
                                shell_output_string("redirection: failed to write file\n");
                                return;
                        }

                        if ((!append && fs_write(file, buffer) != 0) || (append && fs_append(file, buffer) != 0)) {
                                shell_output_string("redirection: failed to write file\n");
                        }

                        return;
                }
        }

        dispatch_command(argv, argc);
}

void enzos_shell(void)
{
	char input[128];
	size_t length = 0;
	size_t prompt_col;

	keyboard_initialize();
	print_prompt();
	prompt_col = terminal_column;

	while (true) {
		char c = keyboard_getchar();

		if (c == '\n') {
			terminal_putchar('\n');
			input[length] = '\0';
			handle_command(input);
			length = 0;
			print_prompt();
			prompt_col = terminal_column;
			continue;
		}

		if (c == '\b') {
			if (length > 0 && terminal_column > prompt_col) {
				size_t col;
				size_t row;

				length--;

				col = terminal_column;
				row = terminal_row;

				/* Move cursor back */
				if (col > 0) {
					col--;
				}

				terminal_set_cursor(col, row);
				terminal_putchar(' ');
				terminal_set_cursor(col, row);
			}
			continue;
		}

		if (length < sizeof(input) - 1) {
			input[length++] = c;
			terminal_putchar(c);
		}
	}
}
