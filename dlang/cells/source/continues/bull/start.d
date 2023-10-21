module continues.bull.start;

/*
 * Copyright (C) 2010 The views Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

// this is translation of views_native_app_glue.c

version(ARM):
extern(D):
@system:

import core.sys.posix.pthread;
import views.input, views.native_window, views.rect, views.log;
import views.configuration, views.looper, views.native_activity;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.stdio;
import core.stdc.errno;
import core.sys.posix.sys.resource;
import core.sys.posix.unistd;

import views.views_native_app_glue;
import views.log;

static void free_saved_state(views_app* views_app) {
    pthread_mutex_lock(&views_app.mutex);
    if (views_app.savedState != null) {
        free(views_app.savedState);
        views_app.savedState = null;
        views_app.savedStateSize = 0;
    }
    pthread_mutex_unlock(&views_app.mutex);
}

byte views_app_read_cmd(views_app* views_app) {
    byte cmd;
    if (read(views_app.msgread, &cmd, cmd.sizeof) == cmd.sizeof) {
        switch (cmd) {
            case APP_CMD_SAVE_STATE:
                free_saved_state(views_app);
                break;
            default:
                break;
        }
        return cmd;
    } else {
        LOGE("No data on command pipe!");
    }
    return -1;
}

static void print_cur_config(views_app* views_app) {

    char[2] lang;
    char[2] country;
    AConfiguration_getLanguage(views_app.config, lang.ptr);
    AConfiguration_getCountry(views_app.config, country.ptr);

    LOGV("Config: mcc=%d mnc=%d lang=%c%c cnt=%c%c orien=%d touch=%d dens=%d " ~
            "keys=%d nav=%d keysHid=%d navHid=%d sdk=%d size=%d long=%d " ~
            "modetype=%d modenight=%d",
            AConfiguration_getMcc(views_app.config),
            AConfiguration_getMnc(views_app.config),
            lang[0], lang[1], country[0], country[1],
            AConfiguration_getOrientation(views_app.config),
            AConfiguration_getTouchscreen(views_app.config),
            AConfiguration_getDensity(views_app.config),
            AConfiguration_getKeyboard(views_app.config),
            AConfiguration_getNavigation(views_app.config),
            AConfiguration_getKeysHidden(views_app.config),
            AConfiguration_getNavHidden(views_app.config),
            AConfiguration_getSdkVersion(views_app.config),
            AConfiguration_getScreenSize(views_app.config),
            AConfiguration_getScreenLong(views_app.config),
            AConfiguration_getUiModeType(views_app.config),
            AConfiguration_getUiModeNight(views_app.config));
}

void views_app_pre_exec_cmd(views_app* views_app, byte cmd) {
    switch (cmd) {
        case APP_CMD_INPUT_CHANGED:
            LOGV("APP_CMD_INPUT_CHANGED\n");
            pthread_mutex_lock(&views_app.mutex);
            if (views_app.inputQueue != null) {
                AInputQueue_detachLooper(views_app.inputQueue);
            }
            views_app.inputQueue = views_app.pendingInputQueue;
            if (views_app.inputQueue != null) {
                LOGV("Attaching input queue to looper");
                AInputQueue_attachLooper(views_app.inputQueue,
                        views_app.looper, LOOPER_ID_INPUT, null,
                        &views_app.inputPollSource);
            }
            pthread_cond_broadcast(&views_app.cond);
            pthread_mutex_unlock(&views_app.mutex);
            break;

        case APP_CMD_INIT_WINDOW:
            LOGV("APP_CMD_INIT_WINDOW\n");
            pthread_mutex_lock(&views_app.mutex);
            views_app.window = views_app.pendingWindow;
            pthread_cond_broadcast(&views_app.cond);
            pthread_mutex_unlock(&views_app.mutex);
            break;

        case APP_CMD_TERM_WINDOW:
            LOGV("APP_CMD_TERM_WINDOW\n");
            pthread_cond_broadcast(&views_app.cond);
            break;

        case APP_CMD_RESUME:
        case APP_CMD_START:
        case APP_CMD_PAUSE:
        case APP_CMD_STOP:
            LOGV("activityState=%d\n", cmd);
            pthread_mutex_lock(&views_app.mutex);
            views_app.activityState = cmd;
            pthread_cond_broadcast(&views_app.cond);
            pthread_mutex_unlock(&views_app.mutex);
            break;

        case APP_CMD_CONFIG_CHANGED:
            LOGV("APP_CMD_CONFIG_CHANGED\n");
            AConfiguration_fromAssetManager(views_app.config,
                    views_app.activity.assetManager);
            print_cur_config(views_app);
            break;

        case APP_CMD_DESTROY:
            LOGV("APP_CMD_DESTROY\n");
            views_app.destroyRequested = 1;
            break;
        default:
            break;
    }
}

void views_app_post_exec_cmd(views_app* views_app, byte cmd) {
    switch (cmd) {
        case APP_CMD_TERM_WINDOW:
            LOGV("APP_CMD_TERM_WINDOW\n");
            pthread_mutex_lock(&views_app.mutex);
            views_app.window = null;
            pthread_cond_broadcast(&views_app.cond);
            pthread_mutex_unlock(&views_app.mutex);
            break;

        case APP_CMD_SAVE_STATE:
            LOGV("APP_CMD_SAVE_STATE\n");
            pthread_mutex_lock(&views_app.mutex);
            views_app.stateSaved = 1;
            pthread_cond_broadcast(&views_app.cond);
            pthread_mutex_unlock(&views_app.mutex);
            break;

        case APP_CMD_RESUME:
            free_saved_state(views_app);
            break;
        default:
            break;
    }
}

void app_dummy() {

}

static void views_app_destroy(views_app* views_app) {
    LOGV("views_app_destroy!");
    free_saved_state(views_app);
    pthread_mutex_lock(&views_app.mutex);
    if (views_app.inputQueue != null) {
        AInputQueue_detachLooper(views_app.inputQueue);
    }
    AConfiguration_delete(views_app.config);
    views_app.destroyed = 1;
    pthread_cond_broadcast(&views_app.cond);
    pthread_mutex_unlock(&views_app.mutex);
    // Can't touch views_app object after this.
}

static void process_input(views_app* app, views_poll_source* source) {
    AInputEvent* event = null;
    while (AInputQueue_getEvent(app.inputQueue, &event) >= 0) {
        LOGV("New input event: type=%d\n", AInputEvent_getType(event));
        if (AInputQueue_preDispatchEvent(app.inputQueue, event)) {
            continue;
        }
        int handled = 0;
        if (app.onInputEvent != null) handled = app.onInputEvent(app, event);
        AInputQueue_finishEvent(app.inputQueue, event, handled);
    }
}

static void process_cmd(views_app* app, views_poll_source* source) {
    byte cmd = views_app_read_cmd(app);
    views_app_pre_exec_cmd(app, cmd);
    if (app.onAppCmd != null) app.onAppCmd(app, cmd);
    views_app_post_exec_cmd(app, cmd);
}

void* views_app_entry(void* param) {
    views_app* views_app = cast(views_app*)param;

    views_app.config = AConfiguration_new();
    AConfiguration_fromAssetManager(views_app.config, views_app.activity.assetManager);

    print_cur_config(views_app);

    views_app.cmdPollSource.id = LOOPER_ID_MAIN;
    views_app.cmdPollSource.app = views_app;
    views_app.cmdPollSource.process = &process_cmd;
    views_app.inputPollSource.id = LOOPER_ID_INPUT;
    views_app.inputPollSource.app = views_app;
    views_app.inputPollSource.process = &process_input;

    ALooper* looper = ALooper_prepare(ALOOPER_PREPARE_ALLOW_NON_CALLBACKS);
    ALooper_addFd(looper, views_app.msgread, LOOPER_ID_MAIN, ALOOPER_EVENT_INPUT, null,
            &views_app.cmdPollSource);
    views_app.looper = looper;

    pthread_mutex_lock(&views_app.mutex);
    views_app.running = 1;
    pthread_cond_broadcast(&views_app.cond);
    pthread_mutex_unlock(&views_app.mutex);


    import core.runtime;
    rt_init();
    views_main(views_app);
    rt_term();

    views_app_destroy(views_app);
    return null;
}

// --------------------------------------------------------------------
// Native activity interaction (called from main thread)
// --------------------------------------------------------------------

static views_app* views_app_create(ANativeActivity* activity,
        void* savedState, size_t savedStateSize) {
    size_t sz = views_app.sizeof;
    views_app* views_app = cast(views_app*)malloc(sz);
    memset(views_app, 0, sz);
    views_app.activity = activity;

    pthread_mutex_init(&views_app.mutex, null);
    pthread_cond_init(&views_app.cond, null);

    if (savedState != null) {
        views_app.savedState = malloc(savedStateSize);
        views_app.savedStateSize = savedStateSize;
        memcpy(views_app.savedState, savedState, savedStateSize);
    }

    int[2] msgpipe;
    if (pipe(msgpipe)) {
        LOGE("could not create pipe: %s", strerror(errno));
        return null;
    }
    views_app.msgread = msgpipe[0];
    views_app.msgwrite = msgpipe[1];

    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    pthread_create(&views_app.thread, &attr, &views_app_entry, views_app);

    // Wait for thread to start.
    pthread_mutex_lock(&views_app.mutex);
    while (!views_app.running) {
        pthread_cond_wait(&views_app.cond, &views_app.mutex);
    }
    pthread_mutex_unlock(&views_app.mutex);

    return views_app;
}

static void views_app_write_cmd(views_app* views_app, byte cmd) {
    if (write(views_app.msgwrite, &cmd, cmd.sizeof) != cmd.sizeof) {
        LOGE("Failure writing views_app cmd: %s\n", strerror(errno));
    }
}

static void views_app_set_input(views_app* views_app, AInputQueue* inputQueue) {
    pthread_mutex_lock(&views_app.mutex);
    views_app.pendingInputQueue = inputQueue;
    views_app_write_cmd(views_app, APP_CMD_INPUT_CHANGED);
    while (views_app.inputQueue != views_app.pendingInputQueue) {
        pthread_cond_wait(&views_app.cond, &views_app.mutex);
    }
    pthread_mutex_unlock(&views_app.mutex);
}

static void views_app_set_window(views_app* views_app, ANativeWindow* window) {
    pthread_mutex_lock(&views_app.mutex);
    if (views_app.pendingWindow != null) {
        views_app_write_cmd(views_app, APP_CMD_TERM_WINDOW);
    }
    views_app.pendingWindow = window;
    if (window != null) {
        views_app_write_cmd(views_app, APP_CMD_INIT_WINDOW);
    }
    while (views_app.window != views_app.pendingWindow) {
        pthread_cond_wait(&views_app.cond, &views_app.mutex);
    }
    pthread_mutex_unlock(&views_app.mutex);
}

static void views_app_set_activity_state(views_app* views_app, byte cmd) {
    pthread_mutex_lock(&views_app.mutex);
    views_app_write_cmd(views_app, cmd);
    while (views_app.activityState != cmd) {
        pthread_cond_wait(&views_app.cond, &views_app.mutex);
    }
    pthread_mutex_unlock(&views_app.mutex);
}

static void views_app_free(views_app* views_app) {
    pthread_mutex_lock(&views_app.mutex);
    views_app_write_cmd(views_app, APP_CMD_DESTROY);
    while (!views_app.destroyed) {
        pthread_cond_wait(&views_app.cond, &views_app.mutex);
    }
    pthread_mutex_unlock(&views_app.mutex);

    close(views_app.msgread);
    close(views_app.msgwrite);
    pthread_cond_destroy(&views_app.cond);
    pthread_mutex_destroy(&views_app.mutex);
    free(views_app);
}

static void onDestroy(ANativeActivity* activity) {
    LOGV("Destroy: %p\n", activity);
    views_app_free(cast(views_app*)activity.instance);
}

static void onStart(ANativeActivity* activity) {
    LOGV("Start: %p\n", activity);
    views_app_set_activity_state(cast(views_app*)activity.instance, APP_CMD_START);
}

static void onResume(ANativeActivity* activity) {
    LOGV("Resume: %p\n", activity);
    views_app_set_activity_state(cast(views_app*)activity.instance, APP_CMD_RESUME);
}

static void* onSaveInstanceState(ANativeActivity* activity, size_t* outLen) {
    views_app* views_app = cast(views_app*)activity.instance;
    void* savedState = null;

    LOGV("SaveInstanceState: %p\n", activity);
    pthread_mutex_lock(&views_app.mutex);
    views_app.stateSaved = 0;
    views_app_write_cmd(views_app, APP_CMD_SAVE_STATE);
    while (!views_app.stateSaved) {
        pthread_cond_wait(&views_app.cond, &views_app.mutex);
    }

    if (views_app.savedState != null) {
        savedState = views_app.savedState;
        *outLen = views_app.savedStateSize;
        views_app.savedState = null;
        views_app.savedStateSize = 0;
    }

    pthread_mutex_unlock(&views_app.mutex);

    return savedState;
}

static void onPause(ANativeActivity* activity) {
    LOGV("Pause: %p\n", activity);
    views_app_set_activity_state(cast(views_app*)activity.instance, APP_CMD_PAUSE);
}

static void onStop(ANativeActivity* activity) {
    LOGV("Stop: %p\n", activity);
    views_app_set_activity_state(cast(views_app*)activity.instance, APP_CMD_STOP);
}

static void onConfigurationChanged(ANativeActivity* activity) {
    views_app* views_app = cast(views_app*)activity.instance;
    LOGV("ConfigurationChanged: %p\n", activity);
    views_app_write_cmd(views_app, APP_CMD_CONFIG_CHANGED);
}

static void onLowMemory(ANativeActivity* activity) {
    views_app* views_app = cast(views_app*)activity.instance;
    LOGV("LowMemory: %p\n", activity);
    views_app_write_cmd(views_app, APP_CMD_LOW_MEMORY);
}

static void onWindowFocusChanged(ANativeActivity* activity, int focused) {
    LOGV("WindowFocusChanged: %p -- %d\n", activity, focused);
    views_app_write_cmd(cast(views_app*)activity.instance,
            focused ? APP_CMD_GAINED_FOCUS : APP_CMD_LOST_FOCUS);
}

static void onNativeWindowCreated(ANativeActivity* activity, ANativeWindow* window) {
    LOGV("NativeWindowCreated: %p -- %p\n", activity, window);
    views_app_set_window(cast(views_app*)activity.instance, window);
}

static void onNativeWindowDestroyed(ANativeActivity* activity, ANativeWindow* window) {
    LOGV("NativeWindowDestroyed: %p -- %p\n", activity, window);
    views_app_set_window(cast(views_app*)activity.instance, null);
}

static void onInputQueueCreated(ANativeActivity* activity, AInputQueue* queue) {
    LOGV("InputQueueCreated: %p -- %p\n", activity, queue);
    views_app_set_input(cast(views_app*)activity.instance, queue);
}

static void onInputQueueDestroyed(ANativeActivity* activity, AInputQueue* queue) {
    LOGV("InputQueueDestroyed: %p -- %p\n", activity, queue);
    views_app_set_input(cast(views_app*)activity.instance, null);
}

void ANativeActivity_onCreate(ANativeActivity* activity,
        void* savedState, size_t savedStateSize) {
    LOGV("Creating: %p\n", activity);
    activity.callbacks.onDestroy = &onDestroy;
    activity.callbacks.onStart = &onStart;
    activity.callbacks.onResume = &onResume;
    activity.callbacks.onSaveInstanceState = &onSaveInstanceState;
    activity.callbacks.onPause = &onPause;
    activity.callbacks.onStop = &onStop;
    activity.callbacks.onConfigurationChanged = &onConfigurationChanged;
    activity.callbacks.onLowMemory = &onLowMemory;
    activity.callbacks.onWindowFocusChanged = &onWindowFocusChanged;
    activity.callbacks.onNativeWindowCreated = &onNativeWindowCreated;
    activity.callbacks.onNativeWindowDestroyed = &onNativeWindowDestroyed;
    activity.callbacks.onInputQueueCreated = &onInputQueueCreated;
    activity.callbacks.onInputQueueDestroyed = &onInputQueueDestroyed;

    activity.instance = views_app_create(activity, savedState, savedStateSize);
}
