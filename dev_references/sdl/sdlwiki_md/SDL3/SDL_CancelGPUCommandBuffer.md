# SDL_CancelGPUCommandBuffer

Cancels a command buffer.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_CancelGPUCommandBuffer(
    SDL_GPUCommandBuffer *command_buffer);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |

## Return Value

(bool) Returns true on success, false on error; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

None of the enqueued commands are executed.

It is an error to call this function after a swapchain texture has been
acquired.

This must be called from the thread the command buffer was acquired on.

You must not reference the command buffer after calling this function.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)
- [SDL_AcquireGPUCommandBuffer](SDL_AcquireGPUCommandBuffer.html)
- [SDL_AcquireGPUSwapchainTexture](SDL_AcquireGPUSwapchainTexture.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
