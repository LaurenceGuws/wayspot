# SDL_hid_get_properties

Get the properties associated with an
[SDL_hid_device](SDL_hid_device.html).

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_PropertiesID SDL_hid_get_properties(SDL_hid_device *dev);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_hid_device](SDL_hid_device.html) \* | **dev** | a device handle returned from [SDL_hid_open](SDL_hid_open.html)(). |

## Return Value

([SDL_PropertiesID](SDL_PropertiesID.html)) Returns a valid property ID
on success or 0 on failure; call [SDL_GetError](SDL_GetError.html)() for
more information.

## Remarks

The following read-only properties are provided by SDL:

- [`SDL_PROP_HIDAPI_LIBUSB_DEVICE_HANDLE_POINTER`](SDL_PROP_HIDAPI_LIBUSB_DEVICE_HANDLE_POINTER.html):
  the libusb_device_handle associated with the device, if it was opened
  using libusb.

## Version

This function is available since SDL 3.4.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
