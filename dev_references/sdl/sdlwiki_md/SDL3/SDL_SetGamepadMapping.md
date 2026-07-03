# SDL_SetGamepadMapping

Set the current mapping of a joystick or gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_SetGamepadMapping(SDL_JoystickID instance_id, const char *mapping);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_JoystickID](SDL_JoystickID.html) | **instance_id** | the joystick instance ID. |
| const char \* | **mapping** | the mapping to use for this device, or NULL to clear the mapping. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Details about mappings are discussed with
[SDL_AddGamepadMapping](SDL_AddGamepadMapping.html)().

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_AddGamepadMapping](SDL_AddGamepadMapping.html)
- [SDL_GetGamepadMapping](SDL_GetGamepadMapping.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
