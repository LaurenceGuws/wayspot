# SDL_GetThreadState

Get the current state of a thread.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_ThreadState SDL_GetThreadState(SDL_Thread *thread);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Thread](SDL_Thread.html) \* | **thread** | the thread to query. |

## Return Value

([SDL_ThreadState](SDL_ThreadState.html)) Returns the current state of a
thread, or [SDL_THREAD_UNKNOWN](SDL_THREAD_UNKNOWN.html) if the thread
isn't valid.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ThreadState](SDL_ThreadState.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
