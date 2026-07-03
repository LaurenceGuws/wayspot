# SDL_ClaimWindowForGPUDevice

Claims a window, creating a swapchain structure for it.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_ClaimWindowForGPUDevice(
    SDL_GPUDevice *device,
    SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_Window](SDL_Window.html) \* | **window** | an [SDL_Window](SDL_Window.html). |

## Return Value

(bool) Returns true on success, or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This must be called before
[SDL_AcquireGPUSwapchainTexture](SDL_AcquireGPUSwapchainTexture.html) is
called using the window. You should only call this function from the
thread that created the window.

The swapchain will be created with
[SDL_GPU_SWAPCHAINCOMPOSITION_SDR](SDL_GPU_SWAPCHAINCOMPOSITION_SDR.html)
and [SDL_GPU_PRESENTMODE_VSYNC](SDL_GPU_PRESENTMODE_VSYNC.html). If you
want to have different swapchain parameters, you must call
[SDL_SetGPUSwapchainParameters](SDL_SetGPUSwapchainParameters.html)
after claiming the window.

## Thread Safety

This function should only be called from the thread that created the
window.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_WaitAndAcquireGPUSwapchainTexture](SDL_WaitAndAcquireGPUSwapchainTexture.html)
- [SDL_ReleaseWindowFromGPUDevice](SDL_ReleaseWindowFromGPUDevice.html)
- [SDL_WindowSupportsGPUPresentMode](SDL_WindowSupportsGPUPresentMode.html)
- [SDL_WindowSupportsGPUSwapchainComposition](SDL_WindowSupportsGPUSwapchainComposition.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
