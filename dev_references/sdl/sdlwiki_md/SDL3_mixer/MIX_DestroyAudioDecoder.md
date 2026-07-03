###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_DestroyAudioDecoder

Destroy the specified audio decoder.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void MIX_DestroyAudioDecoder(MIX_AudioDecoder *audiodecoder);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [MIX_AudioDecoder](MIX_AudioDecoder.html) \* | **audiodecoder** | the audio to destroy. |

## Remarks

Destroying a NULL [MIX_AudioDecoder](MIX_AudioDecoder.html) is a legal
no-op.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
