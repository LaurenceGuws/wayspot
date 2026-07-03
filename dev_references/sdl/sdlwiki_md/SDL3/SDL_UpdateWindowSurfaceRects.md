# SDL_UpdateWindowSurfaceRects

Copy areas of the window surface to the screen.

## Header File

Defined in
[\<SDL3/SDL_video.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_video.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_UpdateWindowSurfaceRects(SDL_Window *window, const SDL_Rect *rects, int numrects);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to update. |
| const [SDL_Rect](SDL_Rect.html) \* | **rects** | an array of [SDL_Rect](SDL_Rect.html) structures representing areas of the surface to copy, in pixels. |
| int | **numrects** | the number of rectangles. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This is the function you use to reflect changes to portions of the
surface on the screen.

This function is equivalent to the SDL 1.2 API
[SDL_UpdateRects](SDL_UpdateRects.html)().

Note that this function will update *at least* the rectangles specified,
but this is only intended as an optimization; in practice, this might
update more of the screen (or all of the screen!), depending on what
method SDL uses to send pixels to the system.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetWindowSurface](SDL_GetWindowSurface.html)
- [SDL_UpdateWindowSurface](SDL_UpdateWindowSurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVideo](CategoryVideo.html)
