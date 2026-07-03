# SDL_CloseAudioDevice

Close a previously-opened audio device.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_CloseAudioDevice(SDL_AudioDeviceID devid);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioDeviceID](SDL_AudioDeviceID.html) | **devid** | an audio device id previously returned by [SDL_OpenAudioDevice](SDL_OpenAudioDevice.html)(). |

## Remarks

The application should close open audio devices once they are no longer
needed.

This function may block briefly while pending audio data is played by
the hardware, so that applications don't drop the last buffer of data
they supplied if terminating immediately afterwards.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## Code Examples

<div id="cb2" class="sourceCode">

``` sourceCode
extern SDL_AudioSpec want;
SDL_AudioDeviceID devid = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &want);
if (devid != 0) {
    SDL_ResumeAudioDevice(devid);
    SDL_Delay(5000);  // let device play for 5 seconds
    SDL_CloseAudioDevice(devid);
}
```

</div>

## See Also

- [SDL_OpenAudioDevice](SDL_OpenAudioDevice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
