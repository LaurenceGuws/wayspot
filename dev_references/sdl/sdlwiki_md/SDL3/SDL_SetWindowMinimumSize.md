# SDL_SetWindowMinimumSize

Set the minimum size of a window's client area.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetWindowMinimumSize(SDL_Window *window, int min_w, int min_h);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to change. |
| int | **min_w** | the minimum width of the window, or 0 for no limit. |
| int | **min_h** | the minimum height of the window, or 0 for no limit. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowMinimumSize](SDL_GetWindowMinimumSize.html)
- [SDL_SetWindowMaximumSize](SDL_SetWindowMaximumSize.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
