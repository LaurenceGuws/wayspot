###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_CreateMixer

Create a mixer that generates audio to a memory buffer.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
MIX_Mixer * MIX_CreateMixer(const SDL_AudioSpec *spec);
```

</div>

## Function Parameters

|                        |          |                                            |
|------------------------|----------|--------------------------------------------|
| const SDL_AudioSpec \* | **spec** | the audio format that mixer will generate. |

## Return Value

([MIX_Mixer](MIX_Mixer.html) \*) Returns a mixer that can be used to
generate audio, or NULL on failure; call SDL_GetError() for more
information.

## Remarks

Usually you want [MIX_CreateMixerDevice](MIX_CreateMixerDevice.html)()
instead of this function. The mixer created here can be used with
[MIX_Generate](MIX_Generate.html)() to produce more data on demand, as
fast as desired.

An audio format must be specified. This is the format it will output in.
This cannot be NULL.

Once a mixer is created, next steps are usually to load audio (through
[MIX_LoadAudio](MIX_LoadAudio.html)() and friends), create a track
([MIX_CreateTrack](MIX_CreateTrack.html)()), and play that audio through
that track.

When done with the mixer, it can be destroyed with
[MIX_DestroyMixer](MIX_DestroyMixer.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_CreateMixerDevice](MIX_CreateMixerDevice.html)
- [MIX_DestroyMixer](MIX_DestroyMixer.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
