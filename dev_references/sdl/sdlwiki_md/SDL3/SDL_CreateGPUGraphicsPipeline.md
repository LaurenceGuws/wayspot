# SDL_CreateGPUGraphicsPipeline

Creates a pipeline object to be used in a graphics workflow.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUGraphicsPipeline * SDL_CreateGPUGraphicsPipeline(
    SDL_GPUDevice *device,
    const SDL_GPUGraphicsPipelineCreateInfo *createinfo);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU Context. |
| const [SDL_GPUGraphicsPipelineCreateInfo](SDL_GPUGraphicsPipelineCreateInfo.html) \* | **createinfo** | a struct describing the state of the graphics pipeline to create. |

## Return Value

([SDL_GPUGraphicsPipeline](SDL_GPUGraphicsPipeline.html) \*) Returns a
graphics pipeline object on success, or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

There are optional properties that can be provided through `props`.
These are the supported properties:

- [`SDL_PROP_GPU_GRAPHICSPIPELINE_CREATE_NAME_STRING`](SDL_PROP_GPU_GRAPHICSPIPELINE_CREATE_NAME_STRING.html):
  a name that can be displayed in debugging tools.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUShader](SDL_CreateGPUShader.html)
- [SDL_BindGPUGraphicsPipeline](SDL_BindGPUGraphicsPipeline.html)
- [SDL_ReleaseGPUGraphicsPipeline](SDL_ReleaseGPUGraphicsPipeline.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
