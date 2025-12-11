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

static size_t kstrlen(const char* str)
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

static void kstrncpy(char* dest, const char* src, size_t max_len)
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

static FSNode* resolve_parent_dir(const char* path, char* name, size_t name_size)
{
        char parent_path[128];
        size_t len;
        int last_sep = -1;

        if (!path || !name) {
                return NULL;
        }

        len = kstrlen(path);

        while (len > 1 && path[len - 1] == '/') {
                --len;
        }

        for (size_t i = 0; i < len; ++i) {
                if (path[i] == '/') {
                        last_sep = (int)i;
                }
        }

        if (last_sep == -1) {
                kstrncpy(name, path, name_size);
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

        kstrncpy(name, path + last_sep + 1, name_size);

        {
                FSNode* parent = fs_resolve_path(fs_get_cwd(), parent_path);

                if (parent && fs_is_dir(parent)) {
                        return parent;
                }
        }

        return NULL;
}

static int unlink_child(FSNode* node)
{
        FSNode* parent;
        int index = -1;

        if (!node || !node->parent) {
                return -1;
        }

        parent = node->parent;

        for (int i = 0; i < parent->child_count; ++i) {
                if (parent->children[i] == node) {
                        index = i;
                        break;
                }
        }

        if (index == -1) {
                return -1;
        }

        for (int i = index; i < parent->child_count - 1; ++i) {
                parent->children[i] = parent->children[i + 1];
        }

        parent->children[parent->child_count - 1] = NULL;
        parent->child_count--;
        node->parent = NULL;

        return 0;
}

static int link_child(FSNode* parent, FSNode* node)
{
        if (!parent || !node || !fs_is_dir(parent)) {
                return -1;
        }

        if (fs_lookup(parent, node->name)) {
                return -1;
        }

        if (parent->child_count >= 32) {
                return -1;
        }

        parent->children[parent->child_count++] = node;
        node->parent = parent;

        return 0;
}

static bool is_ancestor(FSNode* ancestor, FSNode* node)
{
        while (node) {
                if (node == ancestor) {
                        return true;
                }
                node = node->parent;
        }

        return false;
}

static int move_node(FSNode* node, FSNode* target_parent, const char* new_name)
{
        FSNode* existing;

        if (!node || !target_parent || !new_name || !fs_is_dir(target_parent)) {
                return -1;
        }

        if (!node->parent) {
                return -1;
        }

        if (is_ancestor(node, target_parent)) {
                return -1;
        }

        existing = fs_lookup(target_parent, new_name);

        if (existing && existing != node) {
                if (fs_is_dir(existing) || !fs_is_file(node)) {
                        return -1;
                }

                if (fs_remove(existing) != 0) {
                        return -1;
                }
        }

        if (unlink_child(node) != 0) {
                return -1;
        }

        kstrncpy(node->name, new_name, sizeof(node->name));

        return link_child(target_parent, node);
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

static int command_ls(const char* const* args, size_t argc)
{
        FSNode* target = fs_get_cwd();

        if (argc > 0) {
                FSNode* resolved = fs_resolve_path(target, args[0]);

                if (!resolved || !fs_is_dir(resolved)) {
                        shell_output_string("ls: cannot access '");
                        shell_output_string(args[0]);
                        shell_output_string("'\n");
                        return -1;
                }

                target = resolved;
        }

        for (int i = 0; i < target->child_count; i++) {
                FSNode* child = target->children[i];
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
        char leaf[32];
        FSNode* parent;
        FSNode* existing;

        if (!name) {
                shell_output_string("touch: missing filename\n");
                return -1;
        }

        parent = resolve_parent_dir(name, leaf, sizeof(leaf));

        if (!parent) {
                shell_output_string("touch: cannot create file '");
                shell_output_string(name);
                shell_output_string("'\n");
                return -1;
        }

        existing = fs_lookup(parent, leaf);
        if (!existing) {
                fs_create_file(parent, leaf);
                return 0;
        }

        if (!fs_is_file(existing)) {
                shell_output_string("touch: cannot create file '");
                shell_output_string(name);
                shell_output_string("': Is a directory\n");
                return -1;
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

static int mkdir_create_parents(const char* path)
{
        FSNode* node;
        size_t i = 0;

        if (!path || path[0] == '\0') {
                return -1;
        }

        node = (path[0] == '/') ? fs_resolve_path(fs_get_cwd(), "/") : fs_get_cwd();

        if (path[0] == '/') {
                i = 1;
        }

        while (path[i] != '\0') {
                char segment[32];
                size_t seg_len = 0;

                while (path[i] == '/') {
                        ++i;
                }

                if (path[i] == '\0') {
                        break;
                }

                while (path[i] != '\0' && path[i] != '/' && seg_len + 1 < sizeof(segment)) {
                        segment[seg_len++] = path[i++];
                }

                segment[seg_len] = '\0';

                if (seg_len == 0 || kstreq(segment, ".")) {
                        continue;
                }

                if (kstreq(segment, "..")) {
                        if (node && node->parent) {
                                node = node->parent;
                        }
                        continue;
                }

                {
                        FSNode* child = fs_lookup(node, segment);

                        if (child) {
                                if (!fs_is_dir(child)) {
                                        return -1;
                                }
                        } else {
                                child = fs_create_dir(node, segment);

                                if (!child) {
                                        return -1;
                                }
                        }

                        node = child;
                }
        }

        return 0;
}

static int command_mkdir(const char* const* names, size_t count)
{
        size_t start = 0;
        bool parents = false;

        if (count == 0) {
                shell_output_string("mkdir: missing operand\n");
                return -1;
        }

        if (names[0] && names[0][0] == '-' && names[0][1] == 'p' && names[0][2] == '\0') {
                parents = true;
                start = 1;
        }

        if (start >= count) {
                shell_output_string("mkdir: missing operand\n");
                return -1;
        }

        for (size_t i = start; i < count; i++) {
                const char* name = names[i];

                if (parents) {
                        if (mkdir_create_parents(name) != 0) {
                                shell_output_string("mkdir: cannot create directory '");
                                shell_output_string(name);
                                shell_output_string("'\n");
                        }
                        continue;
                }

                {
                        char leaf[32];
                        FSNode* parent = resolve_parent_dir(name, leaf, sizeof(leaf));

                        if (!parent) {
                                shell_output_string("mkdir: cannot create directory '");
                                shell_output_string(name);
                                shell_output_string("'\n");
                                continue;
                        }

                        if (!fs_mkdir(parent, leaf)) {
                                shell_output_string("mkdir: cannot create directory '");
                                shell_output_string(name);
                                shell_output_string("'\n");
                        }
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
			shell_output_string("rmdir: failed to remove '");
			shell_output_string(path);
			shell_output_string("': Not a directory\n");
			continue;
		}

		if (!fs_is_empty_dir(target)) {
			shell_output_string("rmdir: failed to remove '");
			shell_output_string(path);
			shell_output_string("': Directory not empty\n");
			continue;
		}

		if (fs_remove(target) != 0) {
			shell_output_string("rmdir: failed to remove '");
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
			shell_output_string("rm: cannot remove '");
			shell_output_string(path);
			shell_output_string("': No such file or directory\n");
			continue;
		}

		if (fs_is_dir(target) && !recursive) {
			shell_output_string("rm: cannot remove '");
			shell_output_string(path);
			shell_output_string("': Is a directory\n");
			continue;
		}

		if (recursive) {
			if (fs_remove_recursive(target) != 0) {
				shell_output_string("rm: failed to remove '");
				shell_output_string(path);
				shell_output_string("'\n");
			}
			continue;
		}

		if (fs_remove(target) != 0) {
			shell_output_string("rm: failed to remove '");
			shell_output_string(path);
			shell_output_string("'\n");
		}
	}

        return 0;
}

static int command_cp(const char* const* args, size_t count)
{
        size_t start_index = 0;
        FSNode* cwd = fs_get_cwd();
        bool recursive = false;

        if (count < 2) {
                shell_output_string("cp: missing file operand\n");
                return -1;
        }

        if (args[0] && args[0][0] == '-' && args[0][1] == 'r' && args[0][2] == '\0') {
                recursive = true;
                start_index = 1;
        }

        if (count - start_index < 2) {
                shell_output_string("cp: missing destination file operand\n");
                return -1;
        }

        {
                const char* dest_path = args[count - 1];
                FSNode* dest_node = fs_resolve_path(cwd, dest_path);
                bool dest_is_dir = dest_node && fs_is_dir(dest_node);

                if ((count - start_index - 1) > 1 && !dest_is_dir) {
                        shell_output_string("cp: target '");
                        shell_output_string(dest_path);
                        shell_output_string("' is not a directory\n");
                        return -1;
                }

                for (size_t i = start_index; i + 1 < count; ++i) {
                        const char* source_path = args[i];
                        FSNode* source_node = fs_resolve_path(cwd, source_path);
                        FSNode* target_parent = NULL;
                        char target_name[32];

                        if (!source_node) {
                                shell_output_string("cp: cannot stat '");
                                shell_output_string(source_path);
                                shell_output_string("'\n");
                                continue;
                        }

                        if (fs_is_dir(source_node) && !recursive) {
                                shell_output_string("cp: -r not specified; omitting directory '");
                                shell_output_string(source_path);
                                shell_output_string("'\n");
                                continue;
                        }

                        if (dest_is_dir) {
                                kstrncpy(target_name, source_node->name, sizeof(target_name));
                                target_parent = dest_node;
                        } else {
                                target_parent = resolve_parent_dir(dest_path, target_name, sizeof(target_name));
                        }

                        if (!target_parent) {
                                shell_output_string("cp: cannot create regular file '");
                                shell_output_string(dest_path);
                                shell_output_string("'\n");
                                continue;
                        }

                        if (is_ancestor(source_node, target_parent)) {
                                shell_output_string("cp: cannot copy directory into itself\n");
                                continue;
                        }

                        if (fs_copy_recursive(source_node, target_parent, target_name) != 0) {
                                shell_output_string("cp: failed to copy '");
                                shell_output_string(source_path);
                                shell_output_string("'\n");
                        }
                }
        }

        return 0;
}

static int command_mv(const char* const* args, size_t count)
{
        FSNode* cwd = fs_get_cwd();

        if (count < 2) {
                shell_output_string("mv: missing file operand\n");
                return -1;
        }

        {
                const char* dest_path = args[count - 1];
                FSNode* dest_node = fs_resolve_path(cwd, dest_path);
                bool dest_is_dir = dest_node && fs_is_dir(dest_node);

                if ((count - 1) > 1 && !dest_is_dir) {
                        shell_output_string("mv: target '");
                        shell_output_string(dest_path);
                        shell_output_string("' is not a directory\n");
                        return -1;
                }

                for (size_t i = 0; i + 1 < count; ++i) {
                        const char* source_path = args[i];
                        FSNode* source_node = fs_resolve_path(cwd, source_path);
                        FSNode* target_parent = NULL;
                        char target_name[32];

                        if (!source_node) {
                                shell_output_string("mv: cannot stat '");
                                shell_output_string(source_path);
                                shell_output_string("'\n");
                                continue;
                        }

                        if (!source_node->parent) {
                                shell_output_string("mv: cannot move root directory\n");
                                continue;
                        }

                        if (dest_is_dir) {
                                kstrncpy(target_name, source_node->name, sizeof(target_name));
                                target_parent = dest_node;
                        } else {
                                target_parent = resolve_parent_dir(dest_path, target_name, sizeof(target_name));
                        }

                        if (!target_parent) {
                                shell_output_string("mv: cannot move to '");
                                shell_output_string(dest_path);
                                shell_output_string("'\n");
                                continue;
                        }

                        if (is_ancestor(source_node, target_parent)) {
                                shell_output_string("mv: cannot move a directory into itself\n");
                                continue;
                        }

                        if (move_node(source_node, target_parent, target_name) != 0) {
                                shell_output_string("mv: cannot move '");
                                shell_output_string(source_path);
                                shell_output_string("'\n");
                        }
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
                return command_ls(args, argc);
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

        if (kstreq(command, "cp")) {
                return command_cp(args, argc);
        }

        if (kstreq(command, "mv")) {
                return command_mv(args, argc);
        }

	if (kstreq(command, "tree")) {
		FSNode* start = fs_get_cwd();

		if (argc > 0) {
			FSNode* resolved = fs_resolve_path(start, args[0]);

			if (!resolved) {
				shell_output_string("tree: '");
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

