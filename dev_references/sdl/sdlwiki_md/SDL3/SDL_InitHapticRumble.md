# SDL_InitHapticRumble

Initialize a haptic device for simple rumble playback.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_InitHapticRumble(SDL_Haptic *haptic);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the haptic device to initialize for simple rumble playback. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_PlayHapticRumble](SDL_PlayHapticRumble.html)
- [SDL_StopHapticRumble](SDL_StopHapticRumble.html)
- [SDL_HapticRumbleSupported](SDL_HapticRumbleSupported.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
