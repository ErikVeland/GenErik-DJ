#ifndef S4MK3_DRIVER_CLIENT_H
#define S4MK3_DRIVER_CLIENT_H
#include <stdint.h>

uint32_t s4_mk3_driver_open(void);
void s4_mk3_driver_close(uint32_t connection);
int s4_mk3_driver_read(uint32_t connection, uint8_t* bytes, uint32_t capacity);
int s4_mk3_driver_write(uint32_t connection, const uint8_t* bytes, uint32_t count);

#endif
