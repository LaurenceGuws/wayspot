# SDL_GPUGraphicsPipelineCreateInfo

A structure specifying the parameters of a graphics pipeline state.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUGraphicsPipelineCreateInfo
{
    SDL_GPUShader *vertex_shader;                   /**< The vertex shader used by the graphics pipeline. */
    SDL_GPUShader *fragment_shader;                 /**< The fragment shader used by the graphics pipeline. */
    SDL_GPUVertexInputState vertex_input_state;     /**< The vertex layout of the graphics pipeline. */
    SDL_GPUPrimitiveType primitive_type;            /**< The primitive topology of the graphics pipeline. */
    SDL_GPURasterizerState rasterizer_state;        /**< The rasterizer state of the graphics pipeline. */
    SDL_GPUMultisampleState multisample_state;      /**< The multisample state of the graphics pipeline. */
    SDL_GPUDepthStencilState depth_stencil_state;   /**< The depth-stencil state of the graphics pipeline. */
    SDL_GPUGraphicsPipelineTargetInfo target_info;  /**< Formats and blend modes for the render targets of the graphics pipeline. */

    SDL_PropertiesID props;                         /**< A properties ID for extensions. Should be 0 if no extensions are needed. */
} SDL_GPUGraphicsPipelineCreateInfo;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUGraphicsPipeline](SDL_CreateGPUGraphicsPipeline.html)
- [SDL_GPUShader](SDL_GPUShader.html)
- [SDL_GPUVertexInputState](SDL_GPUVertexInputState.html)
- [SDL_GPUPrimitiveType](SDL_GPUPrimitiveType.html)
- [SDL_GPURasterizerState](SDL_GPURasterizerState.html)
- [SDL_GPUMultisampleState](SDL_GPUMultisampleState.html)
- [SDL_GPUDepthStencilState](SDL_GPUDepthStencilState.html)
- [SDL_GPUGraphicsPipelineTargetInfo](SDL_GPUGraphicsPipelineTargetInfo.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
