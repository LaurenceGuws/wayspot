# SDL_WindowSupportsGPUSwapchainComposition

Determines whether a swapchain composition is supported by the window.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WindowSupportsGPUSwapchainComposition(
    SDL_GPUDevice *device,
    SDL_Window *window,
    SDL_GPUSwapchainComposition swapchain_composition);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_Window](SDL_Window.html) \* | **window** | an [SDL_Window](SDL_Window.html). |
| [SDL_GPUSwapchainComposition](SDL_GPUSwapchainComposition.html) | **swapchain_composition** | the swapchain composition to check. |

## Return Value

(bool) Returns true if supported, false if unsupported.

## Remarks

The window must be claimed before calling this function.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_ClaimWindowForGPUDevice](SDL_ClaimWindowForGPUDevice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
