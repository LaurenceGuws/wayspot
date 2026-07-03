# SDL_CalculateGPUTextureFormatSize

Calculate the size in bytes of a texture format with dimensions.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint32 SDL_CalculateGPUTextureFormatSize(
    SDL_GPUTextureFormat format,
    Uint32 width,
    Uint32 height,
    Uint32 depth_or_layer_count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUTextureFormat](SDL_GPUTextureFormat.html) | **format** | a texture format. |
| [Uint32](Uint32.html) | **width** | width in pixels. |
| [Uint32](Uint32.html) | **height** | height in pixels. |
| [Uint32](Uint32.html) | **depth_or_layer_count** | depth for 3D textures or layer count otherwise. |

## Return Value

([Uint32](Uint32.html)) Returns the size of a texture with this format
and dimensions.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
