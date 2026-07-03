# SDL_SetGPUSwapchainParameters

Changes the swapchain parameters for the given claimed window.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetGPUSwapchainParameters(
    SDL_GPUDevice *device,
    SDL_Window *window,
    SDL_GPUSwapchainComposition swapchain_composition,
    SDL_GPUPresentMode present_mode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_Window](SDL_Window.html) \* | **window** | an [SDL_Window](SDL_Window.html) that has been claimed. |
| [SDL_GPUSwapchainComposition](SDL_GPUSwapchainComposition.html) | **swapchain_composition** | the desired composition of the swapchain. |
| [SDL_GPUPresentMode](SDL_GPUPresentMode.html) | **present_mode** | the desired present mode for the swapchain. |

## Return Value

(bool) Returns true if successful, false on error; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function will fail if the requested present mode or swapchain
composition are unsupported by the device. Check if the parameters are
supported via
[SDL_WindowSupportsGPUPresentMode](SDL_WindowSupportsGPUPresentMode.html)
/
[SDL_WindowSupportsGPUSwapchainComposition](SDL_WindowSupportsGPUSwapchainComposition.html)
prior to calling this function.

[SDL_GPU_PRESENTMODE_VSYNC](SDL_GPU_PRESENTMODE_VSYNC.html) with
[SDL_GPU_SWAPCHAINCOMPOSITION_SDR](SDL_GPU_SWAPCHAINCOMPOSITION_SDR.html)
is always supported.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_WindowSupportsGPUPresentMode](SDL_WindowSupportsGPUPresentMode.html)
- [SDL_WindowSupportsGPUSwapchainComposition](SDL_WindowSupportsGPUSwapchainComposition.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
