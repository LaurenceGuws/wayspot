# SDL_OpenXR_UnloadLibrary

Unload the OpenXR loader previously loaded by
[SDL_OpenXR_LoadLibrary](SDL_OpenXR_LoadLibrary.html).

## Header File

Defined in
[\<SDL3/SDL_openxr.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_openxr.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_OpenXR_UnloadLibrary(void);
```

</div>

## Remarks

SDL keeps a reference count of the OpenXR loader, calling this function
will decrement that count. Once the reference count reaches zero, the
library is unloaded.

## Thread Safety

This function is not thread safe.

## Version

This function is available since SDL 3.6.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryOpenxr](CategoryOpenxr.html)
