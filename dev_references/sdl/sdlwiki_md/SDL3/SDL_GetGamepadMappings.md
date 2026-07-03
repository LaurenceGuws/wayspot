# SDL_GetGamepadMappings

Get the current gamepad mappings.

## Header File

Defined in
[\<SDL3/SDL_gamepad.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_gamepad.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
char ** SDL_GetGamepadMappings(int *count);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| int \* | **count** | a pointer filled in with the number of mappings returned, can be NULL. |

## Return Value

(char \*\*) Returns an array of the mapping strings, NULL-terminated, or
NULL on failure; call [SDL_GetError](SDL_GetError.html)() for more
information. This is a single allocation that should be freed with
[SDL_free](SDL_free.html)() when it is no longer needed.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryGamepad](CategoryGamepad.html)
