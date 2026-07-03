# SDL_hid_open_path

Open a HID device by its path name.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_hid_device * SDL_hid_open_path(const char *path);
```

</div>

## Function Parameters

|               |          |                                      |
|---------------|----------|--------------------------------------|
| const char \* | **path** | the path name of the device to open. |

## Return Value

([SDL_hid_device](SDL_hid_device.html) \*) Returns a pointer to a
[SDL_hid_device](SDL_hid_device.html) object on success or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The path name be determined by calling
[SDL_hid_enumerate](SDL_hid_enumerate.html)(), or a platform-specific
path name can be used (eg: /dev/hidraw0 on Linux).

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
