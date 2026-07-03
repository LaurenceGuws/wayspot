# SDL_GetGPUShaderFormats

Returns the supported shader formats for this GPU context.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUShaderFormat SDL_GetGPUShaderFormats(SDL_GPUDevice *device);
```

</div>

## Function Parameters

|                                        |            |                         |
|----------------------------------------|------------|-------------------------|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context to query. |

## Return Value

([SDL_GPUShaderFormat](SDL_GPUShaderFormat.html)) Returns a bitflag
indicating which shader formats the driver is able to consume.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
