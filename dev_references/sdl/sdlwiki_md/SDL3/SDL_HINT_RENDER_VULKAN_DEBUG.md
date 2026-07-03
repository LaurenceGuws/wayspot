# SDL_HINT_RENDER_VULKAN_DEBUG

A variable controlling whether to enable Vulkan Validation Layers.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_RENDER_VULKAN_DEBUG "SDL_RENDER_VULKAN_DEBUG"
```

</div>

## Remarks

This variable can be set to the following values:

- "0": Disable Validation Layer use
- "1": Enable Validation Layer use

By default, SDL does not use Vulkan Validation Layers.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
