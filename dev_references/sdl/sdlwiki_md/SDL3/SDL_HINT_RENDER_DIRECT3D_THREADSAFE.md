# SDL_HINT_RENDER_DIRECT3D_THREADSAFE

A variable controlling whether the Direct3D device is initialized for
thread-safe operations.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_RENDER_DIRECT3D_THREADSAFE "SDL_RENDER_DIRECT3D_THREADSAFE"
```

</div>

## Remarks

The variable can be set to the following values:

- "0": Thread-safety is not enabled. (default)
- "1": Thread-safety is enabled.

This hint should be set before creating a renderer.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
