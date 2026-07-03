# SDL_AUDIO_BITSIZE

Retrieve the size, in bits, from an
[SDL_AudioFormat](SDL_AudioFormat.html).

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_BITSIZE(x)         ((x) & SDL_AUDIO_MASK_BITSIZE)
```

</div>

## Macro Parameters

|       |                                                   |
|-------|---------------------------------------------------|
| **x** | an [SDL_AudioFormat](SDL_AudioFormat.html) value. |

## Return Value

Returns data size in bits.

## Remarks

For example, `SDL_AUDIO_BITSIZE(SDL_AUDIO_S16)` returns 16.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
