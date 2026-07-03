# SDL_RenderCoordinatesToWindow

Get a point in window coordinates when given a point in render
coordinates.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderCoordinatesToWindow(SDL_Renderer *renderer, float x, float y, float *window_x, float *window_y);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| float | **x** | the x coordinate in render coordinates. |
| float | **y** | the y coordinate in render coordinates. |
| float \* | **window_x** | a pointer filled with the x coordinate in window coordinates. |
| float \* | **window_y** | a pointer filled with the y coordinate in window coordinates. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This takes into account several states:

- The window dimensions.
- The logical presentation settings
  ([SDL_SetRenderLogicalPresentation](SDL_SetRenderLogicalPresentation.html))
- The scale ([SDL_SetRenderScale](SDL_SetRenderScale.html))
- The viewport ([SDL_SetRenderViewport](SDL_SetRenderViewport.html))

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetRenderLogicalPresentation](SDL_SetRenderLogicalPresentation.html)
- [SDL_SetRenderScale](SDL_SetRenderScale.html)
- [SDL_SetRenderViewport](SDL_SetRenderViewport.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
