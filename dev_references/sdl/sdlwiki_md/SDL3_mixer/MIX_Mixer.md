###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_Mixer

An opaque object that represents a mixer.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct MIX_Mixer MIX_Mixer;
```

</div>

## Remarks

The [MIX_Mixer](MIX_Mixer.html) is the toplevel object for this library.
To use SDL_mixer, you must have at least one, but are allowed to have
several. Each mixer is responsible for generating a single output stream
of mixed audio, usually to an audio device for realtime playback.

Mixers are either created to feed an audio device (through
[MIX_CreateMixerDevice](MIX_CreateMixerDevice.html)()), or to generate
audio to a buffer in memory, where it can be used for anything (through
[MIX_CreateMixer](MIX_CreateMixer.html)()).

## Version

This datatype is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySDLMixer](CategorySDLMixer.html)
