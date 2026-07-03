# SDL_IsAudioDevicePlayback

Determine if an audio device is a playback device (instead of
recording).

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_IsAudioDevicePlayback(SDL_AudioDeviceID devid);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioDeviceID](SDL_AudioDeviceID.html) | **devid** | the device ID to query. |

## Return Value

(bool) Returns true if devid is a playback device, false if it is
recording.

## Remarks

This function may return either true or false for invalid device IDs.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
