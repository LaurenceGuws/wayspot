# SDL_OpenHaptic

Open a haptic device for use.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Haptic * SDL_OpenHaptic(SDL_HapticID instance_id);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_HapticID](SDL_HapticID.html) | **instance_id** | the haptic device instance ID. |

## Return Value

([SDL_Haptic](SDL_Haptic.html) \*) Returns the device identifier or NULL
on failure; call [SDL_GetError](SDL_GetError.html)() for more
information.

## Remarks

The index passed as an argument refers to the N'th haptic device on this
system.

When opening a haptic device, its gain will be set to maximum and
autocenter will be disabled. To modify these values use
[SDL_SetHapticGain](SDL_SetHapticGain.html)() and
[SDL_SetHapticAutocenter](SDL_SetHapticAutocenter.html)().

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseHaptic](SDL_CloseHaptic.html)
- [SDL_GetHaptics](SDL_GetHaptics.html)
- [SDL_OpenHapticFromJoystick](SDL_OpenHapticFromJoystick.html)
- [SDL_OpenHapticFromMouse](SDL_OpenHapticFromMouse.html)
- [SDL_SetHapticAutocenter](SDL_SetHapticAutocenter.html)
- [SDL_SetHapticGain](SDL_SetHapticGain.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
