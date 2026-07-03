# SDL_GPURenderPass

An opaque handle representing a render pass.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPURenderPass SDL_GPURenderPass;
```

</div>

## Remarks

This handle is transient and should not be held or referenced after
[SDL_EndGPURenderPass](SDL_EndGPURenderPass.html) is called.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_BeginGPURenderPass](SDL_BeginGPURenderPass.html)
- [SDL_EndGPURenderPass](SDL_EndGPURenderPass.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryGPU](CategoryGPU.html)
