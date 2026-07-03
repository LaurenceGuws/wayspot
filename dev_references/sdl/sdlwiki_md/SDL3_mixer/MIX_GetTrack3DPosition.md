###### (This function is part of SDL_mixer, a separate library from SDL.)

# MIX_GetTrack3DPosition

Get a track's current position in 3D space.

## Header File

Defined in
[\<SDL3_mixer/SDL_mixer.h\>](https://github.com/libsdl-org/SDL_mixer/blob/main/include/SDL3_mixer/SDL_mixer.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool MIX_GetTrack3DPosition(MIX_Track *track, MIX_Point3D *position);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [MIX_Track](MIX_Track.html) \* | **track** | the track to query. |
| [MIX_Point3D](MIX_Point3D.html) \* | **position** | on successful return, will contain the track's position. |

## Return Value

(bool) Returns true on success or false on failure; call SDL_GetError()
for more information.

## Remarks

If 3D positioning isn't enabled for this track, through a call to
[MIX_SetTrack3DPosition](MIX_SetTrack3DPosition.html)(), this will
return (0,0,0).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_mixer 3.0.0.

## See Also

- [MIX_SetTrack3DPosition](MIX_SetTrack3DPosition.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLMixer](CategorySDLMixer.html)
