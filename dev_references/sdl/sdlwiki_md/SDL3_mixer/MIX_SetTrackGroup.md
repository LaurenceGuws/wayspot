###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_SetTrackGroup

Assign a track to a mixing group.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool MIX_SetTrackGroup(MIX_Track *track, MIX_Group *group);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [MIX_Track](MIX_Track.html) \* | **track** | the track to set mixing group assignment. |
| [MIX_Group](MIX_Group.html) \* | **group** | the new mixing group to assign to. May be NULL. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

All tracks in a group are mixed together, and that output is made
available to the app before it is mixed into the final output.

Tracks can only be in one group at a time, and the track and group must
have been created on the same [MIX_Mixer](MIX_Mixer.html).

Setting a track to a NULL group will remove it from any app-created
groups, and reassign it to the mixer's internal default group.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_CreateGroup](MIX_CreateGroup.html)
- [MIX_SetGroupPostMixCallback](MIX_SetGroupPostMixCallback.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
