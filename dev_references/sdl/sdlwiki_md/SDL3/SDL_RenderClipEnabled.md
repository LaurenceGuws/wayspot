# SDL_RenderClipEnabled

Get whether clipping is enabled on the given render target.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RenderClipEnabled(SDL_Renderer *renderer);
```

</div>

## Function Parameters

|                                      |              |                        |
|--------------------------------------|--------------|------------------------|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |

## Return Value

(bool) Returns true if clipping is enabled or false if not; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Each render target has its own clip rectangle. This function checks the
cliprect for the current render target.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderClipRect](SDL_GetRenderClipRect.html)
- [SDL_SetRenderClipRect](SDL_SetRenderClipRect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
