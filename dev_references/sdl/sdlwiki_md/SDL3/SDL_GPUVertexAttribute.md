# SDL_GPUVertexAttribute

A structure specifying a vertex attribute.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUVertexAttribute
{
    Uint32 location;                    /**< The shader input location index. */
    Uint32 buffer_slot;                 /**< The binding slot of the associated vertex buffer. */
    SDL_GPUVertexElementFormat format;  /**< The size and type of the attribute data. */
    Uint32 offset;                      /**< The byte offset of this attribute relative to the start of the vertex element. */
} SDL_GPUVertexAttribute;
```

</div>

## Remarks

All vertex attribute locations provided to an
[SDL_GPUVertexInputState](SDL_GPUVertexInputState.html) must be unique.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_GPUVertexBufferDescription](SDL_GPUVertexBufferDescription.html)
- [SDL_GPUVertexInputState](SDL_GPUVertexInputState.html)
- [SDL_GPUVertexElementFormat](SDL_GPUVertexElementFormat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
