###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_GetGroupMixer

Get the [MIX_Mixer](MIX_Mixer.html) that owns a
[MIX_Group](MIX_Group.html).

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
MIX_Mixer * MIX_GetGroupMixer(MIX_Group *group);
```

</div>

## Function Parameters

|                                |           |                     |
|--------------------------------|-----------|---------------------|
| [MIX_Group](MIX_Group.html) \* | **group** | the group to query. |

## Return Value

([MIX_Mixer](MIX_Mixer.html) \*) Returns the mixer associated with the
group, or NULL on error; call SDL_GetError() for more information.

## Remarks

This is the mixer pointer that was passed to
[MIX_CreateGroup](MIX_CreateGroup.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
