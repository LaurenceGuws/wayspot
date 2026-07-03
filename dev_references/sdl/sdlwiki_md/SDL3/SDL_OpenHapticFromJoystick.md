# SDL_OpenHapticFromJoystick

Open a haptic device for use from a joystick device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Haptic * SDL_OpenHapticFromJoystick(SDL_Joystick *joystick);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | the [SDL_Joystick](SDL_Joystick.html) to create a haptic device from. |

## Return Value

([SDL_Haptic](SDL_Haptic.html) \*) Returns a valid haptic device
identifier on success or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

You must still close the haptic device separately. It will not be closed
with the joystick.

When opened from a joystick you should first close the haptic device
before closing the joystick device. If not, on some implementations the
haptic device will also get unallocated and you'll be unable to use
force feedback on that device.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CloseHaptic](SDL_CloseHaptic.html)
- [SDL_IsJoystickHaptic](SDL_IsJoystickHaptic.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
