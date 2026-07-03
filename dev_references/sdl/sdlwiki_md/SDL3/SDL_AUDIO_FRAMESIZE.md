# SDL_AUDIO_FRAMESIZE

Calculate the size of each audio frame (in bytes) from an
[SDL_AudioSpec](SDL_AudioSpec.html).

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_FRAMESIZE(x) (SDL_AUDIO_BYTESIZE((x).format) * (x).channels)
```

</div>

## Macro Parameters

|       |                                                  |
|-------|--------------------------------------------------|
| **x** | an [SDL_AudioSpec](SDL_AudioSpec.html) to query. |

## Return Value

Returns the number of bytes used per sample frame.

## Remarks

This reports on the size of an audio sample frame: stereo
[Sint16](Sint16.html) data (2 channels of 2 bytes each) would be 4 bytes
per frame, for example.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
