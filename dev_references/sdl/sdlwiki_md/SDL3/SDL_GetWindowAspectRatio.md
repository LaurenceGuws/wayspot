# SDL_GetWindowAspectRatio

Get the aspect ratio of a window's client area.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetWindowAspectRatio(SDL_Window *window, float *min_aspect, float *max_aspect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query the width and height from. |
| float \* | **min_aspect** | a pointer filled in with the minimum aspect ratio of the window, may be NULL. |
| float \* | **max_aspect** | a pointer filled in with the maximum aspect ratio of the window, may be NULL. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetWindowAspectRatio](SDL_SetWindowAspectRatio.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
