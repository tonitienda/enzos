#ifndef FS_H
#define FS_H

typedef enum {
	NODE_FILE,
	NODE_DIR
} NodeType;

typedef struct FSNode {
	char name[32];
	NodeType type;
	struct FSNode* parent;

	struct FSNode* children[32];
	int child_count;

	char* content; // only for NODE_FILE
} FSNode;

void fs_init();

// node creation
FSNode* fs_create_file(FSNode* parent, const char* name);
FSNode* fs_create_dir(FSNode* parent, const char* name);

// lookup + navigation
FSNode* fs_lookup(FSNode* parent, const char* name);
FSNode* fs_resolve_path(FSNode* cwd, const char* path);

// working directory
FSNode* fs_get_cwd();
void fs_set_cwd(FSNode* node);

// file I/O
int fs_write(FSNode* file, const char* data);
const char* fs_read(FSNode* file);

#endif
