# SDL_GPUTextureRegion

A structure specifying a region of a texture.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUTextureRegion
{
    SDL_GPUTexture *texture;  /**< The texture used in the copy operation. */
    Uint32 mip_level;         /**< The mip level index to transfer. */
    Uint32 layer;             /**< The layer index to transfer. */
    Uint32 x;                 /**< The left offset of the region. */
    Uint32 y;                 /**< The top offset of the region. */
    Uint32 z;                 /**< The front offset of the region. */
    Uint32 w;                 /**< The width of the region. */
    Uint32 h;                 /**< The height of the region. */
    Uint32 d;                 /**< The depth of the region. */
} SDL_GPUTextureRegion;
```

</div>

## Remarks

Used when transferring data to or from a texture.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_UploadToGPUTexture](SDL_UploadToGPUTexture.html)
- [SDL_DownloadFromGPUTexture](SDL_DownloadFromGPUTexture.html)
- [SDL_CreateGPUTexture](SDL_CreateGPUTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
