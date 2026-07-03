# SDL_GetWindowSurfaceVSync

Get VSync for the window surface.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetWindowSurfaceVSync(SDL_Window *window, int *vsync);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |
| int \* | **vsync** | an int filled with the current vertical refresh sync interval. See [SDL_SetWindowSurfaceVSync](SDL_SetWindowSurfaceVSync.html)() for the meaning of the value. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetWindowSurfaceVSync](SDL_SetWindowSurfaceVSync.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
