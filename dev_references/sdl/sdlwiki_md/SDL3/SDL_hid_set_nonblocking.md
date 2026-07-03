# SDL_hid_set_nonblocking

Set the device handle to be non-blocking.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_hid_set_nonblocking(SDL_hid_device *dev, int nonblock);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_hid_device](SDL_hid_device.html) \* | **dev** | a device handle returned from [SDL_hid_open](SDL_hid_open.html)(). |
| int | **nonblock** | enable or not the nonblocking reads - 1 to enable nonblocking - 0 to disable nonblocking. |

## Return Value

(int) Returns 0 on success or a negative error code on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

In non-blocking mode calls to [SDL_hid_read](SDL_hid_read.html)() will
return immediately with a value of 0 if there is no data to be read. In
blocking mode, [SDL_hid_read](SDL_hid_read.html)() will wait (block)
until there is data to read before returning.

Nonblocking can be turned on and off at any time.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
