# SDL_GetTouchDeviceName

Get the touch device name as reported from the driver.

## Header File

Defined in
[\<SDL3/SDL_touch.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_touch.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetTouchDeviceName(SDL_TouchID touchID);
```

</div>

## Function Parameters

|                                 |             |                               |
|---------------------------------|-------------|-------------------------------|
| [SDL_TouchID](SDL_TouchID.html) | **touchID** | the touch device instance ID. |

## Return Value

(const char \*) Returns touch device name, or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTouch](CategoryTouch.html)
