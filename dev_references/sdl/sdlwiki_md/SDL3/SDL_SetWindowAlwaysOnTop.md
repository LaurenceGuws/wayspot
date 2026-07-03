# SDL_SetWindowAlwaysOnTop

Set the window to always be above the others.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetWindowAlwaysOnTop(SDL_Window *window, bool on_top);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window of which to change the always on top state. |
| bool | **on_top** | true to set the window always on top, false to disable. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This will add or remove the window's
[`SDL_WINDOW_ALWAYS_ON_TOP`](SDL_WINDOW_ALWAYS_ON_TOP.html) flag. This
will bring the window to the front and keep the window above the rest.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowFlags](SDL_GetWindowFlags.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
