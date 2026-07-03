# SDL_AcquireGPUSwapchainTexture

Acquire a texture to use in presentation.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_AcquireGPUSwapchainTexture(
    SDL_GPUCommandBuffer *command_buffer,
    SDL_Window *window,
    SDL_GPUTexture **swapchain_texture,
    Uint32 *swapchain_texture_width,
    Uint32 *swapchain_texture_height);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUCommandBuffer](SDL_GPUCommandBuffer.html) \* | **command_buffer** | a command buffer. |
| [SDL_Window](SDL_Window.html) \* | **window** | a window that has been claimed. |
| [SDL_GPUTexture](SDL_GPUTexture.html) \*\* | **swapchain_texture** | a pointer filled in with a swapchain texture handle. |
| [Uint32](Uint32.html) \* | **swapchain_texture_width** | a pointer filled in with the swapchain texture width, may be NULL. |
| [Uint32](Uint32.html) \* | **swapchain_texture_height** | a pointer filled in with the swapchain texture height, may be NULL. |

## Return Value

(bool) Returns true on success, false on error; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

When a swapchain texture is acquired on a command buffer, it will
automatically be submitted for presentation when the command buffer is
submitted. The swapchain texture should only be referenced by the
command buffer used to acquire it.

This function will fill the swapchain texture handle with NULL if too
many frames are in flight. This is not an error. This NULL pointer
should not be passed back into SDL. Instead, it should be considered as
an indication to wait until the swapchain is available.

If you use this function, it is possible to create a situation where
many command buffers are allocated while the rendering context waits for
the GPU to catch up, which will cause memory usage to grow. You should
use
[SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)()
unless you know what you are doing with timing.

The swapchain texture is managed by the implementation and must not be
freed by the user. You MUST NOT call this function from any thread other
than the one that created the window.

## Thread Safety

This function should only be called from the thread that created the
window.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ClaimWindowForGPUDevice](SDL_ClaimWindowForGPUDevice.html)
- [SDL_SubmitGPUCommandBuffer](SDL_SubmitGPUCommandBuffer.html)
- [SDL_SubmitGPUCommandBufferAndAcquireFence](SDL_SubmitGPUCommandBufferAndAcquireFence.html)
- [SDL_CancelGPUCommandBuffer](SDL_CancelGPUCommandBuffer.html)
- [SDL_GetWindowSizeInPixels](SDL_GetWindowSizeInPixels.html)
- [SDL_WaitForGPUSwapchain](SDL_WaitForGPUSwapchain.html)
- [SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)
- [SDL_SetGPUAllowedFramesInFlight](SDL_SetGPUAllowedFramesInFlight.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
