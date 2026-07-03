# SDL_GPUTextureFormatTexelBlockSize

Obtains the texel block size for a texture format.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint32 SDL_GPUTextureFormatTexelBlockSize(
    SDL_GPUTextureFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUTextureFormat](SDL_GPUTextureFormat.html) | **format** | the texture format you want to know the texel size of. |

## Return Value

([Uint32](Uint32.html)) Returns the texel block size of the texture
format.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_UploadToGPUTexture](SDL_UploadToGPUTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
