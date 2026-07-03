# SDL_GPUSupportsProperties

Checks for GPU runtime support.

## Header File

Defined in
[\<SDL3/SDL_gpu.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gpu.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GPUSupportsProperties(
    SDL_PropertiesID props);
```

</div>

## Function Parameters

|                                           |           |                        |
|-------------------------------------------|-----------|------------------------|
| [SDL_PropertiesID](SDL_PropertiesID.html) | **props** | the properties to use. |

## Return Value

(bool) Returns true if supported, false otherwise.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateGPUDeviceWithProperties](SDL_CreateGPUDeviceWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGPU](CategoryGPU.html)
