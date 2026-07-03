# SDL_GetGPUSwapchainTextureFormat

Obtains the texture format of the swapchain for the given window.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUTextureFormat SDL_GetGPUSwapchainTextureFormat(
    SDL_GPUDevice *device,
    SDL_Window *window);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| [SDL_Window](SDL_Window.html) \* | **window** | an [SDL_Window](SDL_Window.html) that has been claimed. |

## Return Value

([SDL_GPUTextureFormat](SDL_GPUTextureFormat.html)) Returns the texture
format of the swapchain.

## Remarks

Note that this format can change if the swapchain parameters change.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
