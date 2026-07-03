# SDL_SetRenderClipRect

Set the clip rectangle for rendering on the specified target.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetRenderClipRect(SDL_Renderer *renderer, const SDL_Rect *rect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| const [SDL_Rect](SDL_Rect.html) \* | **rect** | an [SDL_Rect](SDL_Rect.html) structure representing the clip area, relative to the viewport, or NULL to disable clipping. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Each render target has its own clip rectangle. This function sets the
cliprect for the current render target.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderClipRect](SDL_GetRenderClipRect.html)
- [SDL_RenderClipEnabled](SDL_RenderClipEnabled.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
