# SDL_hid_get_product_string

Get The Product String from a HID device.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_hid_get_product_string(SDL_hid_device *dev, wchar_t *string, size_t maxlen);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_hid_device](SDL_hid_device.html) \* | **dev** | a device handle returned from [SDL_hid_open](SDL_hid_open.html)(). |
| wchar_t \* | **string** | a wide string buffer to put the data into. |
| size_t | **maxlen** | the length of the buffer in multiples of wchar_t. |

## Return Value

(int) Returns 0 on success or a negative error code on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
