# SDL_hid_init

Initialize the HIDAPI library.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_hid_init(void);
```

</div>

## Return Value

(int) Returns 0 on success or a negative error code on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function initializes the HIDAPI library. Calling it is not strictly
necessary, as it will be called automatically by
[SDL_hid_enumerate](SDL_hid_enumerate.html)(),
[SDL_hid_open](SDL_hid_open.html)(), and
[SDL_hid_open_path](SDL_hid_open_path.html)() if needed. This function
should be called at the beginning of execution however, if there is a
chance of HIDAPI handles being opened by different threads
simultaneously.

Each call to this function should have a matching call to
[SDL_hid_exit](SDL_hid_exit.html)()

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_hid_exit](SDL_hid_exit.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
