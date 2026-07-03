# SDL_GetWindowSize

Get the size of a window's client area.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetWindowSize(SDL_Window *window, int *w, int *h);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query the width and height from. |
| int \* | **w** | a pointer filled in with the width of the window, may be NULL. |
| int \* | **h** | a pointer filled in with the height of the window, may be NULL. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The window pixel size may differ from its window coordinate size if the
window is on a high pixel density display. Use
[SDL_GetWindowSizeInPixels](SDL_GetWindowSizeInPixels.html)() or
[SDL_GetRenderOutputSize](SDL_GetRenderOutputSize.html)() to get the
real client area size in pixels.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderOutputSize](SDL_GetRenderOutputSize.html)
- [SDL_GetWindowSizeInPixels](SDL_GetWindowSizeInPixels.html)
- [SDL_SetWindowSize](SDL_SetWindowSize.html)
- [SDL_EVENT_WINDOW_RESIZED](SDL_EVENT_WINDOW_RESIZED.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
