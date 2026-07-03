# SDL_CreateGPUSampler

Creates a sampler object to be used when binding textures in a graphics
workflow.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUSampler * SDL_CreateGPUSampler(
    SDL_GPUDevice *device,
    const SDL_GPUSamplerCreateInfo *createinfo);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU Context. |
| const [SDL_GPUSamplerCreateInfo](SDL_GPUSamplerCreateInfo.html) \* | **createinfo** | a struct describing the state of the sampler to create. |

## Return Value

([SDL_GPUSampler](SDL_GPUSampler.html) \*) Returns a sampler object on
success, or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information.

## Remarks

There are optional properties that can be provided through `props`.
These are the supported properties:

- [`SDL_PROP_GPU_SAMPLER_CREATE_NAME_STRING`](SDL_PROP_GPU_SAMPLER_CREATE_NAME_STRING.html):
  a name that can be displayed in debugging tools.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_BindGPUVertexSamplers](SDL_BindGPUVertexSamplers.html)
- [SDL_BindGPUFragmentSamplers](SDL_BindGPUFragmentSamplers.html)
- [SDL_ReleaseGPUSampler](SDL_ReleaseGPUSampler.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
