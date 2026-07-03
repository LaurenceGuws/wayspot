# SDL_BindGPUIndexBuffer

Binds an index buffer on a command buffer for use with subsequent draw
calls.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_BindGPUIndexBuffer(
    SDL_GPURenderPass *render_pass,
    const SDL_GPUBufferBinding *binding,
    SDL_GPUIndexElementSize index_element_size);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPURenderPass](SDL_GPURenderPass.html) \* | **render_pass** | a render pass handle. |
| const [SDL_GPUBufferBinding](SDL_GPUBufferBinding.html) \* | **binding** | a pointer to a struct containing an index buffer and offset. |
| [SDL_GPUIndexElementSize](SDL_GPUIndexElementSize.html) | **index_element_size** | whether the index values in the buffer are 16- or 32-bit. |

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
