# SDL_TextureAddressMode

The addressing mode for a texture when used in
[SDL_RenderGeometry](SDL_RenderGeometry.html)().

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_TextureAddressMode
{
    SDL_TEXTURE_ADDRESS_INVALID = -1,
    SDL_TEXTURE_ADDRESS_AUTO,   /**< Wrapping is enabled if texture coordinates are outside [0, 1], this is the default */
    SDL_TEXTURE_ADDRESS_CLAMP,  /**< Texture coordinates are clamped to the [0, 1] range */
    SDL_TEXTURE_ADDRESS_WRAP    /**< The texture is repeated (tiled) */
} SDL_TextureAddressMode;
```

</div>

## Remarks

This affects how texture coordinates are interpreted outside of \[0, 1\]

Texture wrapping is always supported for power of two texture sizes, and
is supported for other texture sizes if
[SDL_PROP_RENDERER_TEXTURE_WRAPPING_BOOLEAN](SDL_PROP_RENDERER_TEXTURE_WRAPPING_BOOLEAN.html)
is set to true.

## Version

This enum is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryRender](CategoryRender.html)
