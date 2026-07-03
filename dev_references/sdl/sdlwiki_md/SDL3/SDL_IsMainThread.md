# SDL_IsMainThread

Return whether this is the main thread.

## Header File

Defined in
[\<SDL3/SDL_init.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_init.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_IsMainThread(void);
```

</div>

## Return Value

(bool) Returns true if this thread is the main thread, or false
otherwise.

## Remarks

On Apple platforms, the main thread is the thread that runs your
program's main() entry point. On other platforms, the main thread is the
one that calls
[SDL_Init](SDL_Init.html)([SDL_INIT_VIDEO](SDL_INIT_VIDEO.html)), which
should usually be the one that runs your program's main() entry point.
If you are using the main callbacks, [SDL_AppInit](SDL_AppInit.html)(),
[SDL_AppIterate](SDL_AppIterate.html)(), and
[SDL_AppQuit](SDL_AppQuit.html)() are all called on the main thread.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RunOnMainThread](SDL_RunOnMainThread.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryInit](CategoryInit.html)
