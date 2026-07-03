###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_GetTrackAudio

Query the [MIX_Audio](MIX_Audio.html) assigned to a track.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
MIX_Audio * MIX_GetTrackAudio(MIX_Track *track);
```

</div>

## Function Parameters

|                                |           |                     |
|--------------------------------|-----------|---------------------|
| [MIX_Track](MIX_Track.html) \* | **track** | the track to query. |

## Return Value

([MIX_Audio](MIX_Audio.html) \*) Returns a [MIX_Audio](MIX_Audio.html)
if available, NULL if not.

## Remarks

This returns the [MIX_Audio](MIX_Audio.html) object currently assigned
to `track` through a call to
[MIX_SetTrackAudio](MIX_SetTrackAudio.html)(). If there is none
assigned, or the track has an input that isn't a
[MIX_Audio](MIX_Audio.html) (such as an SDL_AudioStream or
SDL_IOStream), this will return NULL.

On various errors ([MIX_Init](MIX_Init.html)() was not called, the track
is NULL), this returns NULL, but there is no mechanism to distinguish
errors from tracks without a valid input.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_GetTrackAudioStream](MIX_GetTrackAudioStream.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
