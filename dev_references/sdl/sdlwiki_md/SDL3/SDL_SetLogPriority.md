# SDL_SetLogPriority

Set the priority of a particular log category.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetLogPriority(int category, SDL_LogPriority priority);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int | **category** | the category to assign a priority to. |
| [SDL_LogPriority](SDL_LogPriority.html) | **priority** | the [SDL_LogPriority](SDL_LogPriority.html) to assign. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetLogPriority](SDL_GetLogPriority.html)
- [SDL_ResetLogPriorities](SDL_ResetLogPriorities.html)
- [SDL_SetLogPriorities](SDL_SetLogPriorities.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
