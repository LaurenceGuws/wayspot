# SDL_HINT_VITA_RESOLUTION

A variable overriding the resolution reported on the PlayStation Vita.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_VITA_RESOLUTION "SDL_VITA_RESOLUTION"
```

</div>

## Remarks

The variable can be set to the following values:

- "544": 544p (default)
- "720": 725p for PSTV
- "1080": 1088i for PSTV

This hint should be set before SDL is initialized.

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
