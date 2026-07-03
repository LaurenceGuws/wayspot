# SDL_SetLogPriorityPrefix

Set the text prepended to log messages of a given priority.

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetLogPriorityPrefix(SDL_LogPriority priority, const char *prefix);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_LogPriority](SDL_LogPriority.html) | **priority** | the [SDL_LogPriority](SDL_LogPriority.html) to modify. |
| const char \* | **prefix** | the prefix to use for that log priority, or NULL to use no prefix. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

By default [SDL_LOG_PRIORITY_INFO](SDL_LOG_PRIORITY_INFO.html) and below
have no prefix, and [SDL_LOG_PRIORITY_WARN](SDL_LOG_PRIORITY_WARN.html)
and higher have a prefix showing their priority, e.g. "WARNING: ".

This function makes a copy of its string argument, **prefix**, so it is
not necessary to keep the value of **prefix** alive after the call
returns.

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
