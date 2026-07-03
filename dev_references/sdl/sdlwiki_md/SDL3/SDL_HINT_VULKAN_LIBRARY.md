# SDL_HINT_VULKAN_LIBRARY

Specify the Vulkan library to load.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VULKAN_LIBRARY "SDL_VULKAN_LIBRARY"
```

</div>

## Remarks

This hint should be set before creating a Vulkan window or calling
[SDL_Vulkan_LoadLibrary](SDL_Vulkan_LoadLibrary.html)().

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
