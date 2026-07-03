# SDL_AUDIO_ISFLOAT

Determine if an [SDL_AudioFormat](SDL_AudioFormat.html) represents
floating point data.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_ISFLOAT(x)         ((x) & SDL_AUDIO_MASK_FLOAT)
```

</div>

## Macro Parameters

|       |                                                   |
|-------|---------------------------------------------------|
| **x** | an [SDL_AudioFormat](SDL_AudioFormat.html) value. |

## Return Value

Returns non-zero if format is floating point, zero otherwise.

## Remarks

For example, `SDL_AUDIO_ISFLOAT(SDL_AUDIO_S16)` returns 0.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
