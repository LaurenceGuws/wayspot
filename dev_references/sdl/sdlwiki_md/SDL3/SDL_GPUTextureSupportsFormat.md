# SDL_GPUTextureSupportsFormat

Determines whether a texture format is supported for a given type and
usage.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GPUTextureSupportsFormat(
    SDL_GPUDevice *device,
    SDL_GPUTextureFormat format,
    SDL_GPUTextureType type,
    SDL_GPUTextureUsageFlags usage);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_GPUTextureFormat](SDL_GPUTextureFormat.html) | **format** | the texture format to check. |
| [SDL_GPUTextureType](SDL_GPUTextureType.html) | **type** | the type of texture (2D, 3D, Cube). |
| [SDL_GPUTextureUsageFlags](SDL_GPUTextureUsageFlags.html) | **usage** | a bitmask of all usage scenarios to check. |

## Return Value

(bool) Returns whether the texture format is supported for this type and
usage.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
