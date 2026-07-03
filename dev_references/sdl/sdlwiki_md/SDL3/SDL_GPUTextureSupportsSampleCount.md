# SDL_GPUTextureSupportsSampleCount

Determines if a sample count for a texture format is supported.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GPUTextureSupportsSampleCount(
    SDL_GPUDevice *device,
    SDL_GPUTextureFormat format,
    SDL_GPUSampleCount sample_count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_GPUTextureFormat](SDL_GPUTextureFormat.html) | **format** | the texture format to check. |
| [SDL_GPUSampleCount](SDL_GPUSampleCount.html) | **sample_count** | the sample count to check. |

## Return Value

(bool) Returns whether the sample count is supported for this texture
format.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
