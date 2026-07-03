# SDL_GetGPUXRSwapchainFormats

Queries the GPU device for supported XR swapchain image formats.

## Header File

Defined in
[\<SDL3/SDL_openxr.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_openxr.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_GPUTextureFormat * SDL_GetGPUXRSwapchainFormats(SDL_GPUDevice *device, XrSession session, int *num_formats);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_GPUDevice](SDL_GPUDevice.html) \* | **device** | a GPU context. |
| XrSession | **session** | an OpenXR session created for the given device. |
| int \* | **num_formats** | a pointer filled with the number of supported XR swapchain formats. |

## Return Value

([SDL_GPUTextureFormat](SDL_GPUTextureFormat.html) \*) Returns a 0
terminated array of supported formats or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This should be
freed with [SDL_free](SDL_free.html)() when it is no longer needed.

## Remarks

The returned pointer should be allocated with
[SDL_malloc](SDL_malloc.html)() and will be passed to
[SDL_free](SDL_free.html)().

## Version

This function is available since SDL 3.6.0.

## See Also

- [SDL_CreateGPUXRSwapchain](SDL_CreateGPUXRSwapchain.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryOpenxr](CategoryOpenxr.html)
