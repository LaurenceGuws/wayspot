# SDL_SetLogOutputFunction

Replace the default log output function with one of your own.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetLogOutputFunction(SDL_LogOutputFunction callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_LogOutputFunction](SDL_LogOutputFunction.html) | **callback** | an [SDL_LogOutputFunction](SDL_LogOutputFunction.html) to call instead of the default. |
| void \* | **userdata** | a pointer that is passed to `callback`. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetDefaultLogOutputFunction](SDL_GetDefaultLogOutputFunction.html)
- [SDL_GetLogOutputFunction](SDL_GetLogOutputFunction.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
