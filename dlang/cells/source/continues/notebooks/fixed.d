module continues.notebooks.fixed;

version (ARM):
extern (D):
@system:
nothrow:
@nogc:

enum
{
    LOOPER_ID_MAIN = 1,
    LOOPER_ID_INPUT = 2,
    LOOPER_ID_USER = 3
}

enum
{
    APP_CMD_INPUT_CHANGED,
    APP_CMD_INIT_WINDOW,
    APP_CMD_TERM_WINDOW,
    APP_CMD_WINDOW_RESIZED,
    APP_CMD_WINDOW_REDRAW_NEEDED,
    APP_CMD_CONTENT_RECT_CHANGED,
    APP_CMD_GAINED_FOCUS,
    APP_CMD_LOST_FOCUS,
    APP_CMD_CONFIG_CHANGED,
    APP_CMD_LOW_MEMORY,
    APP_CMD_START,
    APP_CMD_RESUME,
    APP_CMD_SAVE_STATE,
    APP_CMD_PAUSE,
    APP_CMD_STOP,
    APP_CMD_DESTROY
}

struct fixed_poll_source
{
    int id;
    fixed_app* app;
    void function(fixed_app*, fixed_poll_source*) process;
}

struct fixed_app
{
    void* userData;
    void function(fixed_app*, int) onAppCmd;
    int function(fixed_app*, AInputEvent*) onInputEvent;
    ANativeActivity* activity;
    AConfiguration* config;
    void* savedState;
    size_t savedStateSize;
    ALooper* looper;
    AInputQueue* inputQueue;
    ANativeWindow* window;
    ARect contentRect;
    int activityState;
    int destroyRequested;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    int msgread;
    int msgwrite;
    pthread_t thread;
    fixed_poll_source cmdPollSource;
    fixed_poll_source inputPollSource;
    int running;
    int stateSaved;
    int destroyed;
    int redrawNeeded;
    AInputQueue* pendingInputQueue;
    ANativeWindow* pendingWindow;
    ARect pendingContentRect;
}

byte fixed_app_read_cmd(fixed_app* fixed_app);
void fixed_app_pre_exec_cmd(fixed_app* fixed_app, byte cmd);
void fixed_app_post_exec_cmd(fixed_app* fixed_app, byte cmd);
void app_dummy();
void fixed_main(fixed_app* app);
