# SDL_PlayHapticRumble

Run a simple rumble effect on a haptic device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_PlayHapticRumble(SDL_Haptic *haptic, float strength, Uint32 length);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the haptic device to play the rumble effect on. |
| float | **strength** | strength of the rumble to play as a 0-1 float value. |
| [Uint32](Uint32.html) | **length** | length of the rumble to play in milliseconds. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_InitHapticRumble](SDL_InitHapticRumble.html)
- [SDL_StopHapticRumble](SDL_StopHapticRumble.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
