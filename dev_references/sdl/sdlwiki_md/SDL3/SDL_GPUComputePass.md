# SDL_GPUComputePass

An opaque handle representing a compute pass.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUComputePass SDL_GPUComputePass;
```

</div>

## Remarks

This handle is transient and should not be held or referenced after
[SDL_EndGPUComputePass](SDL_EndGPUComputePass.html) is called.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_BeginGPUComputePass](SDL_BeginGPUComputePass.html)
- [SDL_EndGPUComputePass](SDL_EndGPUComputePass.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryGPU](CategoryGPU.html)
