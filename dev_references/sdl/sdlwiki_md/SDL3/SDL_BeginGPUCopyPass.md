# SDL_BeginGPUCopyPass

Begins a copy pass on a command buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUCopyPass * SDL_BeginGPUCopyPass(
    SDL_GPUCommandBuffer *command_buffer);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |

## Return Value

([SDL_GPUCopyPass](SDL_GPUCopyPass.html) \*) Returns a copy pass handle.

## Remarks

All operations related to copying to or from buffers or textures take
place inside a copy pass. You must not begin another copy pass, or a
render pass or compute pass before ending the copy pass.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_EndGPUCopyPass](SDL_EndGPUCopyPass.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
