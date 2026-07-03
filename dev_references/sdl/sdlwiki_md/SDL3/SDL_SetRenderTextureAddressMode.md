# SDL_SetRenderTextureAddressMode

Set the texture addressing mode used in
[SDL_RenderGeometry](SDL_RenderGeometry.html)().

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetRenderTextureAddressMode(SDL_Renderer *renderer, SDL_TextureAddressMode u_mode, SDL_TextureAddressMode v_mode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Renderer](SDL_Renderer.html) \* | **renderer** | the rendering context. |
| [SDL_TextureAddressMode](SDL_TextureAddressMode.html) | **u_mode** | the [SDL_TextureAddressMode](SDL_TextureAddressMode.html) to use for horizontal texture coordinates in [SDL_RenderGeometry](SDL_RenderGeometry.html)(). |
| [SDL_TextureAddressMode](SDL_TextureAddressMode.html) | **v_mode** | the [SDL_TextureAddressMode](SDL_TextureAddressMode.html) to use for vertical texture coordinates in [SDL_RenderGeometry](SDL_RenderGeometry.html)(). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.4.0.

## See Also

- [SDL_RenderGeometry](SDL_RenderGeometry.html)
- [SDL_RenderGeometryRaw](SDL_RenderGeometryRaw.html)
- [SDL_GetRenderTextureAddressMode](SDL_GetRenderTextureAddressMode.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
