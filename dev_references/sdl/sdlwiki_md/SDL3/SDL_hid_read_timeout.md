# SDL_hid_read_timeout

Read an Input report from a HID device with timeout.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_hid_read_timeout(SDL_hid_device *dev, unsigned char *data, size_t length, int milliseconds);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_hid_device](SDL_hid_device.html) \* | **dev** | a device handle returned from [SDL_hid_open](SDL_hid_open.html)(). |
| unsigned char \* | **data** | a buffer to put the read data into. |
| size_t | **length** | the number of bytes to read. For devices with multiple reports, make sure to read an extra byte for the report number. |
| int | **milliseconds** | timeout in milliseconds or -1 for blocking wait. |

## Return Value

(int) Returns the actual number of bytes read and -1 on on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. If no packet
was available to be read within the timeout period, this function
returns 0.

## Remarks

Input reports are returned to the host through the INTERRUPT IN
endpoint. The first byte will contain the Report number if the device
uses numbered reports.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
