# SDL_hid_get_device_info

Get the device info from a HID device.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_hid_device_info * SDL_hid_get_device_info(SDL_hid_device *dev);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_hid_device](SDL_hid_device.html) \* | **dev** | a device handle returned from [SDL_hid_open](SDL_hid_open.html)(). |

## Return Value

([SDL_hid_device_info](SDL_hid_device_info.html) \*) Returns a pointer
to the [SDL_hid_device_info](SDL_hid_device_info.html) for this
hid_device or NULL on failure; call [SDL_GetError](SDL_GetError.html)()
for more information. This struct is valid until the device is closed
with [SDL_hid_close](SDL_hid_close.html)().

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
