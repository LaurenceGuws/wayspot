# SDL_GetTouchFingers

Get a list of active fingers for a given touch device.

## Header File

Defined in
[\<SDL3/SDL_touch.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_touch.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_Finger ** SDL_GetTouchFingers(SDL_TouchID touchID, int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TouchID](SDL_TouchID.html) | **touchID** | the ID of a touch device. |
| int \* | **count** | a pointer filled in with the number of fingers returned, can be NULL. |

## Return Value

([SDL_Finger](SDL_Finger.html) \*\*) Returns a NULL terminated array of
[SDL_Finger](SDL_Finger.html) pointers or NULL on failure; call
[SDL_GetError](SDL_GetError.html)() for more information. This is a
single allocation that should be freed with [SDL_free](SDL_free.html)()
when it is no longer needed.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTouch](CategoryTouch.html)
