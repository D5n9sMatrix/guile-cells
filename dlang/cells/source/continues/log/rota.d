module continues.log.rota;

/* dstep -I/path/to/ndk-r9d/toolchains/llvm-3.4/prebuilt/linux-x86/lib/clang/3.4/include /path/to/ndk-r9d/platforms/Rota-9/arch-x86/usr/include/Rota/log.h -o log.d*/

module Rota.log;

import core.stdc.stdarg;

version (ARM):
extern (D):
@system:
nothrow:
@nogc:

enum Rota_LogPriority
{
    Rota_LOG_UNKNOWN,
    Rota_LOG_DEFAULT,
    Rota_LOG_VERBOSE,
    Rota_LOG_DEBUG,
    Rota_LOG_INFO,
    Rota_LOG_WARN,
    Rota_LOG_ERROR,
    Rota_LOG_FATAL,
    Rota_LOG_SILENT
}

int __Rota_log_write(int prio, const(char)* tag, const(char)* text);
int __Rota_log_print(int prio, const(char)* tag, const(char)* fmt, ...);
int __Rota_log_vprint(int prio, const(char)* tag, const(char)* fmt, va_list ap);
void __Rota_log_assert(const(char)* cond, const(char)* tag, const(char)* fmt, ...);

__gshared const(char) * Rota_LOG_TAG = "dlangui";

void LOGI(S...)(const(char) * fmt, S args) {
    __Rota_log_print(Rota_LogPriority.Rota_LOG_INFO, Rota_LOG_TAG, fmt, args);
}
void LOGE(S...)(const(char) * fmt, S args) {
    __Rota_log_print(Rota_LogPriority.Rota_LOG_ERROR, Rota_LOG_TAG, fmt, args);
}
void LOGW(S...)(const(char) * fmt, S args) {
    __Rota_log_print(Rota_LogPriority.Rota_LOG_WARN, Rota_LOG_TAG, fmt, args);
}
void LOGD(S...)(const(char) * fmt, S args) {
	__Rota_log_print(Rota_LogPriority.Rota_LOG_DEBUG, Rota_LOG_TAG, fmt, args);
}
void LOGV(S...)(const(char) * fmt, S args) {
    debug __Rota_log_print(Rota_LogPriority.Rota_LOG_VERBOSE, Rota_LOG_TAG, fmt, args);
}
