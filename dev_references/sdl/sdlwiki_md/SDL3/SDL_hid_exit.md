# SDL_hid_exit

Finalize the HIDAPI library.

## Header File

Defined in
[\<SDL3/SDL_hidapi.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hidapi.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int SDL_hid_exit(void);
```

</div>

## Return Value

(int) Returns 0 on success or a negative error code on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function frees all of the static data associated with HIDAPI. It
should be called at the end of execution to avoid memory leaks.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_hid_init](SDL_hid_init.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHIDAPI](CategoryHIDAPI.html)
