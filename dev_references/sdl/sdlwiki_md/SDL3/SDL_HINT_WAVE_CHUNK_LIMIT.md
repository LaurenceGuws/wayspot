# SDL_HINT_WAVE_CHUNK_LIMIT

A variable controlling the maximum number of chunks in a WAVE file.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_WAVE_CHUNK_LIMIT "SDL_WAVE_CHUNK_LIMIT"
```

</div>

## Remarks

This sets an upper bound on the number of chunks in a WAVE file to avoid
wasting time on malformed or corrupt WAVE files. This defaults to
"10000".

This hint should be set before calling [SDL_LoadWAV](SDL_LoadWAV.html)()
or [SDL_LoadWAV_IO](SDL_LoadWAV_IO.html)()

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
