# SDL_WaitForGPUIdle

Blocks the thread until the GPU is completely idle.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_WaitForGPUIdle(
    SDL_GPUDevice *device);
```

</div>

## Function Parameters

|                                        |            |                |
|----------------------------------------|------------|----------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |

## Return Value

(bool) Returns true on success, false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_WaitForGPUFences](SDL_WaitForGPUFences.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
