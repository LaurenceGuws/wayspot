# SDL_GPUColorTargetBlendState

A structure specifying the blend state of a color target.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUColorTargetBlendState
{
    SDL_GPUBlendFactor src_color_blendfactor;     /**< The value to be multiplied by the source RGB value. */
    SDL_GPUBlendFactor dst_color_blendfactor;     /**< The value to be multiplied by the destination RGB value. */
    SDL_GPUBlendOp color_blend_op;                /**< The blend operation for the RGB components. */
    SDL_GPUBlendFactor src_alpha_blendfactor;     /**< The value to be multiplied by the source alpha. */
    SDL_GPUBlendFactor dst_alpha_blendfactor;     /**< The value to be multiplied by the destination alpha. */
    SDL_GPUBlendOp alpha_blend_op;                /**< The blend operation for the alpha component. */
    SDL_GPUColorComponentFlags color_write_mask;  /**< A bitmask specifying which of the RGBA components are enabled for writing. Writes to all channels if enable_color_write_mask is false. */
    bool enable_blend;                            /**< Whether blending is enabled for the color target. */
    bool enable_color_write_mask;                 /**< Whether the color write mask is enabled. */
    Uint8 padding1;
    Uint8 padding2;
} SDL_GPUColorTargetBlendState;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_GPUColorTargetDescription](SDL_GPUColorTargetDescription.html)
- [SDL_GPUBlendFactor](SDL_GPUBlendFactor.html)
- [SDL_GPUBlendOp](SDL_GPUBlendOp.html)
- [SDL_GPUColorComponentFlags](SDL_GPUColorComponentFlags.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
