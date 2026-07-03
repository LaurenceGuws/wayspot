# SDL_Texture

An efficient driver-specific representation of pixel data

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
struct SDL_Texture
{
    SDL_PixelFormat format;     /**< The format of the texture, read-only */
    int w;                      /**< The width of the texture, read-only. */
    int h;                      /**< The height of the texture, read-only. */

    int refcount;               /**< Application reference count, used when freeing texture */
};
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_CreateTexture](SDL_CreateTexture.html)
- [SDL_CreateTextureFromSurface](SDL_CreateTextureFromSurface.html)
- [SDL_CreateTextureWithProperties](SDL_CreateTextureWithProperties.html)
- [SDL_DestroyTexture](SDL_DestroyTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryRender](CategoryRender.html)
