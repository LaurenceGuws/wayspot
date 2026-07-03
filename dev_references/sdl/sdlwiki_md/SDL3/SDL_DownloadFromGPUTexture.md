# SDL_DownloadFromGPUTexture

Copies data from a texture to a transfer buffer on the GPU timeline.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DownloadFromGPUTexture(
    SDL_GPUCopyPass *copy_pass,
    const SDL_GPUTextureRegion *source,
    const SDL_GPUTextureTransferInfo *destination);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCopyPass](SDL_GPUCopyPass.html) \* | **copy_pass** | a copy pass handle. |
| const [SDL_GPUTextureRegion](SDL_GPUTextureRegion.html) \* | **source** | the source texture region. |
| const [SDL_GPUTextureTransferInfo](SDL_GPUTextureTransferInfo.html) \* | **destination** | the destination transfer buffer with image layout information. |

## Remarks

This data is not guaranteed to be copied until the command buffer fence
is signaled.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
