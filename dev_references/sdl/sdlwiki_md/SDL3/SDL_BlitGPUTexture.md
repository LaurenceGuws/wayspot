# SDL_BlitGPUTexture

Blits from a source texture region to a destination texture region.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_BlitGPUTexture(
    SDL_GPUCommandBuffer *command_buffer,
    const SDL_GPUBlitInfo *info);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |
| const [SDL_GPUBlitInfo](SDL_GPUBlitInfo.html) \* | **info** | the blit info struct containing the blit parameters. |

## Remarks

This function must not be called inside of any pass.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
