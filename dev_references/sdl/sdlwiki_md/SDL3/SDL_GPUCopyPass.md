# SDL_GPUCopyPass

An opaque handle representing a copy pass.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUCopyPass SDL_GPUCopyPass;
```

</div>

## Remarks

This handle is transient and should not be held or referenced after
[SDL_EndGPUCopyPass](SDL_EndGPUCopyPass.html) is called.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_BeginGPUCopyPass](SDL_BeginGPUCopyPass.html)
- [SDL_EndGPUCopyPass](SDL_EndGPUCopyPass.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryGPU](CategoryGPU.html)
