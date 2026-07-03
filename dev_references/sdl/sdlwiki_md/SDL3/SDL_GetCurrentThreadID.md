# SDL_GetCurrentThreadID

Get the thread identifier for the current thread.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_ThreadID SDL_GetCurrentThreadID(void);
```

</div>

## Return Value

([SDL_ThreadID](SDL_ThreadID.html)) Returns the ID of the current
thread.

## Remarks

This thread identifier is as reported by the underlying operating
system. If SDL is running on a platform that does not support threads
the return value will always be zero.

This function also returns a valid thread ID when called from the main
thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetThreadID](SDL_GetThreadID.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryThread](CategoryThread.html)
