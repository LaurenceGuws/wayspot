# SDL_HINT_VITA_PVR_INIT

A variable controlling whether to perform PVR initialization on the
PlayStation Vita.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VITA_PVR_INIT "SDL_VITA_PVR_INIT"
```

</div>

## Remarks

- "0": Skip PVR initialization.
- "1": Perform the normal PVR initialization. (default)

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
