# SDL_GetWindowMinimumSize

Get the minimum size of a window's client area.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetWindowMinimumSize(SDL_Window *window, int *w, int *h);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |
| int \* | **w** | a pointer filled in with the minimum width of the window, may be NULL. |
| int \* | **h** | a pointer filled in with the minimum height of the window, may be NULL. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowMaximumSize](SDL_GetWindowMaximumSize.html)
- [SDL_SetWindowMinimumSize](SDL_SetWindowMinimumSize.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
