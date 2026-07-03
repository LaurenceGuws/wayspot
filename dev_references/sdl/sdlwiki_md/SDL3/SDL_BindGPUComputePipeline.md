# SDL_BindGPUComputePipeline

Binds a compute pipeline on a command buffer for use in compute
dispatch.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_BindGPUComputePipeline(
    SDL_GPUComputePass *compute_pass,
    SDL_GPUComputePipeline *compute_pipeline);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUComputePass](SDL_GPUComputePass.html) \* | **compute_pass** | a compute pass handle. |
| [SDL_GPUComputePipeline](SDL_GPUComputePipeline.html) \* | **compute_pipeline** | a compute pipeline to bind. |

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
