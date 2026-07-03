# SDL_GetPixelFormatFromGPUTextureFormat

Get the SDL pixel format corresponding to a GPU texture format.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PixelFormat SDL_GetPixelFormatFromGPUTextureFormat(SDL_GPUTextureFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUTextureFormat](SDL_GPUTextureFormat.html) | **format** | a texture format. |

## Return Value

([SDL_PixelFormat](SDL_PixelFormat.html)) Returns the corresponding
pixel format, or [SDL_PIXELFORMAT_UNKNOWN](SDL_PIXELFORMAT_UNKNOWN.html)
if there is no corresponding pixel format.

## Version

This function is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
