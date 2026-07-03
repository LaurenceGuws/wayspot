# SDL_CopyGPUBufferToBuffer

Performs a buffer-to-buffer copy.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_CopyGPUBufferToBuffer(
    SDL_GPUCopyPass *copy_pass,
    const SDL_GPUBufferLocation *source,
    const SDL_GPUBufferLocation *destination,
    Uint32 size,
    bool cycle);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCopyPass](SDL_GPUCopyPass.html) \* | **copy_pass** | a copy pass handle. |
| const [SDL_GPUBufferLocation](SDL_GPUBufferLocation.html) \* | **source** | the buffer and offset to copy from. |
| const [SDL_GPUBufferLocation](SDL_GPUBufferLocation.html) \* | **destination** | the buffer and offset to copy to. |
| [Uint32](Uint32.html) | **size** | the length of the buffer to copy. |
| bool | **cycle** | if true, cycles the destination buffer if it is already bound, otherwise overwrites the data. |

## Remarks

This copy occurs on the GPU timeline. You may assume the copy has
finished in subsequent commands.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
