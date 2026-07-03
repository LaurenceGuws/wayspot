# SDL_ReleaseGPUGraphicsPipeline

Frees the given graphics pipeline as soon as it is safe to do so.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_ReleaseGPUGraphicsPipeline(
    SDL_GPUDevice *device,
    SDL_GPUGraphicsPipeline *graphics_pipeline);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_GPUGraphicsPipeline](SDL_GPUGraphicsPipeline.html) \* | **graphics_pipeline** | a graphics pipeline to be destroyed. |

## Remarks

You must not reference the graphics pipeline after calling this
function.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
