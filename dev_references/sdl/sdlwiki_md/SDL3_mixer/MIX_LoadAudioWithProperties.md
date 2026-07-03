###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_LoadAudioWithProperties

Load audio for playback through a collection of properties.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
MIX_Audio * MIX_LoadAudioWithProperties(SDL_PropertiesID props);
```

</div>

## Function Parameters

|                  |           |                                           |
|------------------|-----------|-------------------------------------------|
| SDL_PropertiesID | **props** | a set of properties on how to load audio. |

## Return Value

([MIX_Audio](MIX_Audio.html) \*) Returns an audio object that can be
used to make sound on a mixer, or NULL on failure; call SDL_GetError()
for more information.

## Remarks

Please see [MIX_LoadAudio_IO](MIX_LoadAudio_IO.html)() for a description
of what the various LoadAudio functions do. This function uses
properties to dictate how it operates, and exposes functionality the
other functions don't provide.

SDL_PropertiesID are discussed in [SDL's
documentation](../SDL3/CategoryProperties.html) .

These are the supported properties:

- [`MIX_PROP_AUDIO_LOAD_IOSTREAM_POINTER`](MIX_PROP_AUDIO_LOAD_IOSTREAM_POINTER.html):
  a pointer to an SDL_IOStream to be used to load audio data. Required.
  This stream must be able to seek!
- [`MIX_PROP_AUDIO_LOAD_CLOSEIO_BOOLEAN`](MIX_PROP_AUDIO_LOAD_CLOSEIO_BOOLEAN.html):
  true if SDL_mixer should close the SDL_IOStream before returning
  (success or failure).
- [`MIX_PROP_AUDIO_LOAD_PREDECODE_BOOLEAN`](MIX_PROP_AUDIO_LOAD_PREDECODE_BOOLEAN.html):
  true if SDL_mixer should fully decode and decompress the data before
  returning. Otherwise it will be stored in its original state and
  decompressed on demand.
- [`MIX_PROP_AUDIO_LOAD_PREFERRED_MIXER_POINTER`](MIX_PROP_AUDIO_LOAD_PREFERRED_MIXER_POINTER.html):
  a pointer to a [MIX_Mixer](MIX_Mixer.html), in case steps can be made
  to match its format when decoding. Optional.
- [`MIX_PROP_AUDIO_LOAD_SKIP_METADATA_TAGS_BOOLEAN`](MIX_PROP_AUDIO_LOAD_SKIP_METADATA_TAGS_BOOLEAN.html):
  true to skip parsing metadata tags, like ID3 and APE tags. This can be
  used to speed up loading *if the data definitely doesn't have these
  tags*. Some decoders will fail if these tags are present when this
  property is true.
- [`MIX_PROP_AUDIO_DECODER_STRING`](MIX_PROP_AUDIO_DECODER_STRING.html):
  the name of the decoder to use for this data. Optional. If not
  specified, SDL_mixer will examine the data and choose the best
  decoder. These names are the same returned from
  [MIX_GetAudioDecoder](MIX_GetAudioDecoder.html)().

Specific decoders might accept additional custom properties, such as
where to find soundfonts for MIDI playback, etc.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_DestroyAudio](MIX_DestroyAudio.html)
- [MIX_SetTrackAudio](MIX_SetTrackAudio.html)
- [MIX_LoadAudio](MIX_LoadAudio.html)
- [MIX_LoadAudio_IO](MIX_LoadAudio_IO.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
