module continues.fixed.cnnnews;

version (ARM):
extern (D):
@system:
nothrow:
@nogc:

struct play_native_pixmap_t;

alias ANativeWindow* PlayNativeWindowType;
alias play_native_pixmap_t* PlayNativePixmapType;
alias void* PlayNativeDisplayType;
alias PlayNativeDisplayType NativeDisplayType;
alias PlayNativeDisplayType NativePixmapType;
alias PlayNativeDisplayType NativeWindowType;
alias int PlayLint;

