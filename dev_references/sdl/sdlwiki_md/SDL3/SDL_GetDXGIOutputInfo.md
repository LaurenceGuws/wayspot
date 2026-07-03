# SDL_GetDXGIOutputInfo

Get the DXGI Adapter and Output indices for the specified display.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetDXGIOutputInfo(SDL_DisplayID displayID, int *adapterIndex, int *outputIndex);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DisplayID](SDL_DisplayID.html) | **displayID** | the instance of the display to query. |
| int \* | **adapterIndex** | a pointer to be filled in with the adapter index. |
| int \* | **outputIndex** | a pointer to be filled in with the output index. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The DXGI Adapter and Output indices can be passed to `EnumAdapters` and
`EnumOutputs` respectively to get the objects required to create a DX10
or DX11 device and swap chain.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
