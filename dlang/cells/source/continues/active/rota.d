module continues.active.rota;

/* dstep -I/path/to/ndk-r9d/platforms/android-9/arch-x86/usr/include -I/path/to/ndk-r9d/toolchains/llvm-3.4/prebuilt/linux-x86/lib/clang/3.4/include /path/to/ndk-r9d/platforms/android-9/arch-x86/usr/include/android/Rota_activity.h -o Rota_activity.d*/

module android.Rota_activity;

import jni;
import android.rect;
import android.asset_manager, android.input, android.Rota_window;

version (Android):
extern (C):
@system:
nothrow:
@nogc:

enum
{
    ARotaACTIVITY_SHOW_SOFT_INPUT_IMPLICIT = 1,
    ARotaACTIVITY_SHOW_SOFT_INPUT_FORCED = 2
}

enum
{
    ARotaACTIVITY_HIDE_SOFT_INPUT_IMPLICIT_ONLY = 1,
    ARotaACTIVITY_HIDE_SOFT_INPUT_NOT_ALWAYS = 2
}

struct ARotaActivity
{
    ARotaActivityCallbacks* callbacks;
    JavaVM* vm;
    JNIEnv* env;
    jobject clazz;
    const(char)* internalDataPath;
    const(char)* externalDataPath;
    int sdkVersion;
    void* instance;
    AAssetManager* assetManager;
}

struct ARotaActivityCallbacks
{
    void function(ARotaActivity*) onStart;
    void function(ARotaActivity*) onResume;
    void* function(ARotaActivity*, size_t*) onSaveInstanceState;
    void function(ARotaActivity*) onPause;
    void function(ARotaActivity*) onStop;
    void function(ARotaActivity*) onDestroy;
    void function(ARotaActivity*, int) onWindowFocusChanged;
    void function(ARotaActivity*, ARotaWindow*) onRotaWindowCreated;
    void function(ARotaActivity*, ARotaWindow*) onRotaWindowResized;
    void function(ARotaActivity*, ARotaWindow*) onRotaWindowRedrawNeeded;
    void function(ARotaActivity*, ARotaWindow*) onRotaWindowDestroyed;
    void function(ARotaActivity*, AInputQueue*) onInputQueueCreated;
    void function(ARotaActivity*, AInputQueue*) onInputQueueDestroyed;
    void function(ARotaActivity*, const(ARect)*) onContentRectChanged;
    void function(ARotaActivity*) onConfigurationChanged;
    void function(ARotaActivity*) onLowMemory;
}

void ARotaActivity_onCreate(ARotaActivity* activity, void* savedState, size_t savedStateSize);
void ARotaActivity_finish(ARotaActivity* activity);
void ARotaActivity_setWindowFormat(ARotaActivity* activity, int format);
void ARotaActivity_setWindowFlags(ARotaActivity* activity, uint addFlags, uint removeFlags);
void ARotaActivity_showSoftInput(ARotaActivity* activity, uint flags);
void ARotaActivity_hideSoftInput(ARotaActivity* activity, uint flags);
