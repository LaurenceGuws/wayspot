# SDL_HINT_VULKAN_DISPLAY

A variable overriding the display index used in
[SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html)()

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VULKAN_DISPLAY "SDL_VULKAN_DISPLAY"
```

</div>

## Remarks

The display index starts at 0, which is the default.

This hint should be set before calling
[SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html)()

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
