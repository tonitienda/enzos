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

static int command_mkdir(const char* const* names, size_t count)
{
	FSNode* cwd = fs_get_cwd();

	if (count == 0) {
		shell_output_string("mkdir: missing operand\n");
		return -1;
	}

	for (size_t i = 0; i < count; i++) {
		const char* name = names[i];
		FSNode* dir = fs_mkdir(cwd, name);

		if (!dir) {
			shell_output_string("mkdir: cannot create directory '\");
			shell_output_string(name);
			shell_output_string("'\n");
		}
	}

	return 0;
}

static int command_rmdir(const char* const* args, size_t count)
{
	if (count == 0) {
		shell_output_string("rmdir: missing operand\n");
		return -1;
	}

	for (size_t i = 0; i < count; i++) {
		const char* path = args[i];
		FSNode* target = fs_resolve_path(fs_get_cwd(), path);

		if (!target || !fs_is_dir(target)) {
			shell_output_string("rmdir: failed to remove '\");
			shell_output_string(path);
			shell_output_string("': Not a directory\n");
			continue;
		}

		if (!fs_is_empty_dir(target)) {
			shell_output_string("rmdir: failed to remove '\");
			shell_output_string(path);
			shell_output_string("': Directory not empty\n");
			continue;
		}

		if (fs_remove(target) != 0) {
			shell_output_string("rmdir: failed to remove '\");
			shell_output_string(path);
			shell_output_string("'\n");
		}
	}

	return 0;
}

static int command_rm(const char* const* args, size_t count)
{
	size_t start_index = 0;
	bool recursive = false;

	if (count == 0) {
		shell_output_string("rm: missing operand\n");
		return -1;
	}

	if (args[0] && args[0][0] == '-' && args[0][1] == 'r' && args[0][2] == '\0') {
		recursive = true;
		start_index = 1;
	}

	if (start_index >= count) {
		shell_output_string("rm: missing operand\n");
		return -1;
	}

	for (size_t i = start_index; i < count; i++) {
		const char* path = args[i];
		FSNode* target = fs_resolve_path(fs_get_cwd(), path);

		if (!target) {
			shell_output_string("rm: cannot remove '\");
			shell_output_string(path);
			shell_output_string("': No such file or directory\n");
			continue;
		}

		if (fs_is_dir(target) && !recursive) {
			shell_output_string("rm: cannot remove '\");
			shell_output_string(path);
			shell_output_string("': Is a directory\n");
			continue;
		}

		if (recursive) {
			if (fs_remove_recursive(target) != 0) {
				shell_output_string("rm: failed to remove '\");
				shell_output_string(path);
				shell_output_string("'\n");
			}
			continue;
		}

		if (fs_remove(target) != 0) {
			shell_output_string("rm: failed to remove '\");
			shell_output_string(path);
			shell_output_string("'\n");
		}
	}

	return 0;
}

static void shell_print_tree_node(FSNode* node, int depth)
{
	for (int i = 0; i < depth; i++) {
		shell_output_string("  ");
	}

	if (node->parent) {
		shell_output_string(node->name);
		if (fs_is_dir(node)) {
			shell_output_char('/');
		}
	} else {
		shell_output_char('/');
	}

	shell_output_char('\n');

	if (!fs_is_dir(node)) {
		return;
	}

	for (int i = 0; i < node->child_count; i++) {
		shell_print_tree_node(node->children[i], depth + 1);
	}
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
		return command_mkdir(args, argc);
	}

	if (kstreq(command, "rmdir")) {
		return command_rmdir(args, argc);
	}

	if (kstreq(command, "rm")) {
		return command_rm(args, argc);
	}

	if (kstreq(command, "tree")) {
		FSNode* start = fs_get_cwd();

		if (argc > 0) {
			FSNode* resolved = fs_resolve_path(start, args[0]);

			if (!resolved) {
				shell_output_string("tree: '\");
				shell_output_string(args[0]);
				shell_output_string("': No such file or directory\n");
				return -1;
			}

			start = resolved;
		}

		shell_print_tree_node(start, 0);
		return 0;
	}

	return -1;
}

