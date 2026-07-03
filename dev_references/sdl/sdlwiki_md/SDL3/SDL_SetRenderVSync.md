# SDL_SetRenderVSync

Toggle VSync of the given renderer.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetRenderVSync(SDL_Renderer *renderer, int vsync);


#define SDL_RENDERER_VSYNC_DISABLED 0
#define SDL_RENDERER_VSYNC_ADAPTIVE (-1)
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the renderer to toggle. |
| int | **vsync** | the vertical refresh sync interval. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

When a renderer is created, vsync defaults to
[SDL_RENDERER_VSYNC_DISABLED](SDL_RENDERER_VSYNC_DISABLED.html).

The `vsync` parameter can be 1 to synchronize present with every
vertical refresh, 2 to synchronize present with every second vertical
refresh, etc.,
[SDL_RENDERER_VSYNC_ADAPTIVE](SDL_RENDERER_VSYNC_ADAPTIVE.html) for late
swap tearing (adaptive vsync), or
[SDL_RENDERER_VSYNC_DISABLED](SDL_RENDERER_VSYNC_DISABLED.html) to
disable. Not every value is supported by every driver, so you should
check the return value to see whether the requested setting is
supported.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetRenderVSync](SDL_GetRenderVSync.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
