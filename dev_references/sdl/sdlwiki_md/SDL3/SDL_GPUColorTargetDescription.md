# SDL_GPUColorTargetDescription

A structure specifying the parameters of color targets used in a
graphics pipeline.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUColorTargetDescription
{
    SDL_GPUTextureFormat format;               /**< The pixel format of the texture to be used as a color target. */
    SDL_GPUColorTargetBlendState blend_state;  /**< The blend state to be used for the color target. */
} SDL_GPUColorTargetDescription;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_GPUGraphicsPipelineTargetInfo](SDL_GPUGraphicsPipelineTargetInfo.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
