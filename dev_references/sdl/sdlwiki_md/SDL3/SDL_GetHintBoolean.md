# SDL_GetHintBoolean

Get the boolean value of a hint variable.

## Header File

Defined in
[\<SDL3/SDL_hints.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_hints.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetHintBoolean(const char *name, bool default_value);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const char \* | **name** | the name of the hint to get the boolean value from. |
| bool | **default_value** | the value to return if the hint does not exist. |

## Return Value

(bool) Returns the boolean value of a hint or the provided default value
if the hint does not exist.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetHint](SDL_GetHint.html)
- [SDL_SetHint](SDL_SetHint.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryHints](CategoryHints.html)
