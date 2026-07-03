# SDL_AUDIO_ISSIGNED

Determine if an [SDL_AudioFormat](SDL_AudioFormat.html) represents
signed data.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_ISSIGNED(x)        ((x) & SDL_AUDIO_MASK_SIGNED)
```

</div>

## Macro Parameters

|       |                                                   |
|-------|---------------------------------------------------|
| **x** | an [SDL_AudioFormat](SDL_AudioFormat.html) value. |

## Return Value

Returns non-zero if format is signed, zero otherwise.

## Remarks

For example, `SDL_AUDIO_ISSIGNED(SDL_AUDIO_U8)` returns 0.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
