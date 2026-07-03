# SDL_GetRenderClipRect

Get the clip rectangle for the current target.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRenderClipRect(SDL_Renderer *renderer, SDL_Rect *rect);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| [SDL_Rect](SDL_Rect.html) \* | **rect** | an [SDL_Rect](SDL_Rect.html) structure filled in with the current clipping area or an empty rectangle if clipping is disabled. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Each render target has its own clip rectangle. This function gets the
cliprect for the current render target.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_RenderClipEnabled](SDL_RenderClipEnabled.html)
- [SDL_SetRenderClipRect](SDL_SetRenderClipRect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
