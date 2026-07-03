###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_DestroyAudio

Destroy the specified audio.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void MIX_DestroyAudio(MIX_Audio *audio);
```

</div>

## Function Parameters

|                                |           |                       |
|--------------------------------|-----------|-----------------------|
| [MIX_Audio](MIX_Audio.html) \* | **audio** | the audio to destroy. |

## Remarks

[MIX_Audio](MIX_Audio.html) is reference-counted internally, so this
function only unrefs it. If doing so causes the reference count to drop
to zero, the [MIX_Audio](MIX_Audio.html) will be deallocated. This
allows the system to safely operate if the audio is still assigned to a
[MIX_Track](MIX_Track.html) at the time of destruction. The actual
destroying will happen when the track stops using it.

But from the caller's perspective, once this function is called, it
should assume the `audio` pointer has become invalid.

Destroying a NULL [MIX_Audio](MIX_Audio.html) is a legal no-op.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
