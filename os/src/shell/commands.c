#include <stdbool.h>
#include <stddef.h>
#include "fs.h"
#include "shell/commands.h"
#include "shell/shell.h"

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

static size_t arg_count(const char* const* args)
{
	size_t count = 0;

	if (!args) {
		return count;
	}

	while (args[count] != NULL) {
		++count;
	}

	return count;
}

static int command_echo(const char* const* args)
{
	if (!args || !args[0]) {
		shell_output_char('\n');
		return 0;
	}

	for (size_t i = 0; args[i] != NULL; i++) {
		if (i > 0) {
			shell_output_char(' ');
		}
		shell_output_string(args[i]);
	}

	shell_output_char('\n');
	return 0;
}

static int command_pwd(void)
{
	FSNode* cwd = fs_get_cwd();

	shell_print_path(cwd);
	shell_output_char('\n');
	return 0;
}

static int command_ls(void)
{
	FSNode* cwd = fs_get_cwd();

	for (int i = 0; i < cwd->child_count; i++) {
		FSNode* child = cwd->children[i];
		shell_output_string(child->name);
		if (child->type == NODE_DIR) {
			shell_output_char('/');
		}
		shell_output_char(' ');
	}

	shell_output_char('\n');
	return 0;
}

static int command_cd(const char* path)
{
	FSNode* target;

	if (!path) {
		shell_output_string("cd: missing argument\n");
		return -1;
	}

	target = fs_resolve_path(fs_get_cwd(), path);
	if (!target || target->type != NODE_DIR) {
		shell_output_string("cd: no such directory: ");
		shell_output_string(path);
		shell_output_char('\n');
		return -1;
	}

	fs_set_cwd(target);
	return 0;
}

static int command_touch(const char* name)
{
	FSNode* cwd = fs_get_cwd();
	FSNode* existing;

	if (!name) {
		shell_output_string("touch: missing filename\n");
		return -1;
	}

	existing = fs_lookup(cwd, name);
	if (!existing) {
		fs_create_file(cwd, name);
	}

	return 0;
}

static int command_cat(const char* path)
{
	FSNode* cwd = fs_get_cwd();
	FSNode* file;
	const char* data;

	if (!path) {
		shell_output_string("cat: missing filename\n");
		return -1;
	}

	file = fs_resolve_path(cwd, path);
	if (!file || file->type != NODE_FILE) {
		shell_output_string("cat: no such file: ");
		shell_output_string(path);
		shell_output_char('\n');
		return -1;
	}

	data = fs_read(file);
	if (data) {
		shell_output_string(data);
		shell_output_char('\n');
	}

	return 0;
}

static int command_mkdir(const char* name)
{
	FSNode* cwd = fs_get_cwd();

	if (!name) {
		shell_output_string("mkdir: missing dirname\n");
		return -1;
	}

	if (!fs_lookup(cwd, name)) {
		fs_create_dir(cwd, name);
	}

	return 0;
}

int commands_execute(const char* command, const char* const* args)
{
	size_t argc;

	if (!command) {
		return -1;
	}

	argc = arg_count(args);

	if (kstreq(command, "echo")) {
		return command_echo(args);
	}

	if (kstreq(command, "pwd")) {
		return command_pwd();
	}

	if (kstreq(command, "ls")) {
		return command_ls();
	}

	if (kstreq(command, "cd")) {
		return command_cd(argc > 0 ? args[0] : NULL);
	}

	if (kstreq(command, "touch")) {
		return command_touch(argc > 0 ? args[0] : NULL);
	}

	if (kstreq(command, "cat")) {
		return command_cat(argc > 0 ? args[0] : NULL);
	}

	if (kstreq(command, "mkdir")) {
		return command_mkdir(argc > 0 ? args[0] : NULL);
	}

	return -1;
}
