# SDL_GetRendererFromTexture

Get the renderer that created an [SDL_Texture](SDL_Texture.html).

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Renderer * SDL_GetRendererFromTexture(SDL_Texture *texture);
```

</div>

## Function Parameters

|                                    |             |                       |
|------------------------------------|-------------|-----------------------|
| [SDL_Texture](SDL_Texture.html) \* | **texture** | the texture to query. |

## Return Value

([SDL_Renderer](SDL_Renderer.html) \*) Returns a pointer to the
[SDL_Renderer](SDL_Renderer.html) that created the texture, or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
