# SDL_GPUIndirectDispatchCommand

A structure specifying the parameters of an indexed dispatch command.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_GPUIndirectDispatchCommand
{
    Uint32 groupcount_x;  /**< The number of local workgroups to dispatch in the X dimension. */
    Uint32 groupcount_y;  /**< The number of local workgroups to dispatch in the Y dimension. */
    Uint32 groupcount_z;  /**< The number of local workgroups to dispatch in the Z dimension. */
} SDL_GPUIndirectDispatchCommand;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_DispatchGPUComputeIndirect](SDL_DispatchGPUComputeIndirect.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryGPU](CategoryGPU.html)
