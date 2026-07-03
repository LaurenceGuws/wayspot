# SDL_GPUBufferBinding

A structure specifying parameters in a buffer binding call.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUBufferBinding
{
    SDL_GPUBuffer *buffer;  /**< The buffer to bind. Must have been created with SDL_GPU_BUFFERUSAGE_VERTEX for SDL_BindGPUVertexBuffers, or SDL_GPU_BUFFERUSAGE_INDEX for SDL_BindGPUIndexBuffer. */
    Uint32 offset;          /**< The starting byte of the data to bind in the buffer. */
} SDL_GPUBufferBinding;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_BindGPUVertexBuffers](SDL_BindGPUVertexBuffers.html)
- [SDL_BindGPUIndexBuffer](SDL_BindGPUIndexBuffer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
