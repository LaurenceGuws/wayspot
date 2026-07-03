###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_TrackPaused

Query if a track is currently paused.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool MIX_TrackPaused(MIX_Track *track);
```

</div>

## Function Parameters

|                                |           |                     |
|--------------------------------|-----------|---------------------|
| [MIX_Track](MIX_Track.html) \* | **track** | the track to query. |

## Return Value

(bool) Returns true if paused, false otherwise.

## Remarks

If this returns true, the track is not currently contributing to the
mixer's output but will when resumed (it's "paused"). It is not playing
nor stopped.

On various errors ([MIX_Init](MIX_Init.html)() was not called, the track
is NULL), this returns false, but there is no mechanism to distinguish
errors from non-playing tracks.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_PlayTrack](MIX_PlayTrack.html)
- [MIX_PauseTrack](MIX_PauseTrack.html)
- [MIX_ResumeTrack](MIX_ResumeTrack.html)
- [MIX_StopTrack](MIX_StopTrack.html)
- [MIX_TrackPlaying](MIX_TrackPlaying.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
