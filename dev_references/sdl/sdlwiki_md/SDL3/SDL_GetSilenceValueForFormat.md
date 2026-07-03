# SDL_GetSilenceValueForFormat

Get the appropriate memset value for silencing an audio format.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_GetSilenceValueForFormat(SDL_AudioFormat format);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioFormat](SDL_AudioFormat.html) | **format** | the audio data format to query. |

## Return Value

(int) Returns a byte value that can be passed to memset.

## Remarks

The value returned by this function can be used as the second argument
to memset (or [SDL_memset](SDL_memset.html)) to set an audio buffer in a
specific format to silence.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
