# SDL_ResetLogPriorities

Reset all priorities to default.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_ResetLogPriorities(void);
```

</div>

## Remarks

This is called by [SDL_Quit](SDL_Quit.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetLogPriorities](SDL_SetLogPriorities.html)
- [SDL_SetLogPriority](SDL_SetLogPriority.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
