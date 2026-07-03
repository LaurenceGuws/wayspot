# SDL_PopGPUDebugGroup

Ends the most-recently pushed debug group.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_PopGPUDebugGroup(
    SDL_GPUCommandBuffer *command_buffer);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |

## Remarks

On Direct3D 12, using [SDL_PopGPUDebugGroup](SDL_PopGPUDebugGroup.html)
requires WinPixEventRuntime.dll to be in your PATH or in the same
directory as your executable. See
[here](https://devblogs.microsoft.com/pix/winpixeventruntime/) for
instructions on how to obtain it.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PushGPUDebugGroup](SDL_PushGPUDebugGroup.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
