# SDL_DrawGPUIndexedPrimitivesIndirect

Draws data using bound graphics state with an index buffer enabled and
with draw parameters set from a buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DrawGPUIndexedPrimitivesIndirect(
    SDL_GPURenderPass *render_pass,
    SDL_GPUBuffer *buffer,
    Uint32 offset,
    Uint32 draw_count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPURenderPass](SDL_GPURenderPass.html) \* | **render_pass** | a render pass handle. |
| [SDL_GPUBuffer](SDL_GPUBuffer.html) \* | **buffer** | a buffer containing draw parameters. |
| [Uint32](Uint32.html) | **offset** | the offset to start reading from the draw buffer. |
| [Uint32](Uint32.html) | **draw_count** | the number of draw parameter sets that should be read from the draw buffer. |

## Remarks

The buffer must consist of tightly-packed draw parameter sets that each
match the layout of
[SDL_GPUIndexedIndirectDrawCommand](SDL_GPUIndexedIndirectDrawCommand.html).
You must not call this function before binding a graphics pipeline.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
