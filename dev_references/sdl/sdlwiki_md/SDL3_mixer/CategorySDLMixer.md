# CategorySDLMixer

SDL_mixer is a library to make complicated audio processing tasks
easier.

It offers audio file decoding, mixing multiple sounds together, basic 3D
positional audio, and various audio effects.

It can mix sound to multiple audio devices in real time, or generate
mixed audio data to a memory buffer for any other use. It can do both at
the same time!

To use the library, first call [MIX_Init](MIX_Init.html)(). Then create
a mixer with [MIX_CreateMixerDevice](MIX_CreateMixerDevice.html)() (or
[MIX_CreateMixer](MIX_CreateMixer.html)() to render to memory).

Once you have a mixer, you can load sound data with
[MIX_LoadAudio](MIX_LoadAudio.html)(),
[MIX_LoadAudio_IO](MIX_LoadAudio_IO.html)(), or
[MIX_LoadAudioWithProperties](MIX_LoadAudioWithProperties.html)(). Data
gets loaded once and can be played over and over.

When loading audio, SDL_mixer can parse out several metadata tag
formats, such as ID3 and APE tags, and exposes this information through
the [MIX_GetAudioProperties](MIX_GetAudioProperties.html)() function.

To play audio, you create a track with
[MIX_CreateTrack](MIX_CreateTrack.html)(). You need one track for each
sound that will be played simultaneously; think of tracks as individual
sliders on a mixer board. You might have loaded hundreds of audio files,
but you probably only have a handful of tracks that you assign those
loaded files to when they are ready to play, and reuse those tracks with
different audio later. Tracks take their input from a
[MIX_Audio](MIX_Audio.html) (static data to be played multiple times) or
an SDL_AudioStream (streaming PCM audio the app supplies, possibly as
needed). A third option is to supply an SDL_IOStream, to load and decode
on the fly, which might be more efficient for background music that is
only used once, etc.

Assign input to a [MIX_Track](MIX_Track.html) with
[MIX_SetTrackAudio](MIX_SetTrackAudio.html)(),
[MIX_SetTrackAudioStream](MIX_SetTrackAudioStream.html)(), or
[MIX_SetTrackIOStream](MIX_SetTrackIOStream.html)().

Once a track has an input, start it playing with
[MIX_PlayTrack](MIX_PlayTrack.html)(). There are many options to this
function to dictate mixing features: looping, fades, etc.

Tracks can be tagged with arbitrary strings, like "music" or "ingame" or
"ui". These tags can be used to start, stop, and pause a selection of
tracks at the same moment.

All significant portions of the mixing pipeline have callbacks, so that
an app can hook in to the appropriate locations to examine or modify
audio data as it passes through the mixer: a "raw" callback for raw PCM
data decoded from an audio file without any modifications, a "cooked"
callback for that same data after all transformations (fade,
positioning, etc) have been processed, a "stopped" callback for when the
track finishes mixing, a "postmix" callback for the final mixed audio
about to be sent to the audio hardware to play. Additionally, you can
use [MIX_Group](MIX_Group.html) objects to mix a subset of playing
tracks and access the data before it is mixed in with other tracks. All
of this is optional, but allows for powerful access and control of the
mixing process.

SDL_mixer can also be used for decoding audio files without actually
rendering a mix. This is done with
[MIX_AudioDecoder](MIX_AudioDecoder.html). Even though SDL_mixer handles
decoding transparently when used as the audio engine for an app, and
probably won't need this interface in that normal scenario, this can be
useful when using a different audio library to access many file formats.

This library offers several features on top of mixing sounds together: a
track can have its own gain, to adjust its volume, in addition to a
master gain applied as well. One can set the "frequency ratio" of a
track or the final mixed output, to speed it up or slow it down, which
also adjusts its pitch. A channel map can also be applied per-track, to
change what speaker a given channel of audio is output to.

Almost all timing in SDL_mixer is in *sample frames*. Stereo PCM audio
data in Sint16 format takes 4 bytes per sample frame (2 bytes per sample
times 2 channels), for example. This allows everything in SDL_mixer to
run at sample-perfect accuracy, and it lets it run without concern for
wall clock time--you can produce audio faster than real-time, if
desired. The problem, though, is different pieces of audio at different
*sample rates* will produce a different number of sample frames for the
same length of time. To deal with this, conversion routines are offered:
[MIX_TrackMSToFrames](MIX_TrackMSToFrames.html)(),
[MIX_TrackFramesToMS](MIX_TrackFramesToMS.html)(), etc. Functions that
operate on multiple tracks at once will deal with time in milliseconds,
so it can do these conversions internally; be sure to read the
documentation for these small quirks!

SDL_mixer offers basic positional audio: a simple 3D positioning API
through [MIX_SetTrack3DPosition](MIX_SetTrack3DPosition.html)() and
[MIX_SetTrackStereo](MIX_SetTrackStereo.html)(). The former will do
simple distance attenuation and spatialization--on a stereo setup, you
will hear sounds move from left to right--and on a surround-sound
configuration, individual tracks can move around the user. The latter,
[MIX_SetTrackStereo](MIX_SetTrackStereo.html)(), will force a sound to
the Front Left and Front Right speakers and let the app pan it left and
right as desired. Either effect can be useful for different situations.
SDL_mixer is not meant to be a full 3D audio engine, but rather Good
Enough for many purposes; if something more powerful in terms of 3D
audio is needed, consider a proper 3D library like OpenAL.

## Functions

- [MIX_AudioFramesToMS](MIX_AudioFramesToMS.html)
- [MIX_AudioMSToFrames](MIX_AudioMSToFrames.html)
- [MIX_CreateAudioDecoder](MIX_CreateAudioDecoder.html)
- [MIX_CreateAudioDecoder_IO](MIX_CreateAudioDecoder_IO.html)
- [MIX_CreateGroup](MIX_CreateGroup.html)
- [MIX_CreateMixer](MIX_CreateMixer.html)
- [MIX_CreateMixerDevice](MIX_CreateMixerDevice.html)
- [MIX_CreateSineWaveAudio](MIX_CreateSineWaveAudio.html)
- [MIX_CreateTrack](MIX_CreateTrack.html)
- [MIX_DecodeAudio](MIX_DecodeAudio.html)
- [MIX_DestroyAudio](MIX_DestroyAudio.html)
- [MIX_DestroyAudioDecoder](MIX_DestroyAudioDecoder.html)
- [MIX_DestroyGroup](MIX_DestroyGroup.html)
- [MIX_DestroyMixer](MIX_DestroyMixer.html)
- [MIX_DestroyTrack](MIX_DestroyTrack.html)
- [MIX_FramesToMS](MIX_FramesToMS.html)
- [MIX_Generate](MIX_Generate.html)
- [MIX_GetAudioDecoder](MIX_GetAudioDecoder.html)
- [MIX_GetAudioDecoderFormat](MIX_GetAudioDecoderFormat.html)
- [MIX_GetAudioDecoderProperties](MIX_GetAudioDecoderProperties.html)
- [MIX_GetAudioDuration](MIX_GetAudioDuration.html)
- [MIX_GetAudioFormat](MIX_GetAudioFormat.html)
- [MIX_GetAudioProperties](MIX_GetAudioProperties.html)
- [MIX_GetGroupMixer](MIX_GetGroupMixer.html)
- [MIX_GetGroupProperties](MIX_GetGroupProperties.html)
- [MIX_GetMasterFrequencyRatio](MIX_GetMasterFrequencyRatio.html)
- [MIX_GetMasterGain](MIX_GetMasterGain.html)
- [MIX_GetMixerFormat](MIX_GetMixerFormat.html)
- [MIX_GetMixerFrequencyRatio](MIX_GetMixerFrequencyRatio.html)
- [MIX_GetMixerGain](MIX_GetMixerGain.html)
- [MIX_GetMixerProperties](MIX_GetMixerProperties.html)
- [MIX_GetNumAudioDecoders](MIX_GetNumAudioDecoders.html)
- [MIX_GetTaggedTracks](MIX_GetTaggedTracks.html)
- [MIX_GetTrack3DPosition](MIX_GetTrack3DPosition.html)
- [MIX_GetTrackAudio](MIX_GetTrackAudio.html)
- [MIX_GetTrackAudioStream](MIX_GetTrackAudioStream.html)
- [MIX_GetTrackFadeFrames](MIX_GetTrackFadeFrames.html)
- [MIX_GetTrackFrequencyRatio](MIX_GetTrackFrequencyRatio.html)
- [MIX_GetTrackGain](MIX_GetTrackGain.html)
- [MIX_GetTrackLoops](MIX_GetTrackLoops.html)
- [MIX_GetTrackMixer](MIX_GetTrackMixer.html)
- [MIX_GetTrackPlaybackPosition](MIX_GetTrackPlaybackPosition.html)
- [MIX_GetTrackProperties](MIX_GetTrackProperties.html)
- [MIX_GetTrackRemaining](MIX_GetTrackRemaining.html)
- [MIX_GetTrackTags](MIX_GetTrackTags.html)
- [MIX_Init](MIX_Init.html)
- [MIX_LoadAudio](MIX_LoadAudio.html)
- [MIX_LoadAudio_IO](MIX_LoadAudio_IO.html)
- [MIX_LoadAudioWithProperties](MIX_LoadAudioWithProperties.html)
- [MIX_LoadRawAudio](MIX_LoadRawAudio.html)
- [MIX_LoadRawAudio_IO](MIX_LoadRawAudio_IO.html)
- [MIX_LoadRawAudioNoCopy](MIX_LoadRawAudioNoCopy.html)
- [MIX_MSToFrames](MIX_MSToFrames.html)
- [MIX_PauseAllTracks](MIX_PauseAllTracks.html)
- [MIX_PauseTag](MIX_PauseTag.html)
- [MIX_PauseTrack](MIX_PauseTrack.html)
- [MIX_PlayAudio](MIX_PlayAudio.html)
- [MIX_PlayTag](MIX_PlayTag.html)
- [MIX_PlayTrack](MIX_PlayTrack.html)
- [MIX_Quit](MIX_Quit.html)
- [MIX_ResumeAllTracks](MIX_ResumeAllTracks.html)
- [MIX_ResumeTag](MIX_ResumeTag.html)
- [MIX_ResumeTrack](MIX_ResumeTrack.html)
- [MIX_SetGroupPostMixCallback](MIX_SetGroupPostMixCallback.html)
- [MIX_SetMasterFrequencyRatio](MIX_SetMasterFrequencyRatio.html)
- [MIX_SetMasterGain](MIX_SetMasterGain.html)
- [MIX_SetMixerFrequencyRatio](MIX_SetMixerFrequencyRatio.html)
- [MIX_SetMixerGain](MIX_SetMixerGain.html)
- [MIX_SetPostMixCallback](MIX_SetPostMixCallback.html)
- [MIX_SetTagGain](MIX_SetTagGain.html)
- [MIX_SetTrack3DPosition](MIX_SetTrack3DPosition.html)
- [MIX_SetTrackAudio](MIX_SetTrackAudio.html)
- [MIX_SetTrackAudioStream](MIX_SetTrackAudioStream.html)
- [MIX_SetTrackCookedCallback](MIX_SetTrackCookedCallback.html)
- [MIX_SetTrackFrequencyRatio](MIX_SetTrackFrequencyRatio.html)
- [MIX_SetTrackGain](MIX_SetTrackGain.html)
- [MIX_SetTrackGroup](MIX_SetTrackGroup.html)
- [MIX_SetTrackIOStream](MIX_SetTrackIOStream.html)
- [MIX_SetTrackLoops](MIX_SetTrackLoops.html)
- [MIX_SetTrackOutputChannelMap](MIX_SetTrackOutputChannelMap.html)
- [MIX_SetTrackPlaybackPosition](MIX_SetTrackPlaybackPosition.html)
- [MIX_SetTrackRawCallback](MIX_SetTrackRawCallback.html)
- [MIX_SetTrackRawIOStream](MIX_SetTrackRawIOStream.html)
- [MIX_SetTrackStereo](MIX_SetTrackStereo.html)
- [MIX_SetTrackStoppedCallback](MIX_SetTrackStoppedCallback.html)
- [MIX_StopAllTracks](MIX_StopAllTracks.html)
- [MIX_StopTag](MIX_StopTag.html)
- [MIX_StopTrack](MIX_StopTrack.html)
- [MIX_TagTrack](MIX_TagTrack.html)
- [MIX_TrackFramesToMS](MIX_TrackFramesToMS.html)
- [MIX_TrackLooping](MIX_TrackLooping.html)
- [MIX_TrackMSToFrames](MIX_TrackMSToFrames.html)
- [MIX_TrackPaused](MIX_TrackPaused.html)
- [MIX_TrackPlaying](MIX_TrackPlaying.html)
- [MIX_UntagTrack](MIX_UntagTrack.html)
- [MIX_Version](MIX_Version.html)

## Datatypes

- [MIX_Audio](MIX_Audio.html)
- [MIX_AudioDecoder](MIX_AudioDecoder.html)
- [MIX_Group](MIX_Group.html)
- [MIX_GroupMixCallback](MIX_GroupMixCallback.html)
- [MIX_Mixer](MIX_Mixer.html)
- [MIX_PostMixCallback](MIX_PostMixCallback.html)
- [MIX_Track](MIX_Track.html)
- [MIX_TrackMixCallback](MIX_TrackMixCallback.html)
- [MIX_TrackStoppedCallback](MIX_TrackStoppedCallback.html)

## Structs

- [MIX_Point3D](MIX_Point3D.html)
- [MIX_StereoGains](MIX_StereoGains.html)

## Enums

- (none.)

## Macros

- [SDL_MIXER_MAJOR_VERSION](SDL_MIXER_MAJOR_VERSION.html)
- [SDL_MIXER_MICRO_VERSION](SDL_MIXER_MICRO_VERSION.html)
- [SDL_MIXER_MINOR_VERSION](SDL_MIXER_MINOR_VERSION.html)
- [SDL_MIXER_VERSION](SDL_MIXER_VERSION.html)
- [SDL_MIXER_VERSION_ATLEAST](SDL_MIXER_VERSION_ATLEAST.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
