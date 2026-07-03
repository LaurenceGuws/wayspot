# SDL_GPUTextureLocation

A structure specifying a location in a texture.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUTextureLocation
{
    SDL_GPUTexture *texture;  /**< The texture used in the copy operation. */
    Uint32 mip_level;         /**< The mip level index of the location. */
    Uint32 layer;             /**< The layer index of the location. */
    Uint32 x;                 /**< The left offset of the location. */
    Uint32 y;                 /**< The top offset of the location. */
    Uint32 z;                 /**< The front offset of the location. */
} SDL_GPUTextureLocation;
```

</div>

## Remarks

Used when copying data from one texture to another.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_CopyGPUTextureToTexture](SDL_CopyGPUTextureToTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
