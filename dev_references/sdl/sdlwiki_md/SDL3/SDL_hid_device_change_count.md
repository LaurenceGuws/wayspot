# SDL_hid_device_change_count

Check to see if devices may have been added or removed.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
Uint32 SDL_hid_device_change_count(void);
```

</div>

## Return Value

([Uint32](Uint32.html)) Returns a change counter that is incremented
with each potential device change, or 0 if device change detection isn't
available.

## Remarks

Enumerating the HID devices is an expensive operation, so you can call
this to see if there have been any system device changes since the last
call to this function. A change in the counter returned doesn't
necessarily mean that anything has changed, but you can call
[SDL_hid_enumerate](SDL_hid_enumerate.html)() to get an updated device
list.

Calling this function for the first time may cause a thread or other
system resource to be allocated to track device change notifications.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_hid_enumerate](SDL_hid_enumerate.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
