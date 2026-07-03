# SDL_GPUFrontFace

Specifies the vertex winding that will cause a triangle to be determined
to be front-facing.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_GPUFrontFace
{
    SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,  /**< A triangle with counter-clockwise vertex winding will be considered front-facing. */
    SDL_GPU_FRONTFACE_CLOCKWISE           /**< A triangle with clockwise vertex winding will be considered front-facing. */
} SDL_GPUFrontFace;
```

</div>

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUGraphicsPipeline](SDL_CreateGPUGraphicsPipeline.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html), [CategoryGPU](CategoryGPU.html)
