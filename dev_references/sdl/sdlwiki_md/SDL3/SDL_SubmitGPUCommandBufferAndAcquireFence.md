# SDL_SubmitGPUCommandBufferAndAcquireFence

Submits a command buffer so its commands can be processed on the GPU,
and acquires a fence associated with the command buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUFence * SDL_SubmitGPUCommandBufferAndAcquireFence(
    SDL_GPUCommandBuffer *command_buffer);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |

## Return Value

([SDL_GPUFence](SDL_GPUFence.html) \*) Returns a fence associated with
the command buffer, or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

You must release this fence when it is no longer needed or it will cause
a leak. It is invalid to use the command buffer after this is called.

This must be called from the thread the command buffer was acquired on.

All commands in the submission are guaranteed to begin executing before
any command in a subsequent submission begins executing.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AcquireGPUCommandBuffer](SDL_AcquireGPUCommandBuffer.html)
- [SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)
- [SDL_AcquireGPUSwapchainTexture](SDL_AcquireGPUSwapchainTexture.html)
- [SDL_SubmitGPUCommandBuffer](SDL_SubmitGPUCommandBuffer.html)
- [SDL_ReleaseGPUFence](SDL_ReleaseGPUFence.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
