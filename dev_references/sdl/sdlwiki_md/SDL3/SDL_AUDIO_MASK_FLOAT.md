# SDL_AUDIO_MASK_FLOAT

Mask of bits in an [SDL_AudioFormat](SDL_AudioFormat.html) that contain
the floating point flag.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_MASK_FLOAT         (1u<<8)
```

</div>

## Remarks

Generally one should use [SDL_AUDIO_ISFLOAT](SDL_AUDIO_ISFLOAT.html)
instead of this macro directly.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
