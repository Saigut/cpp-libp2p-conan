#ifndef CPP_PROJ_UTILS_HPP
#define CPP_PROJ_UTILS_HPP

#include <inttypes.h>

#include <string>
#include <functional>

#include <mod_common/os_compat.hpp>
#include "log.hpp"
#include "expect.hpp"


int util_bind_thread_to_core(unsigned int core_id);
void util_thread_set_self_name(std::string&& name);

uint64_t util_now_ts_ms();
uint64_t util_now_ts_us();
uint64_t util_now_ts_ns();

void util_printf_buf(uint8_t* buf, size_t size);


void cppt_sleep(unsigned ts_s);
void cppt_msleep(unsigned ts_ms);
void cppt_usleep(unsigned ts_us);
void cppt_nanosleep(unsigned ts_ns);


#endif //CPP_PROJ_UTILS_HPP
