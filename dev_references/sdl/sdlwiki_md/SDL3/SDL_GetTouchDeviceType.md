# SDL_GetTouchDeviceType

Get the type of the given touch device.

## Header File

Defined in
[\<SDL3/SDL_touch.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_touch.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_TouchDeviceType SDL_GetTouchDeviceType(SDL_TouchID touchID);
```

</div>

## Function Parameters

|                                 |             |                           |
|---------------------------------|-------------|---------------------------|
| [SDL_TouchID](SDL_TouchID.html) | **touchID** | the ID of a touch device. |

## Return Value

([SDL_TouchDeviceType](SDL_TouchDeviceType.html)) Returns touch device
type.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTouch](CategoryTouch.html)
