# CategoryAudio

Audio functionality for the SDL library.

All audio in SDL3 revolves around
[SDL_AudioStream](SDL_AudioStream.html). Whether you want to play or
record audio, convert it, stream it, buffer it, or mix it, you're going
to be passing it through an audio stream.

Audio streams are quite flexible; they can accept any amount of data at
a time, in any supported format, and output it as needed in any other
format, even if the data format changes on either side halfway through.

An app opens an audio device and binds any number of audio streams to
it, feeding more data to the streams as available. When the device needs
more data, it will pull it from all bound streams and mix them together
for playback.

Audio streams can also use an app-provided callback to supply data
on-demand, which maps pretty closely to the SDL2 audio model.

SDL also provides a simple .WAV loader in
[SDL_LoadWAV](SDL_LoadWAV.html) (and
[SDL_LoadWAV_IO](SDL_LoadWAV_IO.html) if you aren't reading from a file)
as a basic means to load sound data into your program.

## Logical audio devices

In SDL3, opening a physical device (like a SoundBlaster 16 Pro) gives
you a logical device ID that you can bind audio streams to. In almost
all cases, logical devices can be used anywhere in the API that a
physical device is normally used. However, since each device opening
generates a new logical device, different parts of the program (say, a
VoIP library, or text-to-speech framework, or maybe some other sort of
mixer on top of SDL) can have their own device opens that do not
interfere with each other; each logical device will mix its separate
audio down to a single buffer, fed to the physical device, behind the
scenes. As many logical devices as you like can come and go; SDL will
only have to open the physical device at the OS level once, and will
manage all the logical devices on top of it internally.

One other benefit of logical devices: if you don't open a specific
physical device, instead opting for the default, SDL can automatically
migrate those logical devices to different hardware as circumstances
change: a user plugged in headphones? The system default changed? SDL
can transparently migrate the logical devices to the correct physical
device seamlessly and keep playing; the app doesn't even have to know it
happened if it doesn't want to.

## Simplified audio

As a simplified model for when a single source of audio is all that's
needed, an app can use
[SDL_OpenAudioDeviceStream](SDL_OpenAudioDeviceStream.html), which is a
single function to open an audio device, create an audio stream, bind
that stream to the newly-opened device, and (optionally) provide a
callback for obtaining audio data. When using this function, the primary
interface is the [SDL_AudioStream](SDL_AudioStream.html) and the device
handle is mostly hidden away; destroying a stream created through this
function will also close the device, stream bindings cannot be changed,
etc. One other quirk of this is that the device is started in a *paused*
state and must be explicitly resumed; this is partially to offer a clean
migration for SDL2 apps and partially because the app might have to do
more setup before playback begins; in the non-simplified form, nothing
will play until a stream is bound to a device, so they start *unpaused*.

## Channel layouts

Audio data passing through SDL is uncompressed PCM data, interleaved.
One can provide their own decompression through an MP3, etc, decoder,
but SDL does not provide this directly. Each interleaved channel of data
is meant to be in a specific order.

Abbreviations:

- FRONT = single mono speaker
- FL = front left speaker
- FR = front right speaker
- FC = front center speaker
- BL = back left speaker
- BR = back right speaker
- SR = surround right speaker
- SL = surround left speaker
- BC = back center speaker
- LFE = low-frequency speaker

These are listed in the order they are laid out in memory, so "FL, FR"
means "the front left speaker is laid out in memory first, then the
front right, then it repeats for the next audio frame".

- 1 channel (mono) layout: FRONT
- 2 channels (stereo) layout: FL, FR
- 3 channels (2.1) layout: FL, FR, LFE
- 4 channels (quad) layout: FL, FR, BL, BR
- 5 channels (4.1) layout: FL, FR, LFE, BL, BR
- 6 channels (5.1) layout: FL, FR, FC, LFE, BL, BR (last two can also be
  SL, SR)
- 7 channels (6.1) layout: FL, FR, FC, LFE, BC, SL, SR
- 8 channels (7.1) layout: FL, FR, FC, LFE, BL, BR, SL, SR

This is the same order as DirectSound expects, but applied to all
platforms; SDL will swizzle the channels as necessary if a platform
expects something different.

[SDL_AudioStream](SDL_AudioStream.html) can also be provided channel
maps to change this ordering to whatever is necessary, in other audio
processing scenarios.

## Functions

- [SDL_AudioDevicePaused](SDL_AudioDevicePaused.html)
- [SDL_AudioStreamDevicePaused](SDL_AudioStreamDevicePaused.html)
- [SDL_BindAudioStream](SDL_BindAudioStream.html)
- [SDL_BindAudioStreams](SDL_BindAudioStreams.html)
- [SDL_ClearAudioStream](SDL_ClearAudioStream.html)
- [SDL_CloseAudioDevice](SDL_CloseAudioDevice.html)
- [SDL_ConvertAudioSamples](SDL_ConvertAudioSamples.html)
- [SDL_CreateAudioStream](SDL_CreateAudioStream.html)
- [SDL_DestroyAudioStream](SDL_DestroyAudioStream.html)
- [SDL_FlushAudioStream](SDL_FlushAudioStream.html)
- [SDL_GetAudioDeviceChannelMap](SDL_GetAudioDeviceChannelMap.html)
- [SDL_GetAudioDeviceFormat](SDL_GetAudioDeviceFormat.html)
- [SDL_GetAudioDeviceGain](SDL_GetAudioDeviceGain.html)
- [SDL_GetAudioDeviceName](SDL_GetAudioDeviceName.html)
- [SDL_GetAudioDriver](SDL_GetAudioDriver.html)
- [SDL_GetAudioFormatName](SDL_GetAudioFormatName.html)
- [SDL_GetAudioPlaybackDevices](SDL_GetAudioPlaybackDevices.html)
- [SDL_GetAudioRecordingDevices](SDL_GetAudioRecordingDevices.html)
- [SDL_GetAudioStreamAvailable](SDL_GetAudioStreamAvailable.html)
- [SDL_GetAudioStreamData](SDL_GetAudioStreamData.html)
- [SDL_GetAudioStreamDevice](SDL_GetAudioStreamDevice.html)
- [SDL_GetAudioStreamFormat](SDL_GetAudioStreamFormat.html)
- [SDL_GetAudioStreamFrequencyRatio](SDL_GetAudioStreamFrequencyRatio.html)
- [SDL_GetAudioStreamGain](SDL_GetAudioStreamGain.html)
- [SDL_GetAudioStreamInputChannelMap](SDL_GetAudioStreamInputChannelMap.html)
- [SDL_GetAudioStreamOutputChannelMap](SDL_GetAudioStreamOutputChannelMap.html)
- [SDL_GetAudioStreamProperties](SDL_GetAudioStreamProperties.html)
- [SDL_GetAudioStreamQueued](SDL_GetAudioStreamQueued.html)
- [SDL_GetCurrentAudioDriver](SDL_GetCurrentAudioDriver.html)
- [SDL_GetNumAudioDrivers](SDL_GetNumAudioDrivers.html)
- [SDL_GetSilenceValueForFormat](SDL_GetSilenceValueForFormat.html)
- [SDL_IsAudioDevicePhysical](SDL_IsAudioDevicePhysical.html)
- [SDL_IsAudioDevicePlayback](SDL_IsAudioDevicePlayback.html)
- [SDL_LoadWAV](SDL_LoadWAV.html)
- [SDL_LoadWAV_IO](SDL_LoadWAV_IO.html)
- [SDL_LockAudioStream](SDL_LockAudioStream.html)
- [SDL_MixAudio](SDL_MixAudio.html)
- [SDL_OpenAudioDevice](SDL_OpenAudioDevice.html)
- [SDL_OpenAudioDeviceStream](SDL_OpenAudioDeviceStream.html)
- [SDL_PauseAudioDevice](SDL_PauseAudioDevice.html)
- [SDL_PauseAudioStreamDevice](SDL_PauseAudioStreamDevice.html)
- [SDL_PutAudioStreamData](SDL_PutAudioStreamData.html)
- [SDL_PutAudioStreamDataNoCopy](SDL_PutAudioStreamDataNoCopy.html)
- [SDL_PutAudioStreamPlanarData](SDL_PutAudioStreamPlanarData.html)
- [SDL_ResumeAudioDevice](SDL_ResumeAudioDevice.html)
- [SDL_ResumeAudioStreamDevice](SDL_ResumeAudioStreamDevice.html)
- [SDL_SetAudioDeviceGain](SDL_SetAudioDeviceGain.html)
- [SDL_SetAudioPostmixCallback](SDL_SetAudioPostmixCallback.html)
- [SDL_SetAudioStreamFormat](SDL_SetAudioStreamFormat.html)
- [SDL_SetAudioStreamFrequencyRatio](SDL_SetAudioStreamFrequencyRatio.html)
- [SDL_SetAudioStreamGain](SDL_SetAudioStreamGain.html)
- [SDL_SetAudioStreamGetCallback](SDL_SetAudioStreamGetCallback.html)
- [SDL_SetAudioStreamInputChannelMap](SDL_SetAudioStreamInputChannelMap.html)
- [SDL_SetAudioStreamOutputChannelMap](SDL_SetAudioStreamOutputChannelMap.html)
- [SDL_SetAudioStreamPutCallback](SDL_SetAudioStreamPutCallback.html)
- [SDL_UnbindAudioStream](SDL_UnbindAudioStream.html)
- [SDL_UnbindAudioStreams](SDL_UnbindAudioStreams.html)
- [SDL_UnlockAudioStream](SDL_UnlockAudioStream.html)

## Datatypes

- [SDL_AudioDeviceID](SDL_AudioDeviceID.html)
- [SDL_AudioPostmixCallback](SDL_AudioPostmixCallback.html)
- [SDL_AudioStream](SDL_AudioStream.html)
- [SDL_AudioStreamCallback](SDL_AudioStreamCallback.html)
- [SDL_AudioStreamDataCompleteCallback](SDL_AudioStreamDataCompleteCallback.html)

## Structs

- [SDL_AudioSpec](SDL_AudioSpec.html)

## Enums

- [SDL_AudioFormat](SDL_AudioFormat.html)

## Macros

- [SDL_AUDIO_BITSIZE](SDL_AUDIO_BITSIZE.html)
- [SDL_AUDIO_BYTESIZE](SDL_AUDIO_BYTESIZE.html)
- [SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK](SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK.html)
- [SDL_AUDIO_DEVICE_DEFAULT_RECORDING](SDL_AUDIO_DEVICE_DEFAULT_RECORDING.html)
- [SDL_AUDIO_FRAMESIZE](SDL_AUDIO_FRAMESIZE.html)
- [SDL_AUDIO_ISBIGENDIAN](SDL_AUDIO_ISBIGENDIAN.html)
- [SDL_AUDIO_ISFLOAT](SDL_AUDIO_ISFLOAT.html)
- [SDL_AUDIO_ISINT](SDL_AUDIO_ISINT.html)
- [SDL_AUDIO_ISLITTLEENDIAN](SDL_AUDIO_ISLITTLEENDIAN.html)
- [SDL_AUDIO_ISSIGNED](SDL_AUDIO_ISSIGNED.html)
- [SDL_AUDIO_ISUNSIGNED](SDL_AUDIO_ISUNSIGNED.html)
- [SDL_AUDIO_MASK_BIG_ENDIAN](SDL_AUDIO_MASK_BIG_ENDIAN.html)
- [SDL_AUDIO_MASK_BITSIZE](SDL_AUDIO_MASK_BITSIZE.html)
- [SDL_AUDIO_MASK_FLOAT](SDL_AUDIO_MASK_FLOAT.html)
- [SDL_AUDIO_MASK_SIGNED](SDL_AUDIO_MASK_SIGNED.html)
- [SDL_DEFINE_AUDIO_FORMAT](SDL_DEFINE_AUDIO_FORMAT.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
