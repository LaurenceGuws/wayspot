# SDL_GPUTextureType

Specifies the type of a texture.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_GPUTextureType
{
    SDL_GPU_TEXTURETYPE_2D,         /**< The texture is a 2-dimensional image. */
    SDL_GPU_TEXTURETYPE_2D_ARRAY,   /**< The texture is a 2-dimensional array image. */
    SDL_GPU_TEXTURETYPE_3D,         /**< The texture is a 3-dimensional image. */
    SDL_GPU_TEXTURETYPE_CUBE,       /**< The texture is a cube image. */
    SDL_GPU_TEXTURETYPE_CUBE_ARRAY  /**< The texture is a cube array image. */
} SDL_GPUTextureType;
```

</div>

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUTexture](SDL_CreateGPUTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html), [CategoryGPU](CategoryGPU.html)
