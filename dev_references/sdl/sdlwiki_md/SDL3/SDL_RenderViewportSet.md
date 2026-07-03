# SDL_RenderViewportSet

Return whether an explicit rectangle was set as the viewport.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderViewportSet(SDL_Renderer *renderer);
```

</div>

## Function Parameters

|                                      |              |                        |
|--------------------------------------|--------------|------------------------|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |

## Return Value

(bool) Returns true if the viewport was set to a specific rectangle, or
false if it was set to NULL (the entire target).

## Remarks

This is useful if you're saving and restoring the viewport and want to
know whether you should restore a specific rectangle or NULL.

Each render target has its own viewport. This function checks the
viewport for the current render target.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderViewport](SDL_GetRenderViewport.html)
- [SDL_SetRenderViewport](SDL_SetRenderViewport.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
