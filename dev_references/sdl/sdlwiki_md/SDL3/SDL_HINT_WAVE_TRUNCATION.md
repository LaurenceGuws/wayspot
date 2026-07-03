# SDL_HINT_WAVE_TRUNCATION

A variable controlling how a truncated WAVE file is handled.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_HINT_WAVE_TRUNCATION "SDL_WAVE_TRUNCATION"
```

</div>

## Remarks

A WAVE file is considered truncated if any of the chunks are incomplete
or the data chunk size is not a multiple of the block size. By default,
SDL decodes until the first incomplete block, as most applications seem
to do.

The variable can be set to the following values:

- "verystrict" - Raise an error if the file is truncated.
- "strict" - Like "verystrict", but the size of the RIFF chunk is
  ignored.
- "dropframe" - Decode until the first incomplete sample frame.
- "dropblock" - Decode until the first incomplete block. (default)

This hint should be set before calling [SDL_LoadWAV](SDL_LoadWAV.html)()
or [SDL_LoadWAV_IO](SDL_LoadWAV_IO.html)()

## Version

This hint is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryHints](CategoryHints.html)
