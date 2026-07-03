# SDL_AUDIO_MASK_BIG_ENDIAN

Mask of bits in an [SDL_AudioFormat](SDL_AudioFormat.html) that contain
the bigendian flag.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_MASK_BIG_ENDIAN    (1u<<12)
```

</div>

## Remarks

Generally one should use
[SDL_AUDIO_ISBIGENDIAN](SDL_AUDIO_ISBIGENDIAN.html) or
[SDL_AUDIO_ISLITTLEENDIAN](SDL_AUDIO_ISLITTLEENDIAN.html) instead of
this macro directly.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
