# SDL_SetWindowsMessageHook

Set a callback for every Windows message, run before TranslateMessage().

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetWindowsMessageHook(SDL_WindowsMessageHook callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_WindowsMessageHook](SDL_WindowsMessageHook.html) | **callback** | the [SDL_WindowsMessageHook](SDL_WindowsMessageHook.html) function to call. |
| void \* | **userdata** | a pointer to pass to every iteration of `callback`. |

## Remarks

The callback may modify the message, and should return true if the
message should continue to be processed, or false to prevent further
processing.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_WindowsMessageHook](SDL_WindowsMessageHook.html)
- [SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP](SDL_HINT_WINDOWS_ENABLE_MESSAGELOOP.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
