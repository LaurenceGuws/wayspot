# SDL_RumbleGamepad

Start a rumble effect on a gamepad.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_RumbleGamepad(SDL_Gamepad *gamepad, Uint16 low_frequency_rumble, Uint16 high_frequency_rumble, Uint32 duration_ms);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Gamepad](SDL_Gamepad.html) \* | **gamepad** | the gamepad to vibrate. |
| [Uint16](Uint16.html) | **low_frequency_rumble** | the intensity of the low frequency (left) rumble motor, from 0 to 0xFFFF. |
| [Uint16](Uint16.html) | **high_frequency_rumble** | the intensity of the high frequency (right) rumble motor, from 0 to 0xFFFF. |
| [Uint32](Uint32.html) | **duration_ms** | the duration of the rumble effect, in milliseconds. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Each call to this function cancels any previous rumble effect, and
calling it with 0 intensity stops any rumbling.

This function requires you to process SDL events or call
[SDL_UpdateJoysticks](SDL_UpdateJoysticks.html)() to update rumble
state.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
