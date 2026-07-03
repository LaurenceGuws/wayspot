###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_TrackStoppedCallback

A callback that fires when a [MIX_Track](MIX_Track.html) is stopped.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef void (SDLCALL *MIX_TrackStoppedCallback)(void *userdata, MIX_Track *track);
```

</div>

## Function Parameters

|              |                                                             |
|--------------|-------------------------------------------------------------|
| **userdata** | an opaque pointer provided by the app for its personal use. |
| **track**    | the track that has stopped.                                 |

## Remarks

This callback is fired when a track completes playback, either because
it ran out of data to mix (and all loops were completed as well), or it
was explicitly stopped by the app. Pausing a track will not fire this
callback.

It is legal to adjust the track, including changing its input and
restarting it. If this is done because it ran out of data in the middle
of mixing, the mixer will start mixing the new track state in its
current run without any gap in the audio.

This callback will not fire when a playing track is destroyed.

## Version

This datatype is available since SDL_mixer 3.0.0.

## See Also

- [MIX_SetTrackStoppedCallback](MIX_SetTrackStoppedCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategorySDLMixer](CategorySDLMixer.html)
