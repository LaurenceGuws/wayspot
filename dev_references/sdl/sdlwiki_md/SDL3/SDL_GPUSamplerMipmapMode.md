# SDL_GPUSamplerMipmapMode

Specifies a mipmap mode used by a sampler.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_GPUSamplerMipmapMode
{
    SDL_GPU_SAMPLERMIPMAPMODE_NEAREST,  /**< Point filtering. */
    SDL_GPU_SAMPLERMIPMAPMODE_LINEAR    /**< Linear filtering. */
} SDL_GPUSamplerMipmapMode;
```

</div>

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUSampler](SDL_CreateGPUSampler.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html), [CategoryGPU](CategoryGPU.html)
