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

static FSNode* resolve_segment(FSNode* start, const char* segment)
{
	if (kstrcmp(segment, ".") == 0) {
		return start;
	}

	if (kstrcmp(segment, "..") == 0) {
		if (start && start->parent) {
			return start->parent;
		}
		return start;
	}

	return fs_lookup(start, segment);
}

FSNode* fs_resolve_path(FSNode* cwd, const char* path)
{
	FSNode* node;
	size_t i = 0;

	if (!path || path[0] == '\0') {
		return cwd;
	}

	if (path[0] == '/') {
		node = &root_node;
		i = 1;
	} else {
		node = cwd;
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

		if (seg_len == 0) {
			continue;
		}

		node = resolve_segment(node, segment);
		if (!node) {
			return NULL;
		}
	}

	return node;
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

const char* fs_read(FSNode* file)
{
	if (!file || file->type != NODE_FILE) {
		return NULL;
	}

	return file->content;
}
