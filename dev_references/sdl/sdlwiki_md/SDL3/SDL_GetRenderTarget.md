# SDL_GetRenderTarget

Get the current render target.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Texture * SDL_GetRenderTarget(SDL_Renderer *renderer);
```

</div>

## Function Parameters

|                                      |              |                        |
|--------------------------------------|--------------|------------------------|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |

## Return Value

([SDL_Texture](SDL_Texture.html) \*) Returns the current render target
or NULL for the default render target.

## Remarks

The default render target is the window for which the renderer was
created, and is reported a NULL here.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_SetRenderTarget](SDL_SetRenderTarget.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
