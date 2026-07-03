# SDL_DownloadFromGPUBuffer

Copies data from a buffer to a transfer buffer on the GPU timeline.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DownloadFromGPUBuffer(
    SDL_GPUCopyPass *copy_pass,
    const SDL_GPUBufferRegion *source,
    const SDL_GPUTransferBufferLocation *destination);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCopyPass](SDL_GPUCopyPass.html) \* | **copy_pass** | a copy pass handle. |
| const [SDL_GPUBufferRegion](SDL_GPUBufferRegion.html) \* | **source** | the source buffer with offset and size. |
| const [SDL_GPUTransferBufferLocation](SDL_GPUTransferBufferLocation.html) \* | **destination** | the destination transfer buffer with offset. |

## Remarks

This data is not guaranteed to be copied until the command buffer fence
is signaled.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
