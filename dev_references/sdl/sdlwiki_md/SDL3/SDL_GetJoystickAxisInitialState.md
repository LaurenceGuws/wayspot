# SDL_GetJoystickAxisInitialState

Get the initial state of an axis control on a joystick.

## Header File

Defined in
[\<SDL3/SDL_joystick.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_joystick.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetJoystickAxisInitialState(SDL_Joystick *joystick, int axis, Sint16 *state);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Joystick](SDL_Joystick.html) \* | **joystick** | an [SDL_Joystick](SDL_Joystick.html) structure containing joystick information. |
| int | **axis** | the axis to query; the axis indices start at index 0. |
| [Sint16](Sint16.html) \* | **state** | upon return, the initial value is supplied here. |

## Return Value

(bool) Returns true if this axis has any initial value, or false if not.

## Remarks

The state is a value ranging from -32768 to 32767.

The axis indices start at index 0.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryJoystick](CategoryJoystick.html)
