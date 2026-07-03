# SDL_SetGPUBlendConstants

Sets the current blend constants on a command buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_SetGPUBlendConstants(
    SDL_GPURenderPass *render_pass,
    SDL_FColor blend_constants);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPURenderPass](SDL_GPURenderPass.html) \* | **render_pass** | a render pass handle. |
| [SDL_FColor](SDL_FColor.html) | **blend_constants** | the blend constant color. |

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GPU_BLENDFACTOR_CONSTANT_COLOR](SDL_GPU_BLENDFACTOR_CONSTANT_COLOR.html)
- [SDL_GPU_BLENDFACTOR_ONE_MINUS_CONSTANT_COLOR](SDL_GPU_BLENDFACTOR_ONE_MINUS_CONSTANT_COLOR.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
