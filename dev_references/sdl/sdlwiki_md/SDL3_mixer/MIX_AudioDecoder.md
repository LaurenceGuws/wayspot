###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_AudioDecoder

An opaque object that represents an audio decoder.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct MIX_AudioDecoder MIX_AudioDecoder;
```

</div>

## Remarks

Most apps won't need this, as SDL_mixer's usual interfaces will decode
audio as needed. However, if one wants to decode an audio file into a
memory buffer without playing it, this interface offers that.

These objects are created with
[MIX_CreateAudioDecoder](MIX_CreateAudioDecoder.html)() or
[MIX_CreateAudioDecoder_IO](MIX_CreateAudioDecoder_IO.html)(), and then
can use [MIX_DecodeAudio](MIX_DecodeAudio.html)() to retrieve the raw
PCM data.

## Version

This struct is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySDLMixer](CategorySDLMixer.html)
