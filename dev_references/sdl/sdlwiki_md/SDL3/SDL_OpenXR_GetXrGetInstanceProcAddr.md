# SDL_OpenXR_GetXrGetInstanceProcAddr

Get the address of the `xrGetInstanceProcAddr` function.

## Header File

Defined in
[\<SDL3/SDL_openxr.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_openxr.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
PFN_xrGetInstanceProcAddr SDL_OpenXR_GetXrGetInstanceProcAddr(void);
```

</div>

## Return Value

(PFN_xrGetInstanceProcAddr) Returns the function pointer for
`xrGetInstanceProcAddr` or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This should be called after either calling
[SDL_OpenXR_LoadLibrary](SDL_OpenXR_LoadLibrary.html)() or creating an
OpenXR [SDL_GPUDevice](SDL_GPUDevice.html).

The actual type of the returned function pointer is
PFN_xrGetInstanceProcAddr, but that isn't always available. You should
include the OpenXR headers before this header, or cast the return value
of this function to the correct type.

## Version

This function is available since SDL 3.6.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryOpenxr](CategoryOpenxr.html)
