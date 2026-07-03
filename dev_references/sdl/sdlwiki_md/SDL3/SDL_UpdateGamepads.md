# SDL_UpdateGamepads

Manually pump gamepad updates if not using the loop.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_UpdateGamepads(void);
```

</div>

## Remarks

This function is called automatically by the event loop if events are
enabled. Under such circumstances, it will not be necessary to call this
function.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
