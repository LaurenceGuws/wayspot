# SDL_OpenAudioDeviceStream

Convenience function for straightforward audio init for the common case.

## Header File

Defined in
[\<SDL3/SDL_audio.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_audio.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_AudioStream * SDL_OpenAudioDeviceStream(SDL_AudioDeviceID devid, const SDL_AudioSpec *spec, SDL_AudioStreamCallback callback, void *userdata);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_AudioDeviceID](SDL_AudioDeviceID.html) | **devid** | an audio device to open, or [SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK](SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK.html) or [SDL_AUDIO_DEVICE_DEFAULT_RECORDING](SDL_AUDIO_DEVICE_DEFAULT_RECORDING.html). |
| const [SDL_AudioSpec](SDL_AudioSpec.html) \* | **spec** | the audio stream's data format. Can be NULL. |
| [SDL_AudioStreamCallback](SDL_AudioStreamCallback.html) | **callback** | a callback where the app will provide new data for playback, or receive new data for recording. Can be NULL, in which case the app will need to call [SDL_PutAudioStreamData](SDL_PutAudioStreamData.html) or [SDL_GetAudioStreamData](SDL_GetAudioStreamData.html) as necessary. |
| void \* | **userdata** | app-controlled pointer passed to callback. Can be NULL. Ignored if callback is NULL. |

## Return Value

([SDL_AudioStream](SDL_AudioStream.html) \*) Returns an audio stream on
success, ready to use, or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. When done with
this stream, call [SDL_DestroyAudioStream](SDL_DestroyAudioStream.html)
to free resources and close the device.

## Remarks

If all your app intends to do is provide a single source of PCM audio,
this function allows you to do all your audio setup in a single call.

This is also intended to be a clean means to migrate apps from SDL2.

This function will open an audio device, create a stream and bind it.
Unlike other methods of setup, the audio device will be closed when this
stream is destroyed, so the app can treat the returned
[SDL_AudioStream](SDL_AudioStream.html) as the only object needed to
manage audio playback.

Also unlike other functions, the audio device begins paused. This is to
map more closely to SDL2-style behavior, since there is no extra step
here to bind a stream to begin audio flowing. The audio device should be
resumed with
[SDL_ResumeAudioStreamDevice](SDL_ResumeAudioStreamDevice.html)().

This function works with both playback and recording devices.

The `spec` parameter represents the app's side of the audio stream. That
is, for recording audio, this will be the output format, and for playing
audio, this will be the input format. If spec is NULL, the system will
choose the format, and the app can use
[SDL_GetAudioStreamFormat](SDL_GetAudioStreamFormat.html)() to obtain
this information later.

If you don't care about opening a specific audio device, you can (and
probably *should*), use
[SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK](SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK.html)
for playback and
[SDL_AUDIO_DEVICE_DEFAULT_RECORDING](SDL_AUDIO_DEVICE_DEFAULT_RECORDING.html)
for recording.

One can optionally provide a callback function; if NULL, the app is
expected to queue audio data for playback (or unqueue audio data if
capturing). Otherwise, the callback will begin to fire once the device
is unpaused.

Destroying the returned stream with
[SDL_DestroyAudioStream](SDL_DestroyAudioStream.html) will also close
the audio device associated with this stream.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAudioStreamDevice](SDL_GetAudioStreamDevice.html)
- [SDL_ResumeAudioStreamDevice](SDL_ResumeAudioStreamDevice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAudio](CategoryAudio.html)
