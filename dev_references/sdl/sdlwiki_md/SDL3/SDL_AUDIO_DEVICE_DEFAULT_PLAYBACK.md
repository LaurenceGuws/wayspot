# SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK

A value used to request a default playback audio device.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK ((SDL_AudioDeviceID) 0xFFFFFFFFu)
```

</div>

## Remarks

Several functions that require an
[SDL_AudioDeviceID](SDL_AudioDeviceID.html) will accept this value to
signify the app just wants the system to choose a default device instead
of the app providing a specific one.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryAudio](CategoryAudio.html)
