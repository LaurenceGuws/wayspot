###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_Audio

An opaque object that represents audio data.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct MIX_Audio MIX_Audio;
```

</div>

## Remarks

Generally you load audio data (in whatever file format) into SDL_mixer
with [MIX_LoadAudio](MIX_LoadAudio.html)() or one of its several
variants, producing a [MIX_Audio](MIX_Audio.html) object.

A [MIX_Audio](MIX_Audio.html) represents static audio data; it could be
background music, or maybe a laser gun sound effect. It is loaded into
RAM and can be played multiple times, possibly on different tracks at
the same time.

Unlike most other objects, [MIX_Audio](MIX_Audio.html) objects can be
shared between mixers.

## Version

This datatype is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySDLMixer](CategorySDLMixer.html)
