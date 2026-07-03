# SDL_GPUVertexInputState

A structure specifying the parameters of a graphics pipeline vertex
input state.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUVertexInputState
{
    const SDL_GPUVertexBufferDescription *vertex_buffer_descriptions; /**< A pointer to an array of vertex buffer descriptions. */
    Uint32 num_vertex_buffers;                                        /**< The number of vertex buffer descriptions in the above array. */
    const SDL_GPUVertexAttribute *vertex_attributes;                  /**< A pointer to an array of vertex attribute descriptions. */
    Uint32 num_vertex_attributes;                                     /**< The number of vertex attribute descriptions in the above array. */
} SDL_GPUVertexInputState;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_GPUGraphicsPipelineCreateInfo](SDL_GPUGraphicsPipelineCreateInfo.html)
- [SDL_GPUVertexBufferDescription](SDL_GPUVertexBufferDescription.html)
- [SDL_GPUVertexAttribute](SDL_GPUVertexAttribute.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
