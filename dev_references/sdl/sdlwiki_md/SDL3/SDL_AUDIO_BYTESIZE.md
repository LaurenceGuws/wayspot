# SDL_AUDIO_BYTESIZE

Retrieve the size, in bytes, from an
[SDL_AudioFormat](SDL_AudioFormat.html).

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_BYTESIZE(x)        (SDL_AUDIO_BITSIZE(x) / 8)
```

</div>

## Macro Parameters

|       |                                                   |
|-------|---------------------------------------------------|
| **x** | an [SDL_AudioFormat](SDL_AudioFormat.html) value. |

## Return Value

Returns data size in bytes.

## Remarks

For example, `SDL_AUDIO_BYTESIZE(SDL_AUDIO_S16)` returns 2.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
