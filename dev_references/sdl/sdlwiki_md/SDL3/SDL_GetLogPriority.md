# SDL_GetLogPriority

Get the priority of a particular log category.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_LogPriority SDL_GetLogPriority(int category);
```

</div>

## Function Parameters

|     |              |                        |
|-----|--------------|------------------------|
| int | **category** | the category to query. |

## Return Value

([SDL_LogPriority](SDL_LogPriority.html)) Returns the
[SDL_LogPriority](SDL_LogPriority.html) for the requested category.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetLogPriority](SDL_SetLogPriority.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
