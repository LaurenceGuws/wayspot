# SDL_SetHapticAutocenter

Set the global autocenter of the device.

## Header File

Defined in
[\<SDL3/SDL_haptic.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_haptic.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetHapticAutocenter(SDL_Haptic *haptic, int autocenter);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Haptic](SDL_Haptic.html) \* | **haptic** | the [SDL_Haptic](SDL_Haptic.html) device to set autocentering on. |
| int | **autocenter** | value to set autocenter to (0-100). |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Autocenter should be between 0 and 100. Setting it to 0 will disable
autocentering.

Device must support the
[SDL_HAPTIC_AUTOCENTER](SDL_HAPTIC_AUTOCENTER.html) feature.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHapticFeatures](SDL_GetHapticFeatures.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHaptic](CategoryHaptic.html)
