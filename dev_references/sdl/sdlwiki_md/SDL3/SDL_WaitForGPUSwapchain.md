# SDL_WaitForGPUSwapchain

Blocks the thread until a swapchain texture is available to be acquired.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WaitForGPUSwapchain(
    SDL_GPUDevice *device,
    SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_Window](SDL_Window.html) \* | **window** | a window that has been claimed. |

## Return Value

(bool) Returns true on success, false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Thread Safety

This function should only be called from the thread that created the
window.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AcquireGPUSwapchainTexture](SDL_AcquireGPUSwapchainTexture.html)
- [SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)
- [SDL_SetGPUAllowedFramesInFlight](SDL_SetGPUAllowedFramesInFlight.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
