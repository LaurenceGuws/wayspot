# SDL_GetNumRenderDrivers

Get the number of 2D rendering drivers available for the current
display.

## Header File

Defined in
[\<SDL3/SDL_render.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_render.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetNumRenderDrivers(void);
```

</div>

## Return Value

(int) Returns the number of built in render drivers.

## Remarks

A render driver is a set of code that handles rendering and texture
management on a particular display. Normally there is only one, but some
drivers may have several available with different capabilities.

There may be none if SDL was compiled without render support.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateRenderer](SDL_CreateRenderer.html)
- [SDL_GetRenderDriver](SDL_GetRenderDriver.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRender](CategoryRender.html)
