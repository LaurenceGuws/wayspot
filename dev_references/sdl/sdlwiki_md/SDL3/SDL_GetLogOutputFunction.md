# SDL_GetLogOutputFunction

Get the current log output function.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_GetLogOutputFunction(SDL_LogOutputFunction *callback, void **userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_LogOutputFunction](SDL_LogOutputFunction.html) \* | **callback** | an [SDL_LogOutputFunction](SDL_LogOutputFunction.html) filled in with the current log callback. |
| void \*\* | **userdata** | a pointer filled in with the pointer that is passed to `callback`. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetDefaultLogOutputFunction](SDL_GetDefaultLogOutputFunction.html)
- [SDL_SetLogOutputFunction](SDL_SetLogOutputFunction.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
