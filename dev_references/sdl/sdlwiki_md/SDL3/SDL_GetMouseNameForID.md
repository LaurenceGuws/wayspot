# SDL_GetMouseNameForID

Get the name of a mouse.

## Header File

Defined in
[\<SDL3/SDL_mouse.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_mouse.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetMouseNameForID(SDL_MouseID instance_id);
```

</div>

## Function Parameters

|                                 |                 |                        |
|---------------------------------|-----------------|------------------------|
| [SDL_MouseID](SDL_MouseID.html) | **instance_id** | the mouse instance ID. |

## Return Value

(const char \*) Returns the name of the selected mouse, or NULL on
failure; call [SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

This function returns "" if the mouse doesn't have a name.

## Thread Safety

This function should only be called on the main thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetMice](SDL_GetMice.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryMouse](CategoryMouse.html)
