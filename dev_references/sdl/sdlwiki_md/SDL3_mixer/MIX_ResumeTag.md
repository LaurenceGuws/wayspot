###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_ResumeTag

Resume all tracks with a specific tag.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool MIX_ResumeTag(MIX_Mixer *mixer, const char *tag);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [MIX_Mixer](MIX_Mixer.html) \* | **mixer** | the mixer on which to resume tracks. |
| const char \* | **tag** | the tag to use when searching for tracks. |

## Return Value

(bool) Returns true on success, false on error; call SDL_GetError() for
details.

## Remarks

A paused track is not considered "stopped," so its
[MIX_TrackStoppedCallback](MIX_TrackStoppedCallback.html) will not fire
if paused, but it won't change state by default, generate audio, or
generally make progress, until it is resumed.

This function makes all currently-paused tracks on the specified mixer,
with a specific tag, move to a playing state.

Tracks that match the specified tag that aren't currently paused are
ignored.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_ResumeTrack](MIX_ResumeTrack.html)
- [MIX_PauseTrack](MIX_PauseTrack.html)
- [MIX_PauseTag](MIX_PauseTag.html)
- [MIX_TagTrack](MIX_TagTrack.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
