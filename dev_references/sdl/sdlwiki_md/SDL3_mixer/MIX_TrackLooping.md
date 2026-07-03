###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_TrackLooping

Query whether a given track is looping.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool MIX_TrackLooping(MIX_Track *track);
```

</div>

## Function Parameters

|                                |           |                     |
|--------------------------------|-----------|---------------------|
| [MIX_Track](MIX_Track.html) \* | **track** | the track to query. |

## Return Value

(bool) Returns true if looping, false otherwise.

## Remarks

This specifically checks if the track is *not stopped* (paused or
playing), and there is at least one loop remaining. If a track *was*
looping but is on its final iteration of the loop, this will return
false.

On various errors ([MIX_Init](MIX_Init.html)() was not called, the track
is NULL), this returns false, but there is no mechanism to distinguish
errors from non-looping tracks.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
