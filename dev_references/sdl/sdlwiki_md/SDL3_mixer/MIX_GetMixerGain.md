###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_GetMixerGain

Get a mixer's master gain control.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
float MIX_GetMixerGain(MIX_Mixer *mixer);
```

</div>

## Function Parameters

|                                |           |                     |
|--------------------------------|-----------|---------------------|
| [MIX_Mixer](MIX_Mixer.html) \* | **mixer** | the mixer to query. |

## Return Value

(float) Returns the mixer's current master gain.

## Remarks

This returns the last value set through
[MIX_SetMixerGain](MIX_SetMixerGain.html)(), or 1.0f if no value has
ever been explicitly set.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_SetMixerGain](MIX_SetMixerGain.html)
- [MIX_GetTrackGain](MIX_GetTrackGain.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
