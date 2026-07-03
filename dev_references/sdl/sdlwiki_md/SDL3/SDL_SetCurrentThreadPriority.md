# SDL_SetCurrentThreadPriority

Set the priority for the current thread.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetCurrentThreadPriority(SDL_ThreadPriority priority);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_ThreadPriority](SDL_ThreadPriority.html) | **priority** | the [SDL_ThreadPriority](SDL_ThreadPriority.html) to set. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Note that some platforms will not let you alter the priority (or at
least, promote the thread to a higher priority) at all, and some require
you to be an administrator account. Be prepared for this to fail.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
