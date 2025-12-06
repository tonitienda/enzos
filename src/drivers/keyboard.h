// SPDX-License-Identifier: MIT

#ifndef ENZOS_DRIVERS_KEYBOARD_H
#define ENZOS_DRIVERS_KEYBOARD_H

#include <stdbool.h>
#include <stdint.h>

void keyboard_initialize(void);
char keyboard_getchar(void);

#endif /* ENZOS_DRIVERS_KEYBOARD_H */
