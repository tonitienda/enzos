#include <stddef.h>
#include "fs.h"

/* Check if the compiler thinks you are targeting the wrong operating system. */
#if defined(__linux__) && !defined(ALLOW_HOST_TOOLCHAIN)
#error "You are not using a cross-compiler, you will most certainly run into trouble"
#endif

/* This tutorial will only work for the 32-bit ix86 targets. */
#if !defined(__i386__)
#error "This tutorial needs to be compiled with a ix86-elf compiler"
#endif

#define FS_MAX_NODES 128
#define FS_CONTENT_POOL_SIZE 4096

static FSNode node_pool[FS_MAX_NODES];
static size_t node_pool_used = 0;
static FSNode root_node;
static FSNode* current_working_directory = NULL;

static char content_pool[FS_CONTENT_POOL_SIZE];
static size_t content_pool_used = 0;

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

static int kstrcmp(const char* a, const char* b)
{
	size_t i = 0;

	if (!a || !b) {
		return a == b ? 0 : -1;
	}

	while (a[i] != '\0' && b[i] != '\0') {
			if (a[i] != b[i]) {
				return (int)((unsigned char)a[i] - (unsigned char)b[i]);
			}
			++i;
	}

	return (int)((unsigned char)a[i] - (unsigned char)b[i]);
}

static void kstrncpy(char* dest, const char* src, size_t max_len)
{
	size_t i;

	for (i = 0; i + 1 < max_len && src[i] != '\0'; ++i) {
		dest[i] = src[i];
	}

	dest[i] = '\0';
}

static FSNode* allocate_node(NodeType type, const char* name, FSNode* parent)
{
	FSNode* node;

	if (node_pool_used >= FS_MAX_NODES) {
		return NULL;
	}

	node = &node_pool[node_pool_used++];
	kstrncpy(node->name, name, sizeof(node->name));
	node->type = type;
	node->parent = parent;
	node->child_count = 0;
	for (int i = 0; i < 32; ++i) {
		node->children[i] = NULL;
	}
	node->content = NULL;

	return node;
}

void fs_init()
{
	node_pool_used = 0;
	content_pool_used = 0;

	kstrncpy(root_node.name, "/", sizeof(root_node.name));
	root_node.type = NODE_DIR;
	root_node.parent = NULL;
	root_node.child_count = 0;
	for (int i = 0; i < 32; ++i) {
		root_node.children[i] = NULL;
	}
	root_node.content = NULL;
	current_working_directory = &root_node;
}

static int add_child(FSNode* parent, FSNode* child)
{
        if (!parent || parent->type != NODE_DIR) {
                return -1;
        }

	if (parent->child_count >= 32) {
		return -1;
	}

        parent->children[parent->child_count++] = child;
        return 0;
}

static int detach_child(FSNode* node)
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

int fs_is_dir(FSNode* node)
{
        return node && node->type == NODE_DIR;
}

int fs_is_file(FSNode* node)
{
        return node && node->type == NODE_FILE;
}

int fs_is_empty_dir(FSNode* node)
{
        if (!fs_is_dir(node)) {
                return 0;
        }

        return node->child_count == 0;
}

FSNode* fs_create_file(FSNode* parent, const char* name)
{
	FSNode* node;

	if (!parent || parent->type != NODE_DIR) {
		return NULL;
	}

	node = allocate_node(NODE_FILE, name, parent);
	if (!node) {
		return NULL;
	}

	if (add_child(parent, node) != 0) {
		return NULL;
	}

	return node;
}

FSNode* fs_create_dir(FSNode* parent, const char* name)
{
        FSNode* node;

	if (!parent || parent->type != NODE_DIR) {
		return NULL;
	}

	node = allocate_node(NODE_DIR, name, parent);
	if (!node) {
		return NULL;
	}

	if (add_child(parent, node) != 0) {
		return NULL;
	}

        return node;
}

FSNode* fs_mkdir(FSNode* parent, const char* name)
{
        FSNode* existing;

        if (!parent || parent->type != NODE_DIR) {
                return NULL;
        }

        existing = fs_lookup(parent, name);
        if (existing) {
                if (existing->type == NODE_DIR) {
                        return existing;
                }

                return NULL;
        }

        return fs_create_dir(parent, name);
}

FSNode* fs_lookup(FSNode* parent, const char* name)
{
	if (!parent || parent->type != NODE_DIR) {
		return NULL;
	}

	for (int i = 0; i < parent->child_count; ++i) {
		FSNode* child = parent->children[i];

		if (kstrcmp(child->name, name) == 0) {
			return child;
		}
	}

	return NULL;
}

FSNode* fs_resolve_path(FSNode* cwd, const char* path)
{
        FSNode* node;
        size_t i = 0;

        if (!path || path[0] == '\0') {
                return cwd;
        }

        node = (path[0] == '/') ? &root_node : cwd;

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

                if (seg_len == 0 || kstrcmp(segment, ".") == 0) {
                        continue;
                }

                if (kstrcmp(segment, "..") == 0) {
                        if (node && node->parent) {
                                node = node->parent;
                        }
                        continue;
                }

                node = fs_lookup(node, segment);
                if (!node) {
                        return NULL;
                }
        }

        return node;
}

int fs_remove(FSNode* node)
{
        if (!node || node == &root_node) {
                return -1;
        }

        if (fs_is_dir(node) && !fs_is_empty_dir(node)) {
                return -1;
        }

        return detach_child(node);
}

int fs_remove_recursive(FSNode* node)
{
        if (!node || node == &root_node) {
                return -1;
        }

        if (fs_is_dir(node)) {
                while (node->child_count > 0) {
                        FSNode* child = node->children[node->child_count - 1];

                        if (fs_remove_recursive(child) != 0) {
                                return -1;
                        }
                }
        }

        return fs_remove(node);
}

FSNode* fs_clone_node(FSNode* node)
{
        FSNode* clone;

        if (!node) {
                return NULL;
        }

        clone = allocate_node(node->type, node->name, NULL);
        if (!clone) {
                return NULL;
        }

        if (node->type == NODE_FILE && node->content) {
                if (fs_write(clone, node->content) != 0) {
                        return NULL;
                }
        }

        return clone;
}

int fs_copy_recursive(FSNode* src, FSNode* dst_parent, const char* new_name)
{
        if (!src || !dst_parent || dst_parent->type != NODE_DIR || !new_name) {
                return -1;
        }

        if (src->type == NODE_FILE) {
                FSNode* file = fs_lookup(dst_parent, new_name);
                const char* data = fs_read(src);

                if (!file) {
                        file = fs_create_file(dst_parent, new_name);
                        if (!file) {
                                return -1;
                        }
                } else if (!fs_is_file(file)) {
                        return -1;
                }

                if (data) {
                        return fs_write(file, data);
                }

                return 0;
        }

        if (src->type == NODE_DIR) {
                FSNode* dir = fs_lookup(dst_parent, new_name);

                if (dir) {
                        if (!fs_is_dir(dir)) {
                                return -1;
                        }
                } else {
                        dir = fs_create_dir(dst_parent, new_name);
                        if (!dir) {
                                return -1;
                        }
                }

                for (int i = 0; i < src->child_count; ++i) {
                        FSNode* child = src->children[i];

                        if (fs_copy_recursive(child, dir, child->name) != 0) {
                                return -1;
                        }
                }

                return 0;
        }

        return -1;
}

FSNode* fs_get_cwd()
{
	return current_working_directory;
}

void fs_set_cwd(FSNode* node)
{
	if (node && node->type == NODE_DIR) {
		current_working_directory = node;
	}
}

int fs_write(FSNode* file, const char* data)
{
        size_t len;
        size_t remaining;

        if (!file || file->type != NODE_FILE || !data) {
                return -1;
        }

	len = kstrlen(data);
	remaining = FS_CONTENT_POOL_SIZE - content_pool_used;

	if (len + 1 > remaining) {
		return -1;
	}

	file->content = &content_pool[content_pool_used];

	for (size_t i = 0; i < len; ++i) {
		content_pool[content_pool_used++] = data[i];
	}

	content_pool[content_pool_used++] = '\0';

        return 0;
}

int fs_append(FSNode* file, const char* data)
{
        size_t existing_len = 0;
        size_t new_len;
        size_t remaining;
        const char* existing;

        if (!file || file->type != NODE_FILE || !data) {
                return -1;
        }

        existing = file->content;
        if (existing) {
                existing_len = kstrlen(existing);
        }

        new_len = kstrlen(data);
        remaining = FS_CONTENT_POOL_SIZE - content_pool_used;

        if (existing_len + new_len + 1 > remaining) {
                return -1;
        }

        file->content = &content_pool[content_pool_used];

        for (size_t i = 0; i < existing_len; ++i) {
                content_pool[content_pool_used++] = existing ? existing[i] : '\0';
        }

        for (size_t i = 0; i < new_len; ++i) {
                content_pool[content_pool_used++] = data[i];
        }

        content_pool[content_pool_used++] = '\0';

        return 0;
}

const char* fs_read(FSNode* file)
{
	if (!file || file->type != NODE_FILE) {
		return NULL;
	}

	return file->content;
}
