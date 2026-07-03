# SDL_GetPenDeviceType

Get the device type of the given pen.

## Header File

Defined in
[\<SDL3/SDL_pen.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pen.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PenDeviceType SDL_GetPenDeviceType(SDL_PenID instance_id);
```

</div>

## Function Parameters

|                             |                 |                      |
|-----------------------------|-----------------|----------------------|
| [SDL_PenID](SDL_PenID.html) | **instance_id** | the pen instance ID. |

## Return Value

([SDL_PenDeviceType](SDL_PenDeviceType.html)) Returns the device type of
the given pen, or
[SDL_PEN_DEVICE_TYPE_INVALID](SDL_PEN_DEVICE_TYPE_INVALID.html) on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

Many platforms do not supply this information, so an app must always be
prepared to get an
[SDL_PEN_DEVICE_TYPE_UNKNOWN](SDL_PEN_DEVICE_TYPE_UNKNOWN.html) result.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryPen](CategoryPen.html)
