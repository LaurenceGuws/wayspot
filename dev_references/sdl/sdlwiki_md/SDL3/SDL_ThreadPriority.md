# SDL_ThreadPriority

The SDL thread priority.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_ThreadPriority {
    SDL_THREAD_PRIORITY_LOW,
    SDL_THREAD_PRIORITY_NORMAL,
    SDL_THREAD_PRIORITY_HIGH,
    SDL_THREAD_PRIORITY_TIME_CRITICAL
} SDL_ThreadPriority;
```

</div>

## Remarks

SDL will make system changes as necessary in order to apply the thread
priority. Code which attempts to control thread state related to
priority should be aware that calling
[SDL_SetCurrentThreadPriority](SDL_SetCurrentThreadPriority.html) may
alter such state.
[SDL_HINT_THREAD_PRIORITY_POLICY](SDL_HINT_THREAD_PRIORITY_POLICY.html)
can be used to control aspects of this behavior.

## Version

This enum is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryThread](CategoryThread.html)
