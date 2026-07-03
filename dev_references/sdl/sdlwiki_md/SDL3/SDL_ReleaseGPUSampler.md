# SDL_ReleaseGPUSampler

Frees the given sampler as soon as it is safe to do so.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_ReleaseGPUSampler(
    SDL_GPUDevice *device,
    SDL_GPUSampler *sampler);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_GPUSampler](SDL_GPUSampler.html) \* | **sampler** | a sampler to be destroyed. |

## Remarks

You must not reference the sampler after calling this function.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
