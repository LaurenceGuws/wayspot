# SDL_GetDirect3D9AdapterIndex

Get the D3D9 adapter index that matches the specified display.

## Header File

Defined in
[\<SDL3/SDL_system.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_system.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetDirect3D9AdapterIndex(SDL_DisplayID displayID);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_DisplayID](SDL_DisplayID.html) | **displayID** | the instance of the display to query. |

## Return Value

(int) Returns the D3D9 adapter index on success or -1 on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The returned adapter index can be passed to `IDirect3D9::CreateDevice`
and controls on which monitor a full screen application will appear.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySystem](CategorySystem.html)
