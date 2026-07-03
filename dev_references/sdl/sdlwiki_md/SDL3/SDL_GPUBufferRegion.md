# SDL_GPUBufferRegion

A structure specifying a region of a buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUBufferRegion
{
    SDL_GPUBuffer *buffer;  /**< The buffer. */
    Uint32 offset;          /**< The starting byte within the buffer. */
    Uint32 size;            /**< The size in bytes of the region. */
} SDL_GPUBufferRegion;
```

</div>

## Remarks

Used when transferring data to or from buffers.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_UploadToGPUBuffer](SDL_UploadToGPUBuffer.html)
- [SDL_DownloadFromGPUBuffer](SDL_DownloadFromGPUBuffer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
