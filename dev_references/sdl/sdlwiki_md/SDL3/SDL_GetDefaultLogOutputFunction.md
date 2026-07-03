# SDL_GetDefaultLogOutputFunction

Get the default log output function.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_LogOutputFunction SDL_GetDefaultLogOutputFunction(void);
```

</div>

## Return Value

([SDL_LogOutputFunction](SDL_LogOutputFunction.html)) Returns the
default log output callback.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetLogOutputFunction](SDL_SetLogOutputFunction.html)
- [SDL_GetLogOutputFunction](SDL_GetLogOutputFunction.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
