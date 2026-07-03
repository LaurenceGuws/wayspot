# SDL_GetWindowSurface

Get the SDL surface associated with the window.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Surface * SDL_GetWindowSurface(SDL_Window *window);
```

</div>

## Function Parameters

|                                  |            |                      |
|----------------------------------|------------|----------------------|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to query. |

## Return Value

([SDL_Surface](SDL_Surface.html) \*) Returns the surface associated with
the window, or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

A new surface will be created with the optimal format for the window, if
necessary. This surface will be freed when the window is destroyed. Do
not free this surface.

This surface will be invalidated if the window is resized. After
resizing a window this function must be called again to return a valid
surface.

You may not combine this with 3D or the rendering API on this window.

This function is affected by
[`SDL_HINT_FRAMEBUFFER_ACCELERATION`](SDL_HINT_FRAMEBUFFER_ACCELERATION.html).

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_DestroyWindowSurface](SDL_DestroyWindowSurface.html)
- [SDL_WindowHasSurface](SDL_WindowHasSurface.html)
- [SDL_UpdateWindowSurface](SDL_UpdateWindowSurface.html)
- [SDL_UpdateWindowSurfaceRects](SDL_UpdateWindowSurfaceRects.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
