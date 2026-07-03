# SDL_SetWindowFullscreenMode

Set the display mode to use when a window is visible and fullscreen.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetWindowFullscreenMode(SDL_Window *window, const SDL_DisplayMode *mode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to affect. |
| const [SDL_DisplayMode](SDL_DisplayMode.html) \* | **mode** | a pointer to the display mode to use, which can be NULL for borderless fullscreen desktop mode, or one of the fullscreen modes returned by [SDL_GetFullscreenDisplayModes](SDL_GetFullscreenDisplayModes.html)() to set an exclusive fullscreen mode. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This only affects the display mode used when the window is fullscreen.
To change the window size when the window is not fullscreen, use
[SDL_SetWindowSize](SDL_SetWindowSize.html)().

If the window is currently in the fullscreen state, this request is
asynchronous on some windowing systems and the new mode dimensions may
not be applied immediately upon the return of this function. If an
immediate change is required, call
[SDL_SyncWindow](SDL_SyncWindow.html)() to block until the changes have
taken effect.

When the new mode takes effect, an
[SDL_EVENT_WINDOW_RESIZED](SDL_EVENT_WINDOW_RESIZED.html) and/or an
[SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED](SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED.html)
event will be emitted with the new mode dimensions.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowFullscreenMode](SDL_GetWindowFullscreenMode.html)
- [SDL_SetWindowFullscreen](SDL_SetWindowFullscreen.html)
- [SDL_SyncWindow](SDL_SyncWindow.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
