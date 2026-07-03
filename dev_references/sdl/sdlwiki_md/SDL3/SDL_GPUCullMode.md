# SDL_GPUCullMode

Specifies the facing direction in which triangle faces will be culled.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_GPUCullMode
{
    SDL_GPU_CULLMODE_NONE,   /**< No triangles are culled. */
    SDL_GPU_CULLMODE_FRONT,  /**< Front-facing triangles are culled. */
    SDL_GPU_CULLMODE_BACK    /**< Back-facing triangles are culled. */
} SDL_GPUCullMode;
```

</div>

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUGraphicsPipeline](SDL_CreateGPUGraphicsPipeline.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html), [CategoryGPU](CategoryGPU.html)
