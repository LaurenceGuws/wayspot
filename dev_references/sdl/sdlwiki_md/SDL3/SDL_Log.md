# SDL_Log

Log a message with
[SDL_LOG_CATEGORY_APPLICATION](SDL_LOG_CATEGORY_APPLICATION.html) and
[SDL_LOG_PRIORITY_INFO](SDL_LOG_PRIORITY_INFO.html).

## Header File

Defined in
[\<SDL3/SDL_log.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_log.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_Log(const char *fmt, ...);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **fmt** | a printf() style message format string. |
| ... | **...** | additional parameters matching % tokens in the `fmt` string, if any. |

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_LogCritical](SDL_LogCritical.html)
- [SDL_LogDebug](SDL_LogDebug.html)
- [SDL_LogError](SDL_LogError.html)
- [SDL_LogInfo](SDL_LogInfo.html)
- [SDL_LogMessage](SDL_LogMessage.html)
- [SDL_LogMessageV](SDL_LogMessageV.html)
- [SDL_LogTrace](SDL_LogTrace.html)
- [SDL_LogVerbose](SDL_LogVerbose.html)
- [SDL_LogWarn](SDL_LogWarn.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryLog](CategoryLog.html)
