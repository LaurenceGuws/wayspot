# SDL_GenerateMipmapsForGPUTexture

Generates mipmaps for the given texture.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_GenerateMipmapsForGPUTexture(
    SDL_GPUCommandBuffer *command_buffer,
    SDL_GPUTexture *texture);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command_buffer. |
| [SDL_GPUTexture](SDL_GPUTexture.html) \* | **texture** | a texture with more than 1 mip level. |

## Remarks

This function must not be called inside of any pass.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
