# SDL_GPUTextureSamplerBinding

A structure specifying parameters in a sampler binding call.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUTextureSamplerBinding
{
    SDL_GPUTexture *texture;  /**< The texture to bind. Must have been created with SDL_GPU_TEXTUREUSAGE_SAMPLER. */
    SDL_GPUSampler *sampler;  /**< The sampler to bind. */
} SDL_GPUTextureSamplerBinding;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_BindGPUVertexSamplers](SDL_BindGPUVertexSamplers.html)
- [SDL_BindGPUFragmentSamplers](SDL_BindGPUFragmentSamplers.html)
- [SDL_GPUTexture](SDL_GPUTexture.html)
- [SDL_GPUSampler](SDL_GPUSampler.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
