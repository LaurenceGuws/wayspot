# SDL_DestroyGPUDevice

Destroys a GPU context previously returned by
[SDL_CreateGPUDevice](SDL_CreateGPUDevice.html).

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyGPUDevice(SDL_GPUDevice *device);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU Context to destroy. |

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUDevice](SDL_CreateGPUDevice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
