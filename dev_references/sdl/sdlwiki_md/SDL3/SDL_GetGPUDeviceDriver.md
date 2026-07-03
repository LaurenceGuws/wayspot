# SDL_GetGPUDeviceDriver

Returns the name of the backend used to create this GPU context.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetGPUDeviceDriver(SDL_GPUDevice *device);
```

</div>

## Function Parameters

|                                        |            |                         |
|----------------------------------------|------------|-------------------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context to query. |

## Return Value

(const char \*) Returns the name of the device's driver, or NULL on
error.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
