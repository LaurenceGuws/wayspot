###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_LoadAudio

Load audio for playback from a file.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
MIX_Audio * MIX_LoadAudio(MIX_Mixer *mixer, const char *path, bool predecode);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [MIX_Mixer](MIX_Mixer.html) \* | **mixer** | a mixer this audio is intended to be used with. May be NULL. |
| const char \* | **path** | the path on the filesystem to load data from. |
| bool | **predecode** | if true, data will be fully uncompressed before returning. |

## Return Value

([MIX_Audio](MIX_Audio.html) \*) Returns an audio object that can be
used to make sound on a mixer, or NULL on failure; call SDL_GetError()
for more information.

## Remarks

This is equivalent to calling:

<div id="cb2" class="sourceCode">

``` sourceCode
MIX_LoadAudio_IO(mixer, SDL_IOFromFile(path, "rb"), predecode, true);
```

</div>

This function loads data from a path on the filesystem. There is also a
version that loads from an SDL_IOStream
([MIX_LoadAudio_IO](MIX_LoadAudio_IO.html)()), and one that accepts
properties for ultimate control
([MIX_LoadAudioWithProperties](MIX_LoadAudioWithProperties.html)()).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_DestroyAudio](MIX_DestroyAudio.html)
- [MIX_SetTrackAudio](MIX_SetTrackAudio.html)
- [MIX_LoadAudio_IO](MIX_LoadAudio_IO.html)
- [MIX_LoadAudioWithProperties](MIX_LoadAudioWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
