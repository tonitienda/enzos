// SPDX-License-Identifier: MIT

#ifndef ENZOS_SHELL_SHELL_H
#define ENZOS_SHELL_SHELL_H

#include <stddef.h>
#include "fs.h"

void enzos_shell(void);
void shell_output_char(char c);
void shell_output_string(const char* data);
void shell_capture_output_begin(char* buffer, size_t capacity);
void shell_capture_output_end(void);
void shell_print_path(FSNode* node);

#endif /* ENZOS_SHELL_SHELL_H */
