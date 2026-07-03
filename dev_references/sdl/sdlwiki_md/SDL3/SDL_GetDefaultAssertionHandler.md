# SDL_GetDefaultAssertionHandler

Get the default assertion handler.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_AssertionHandler SDL_GetDefaultAssertionHandler(void);
```

</div>

## Return Value

([SDL_AssertionHandler](SDL_AssertionHandler.html)) Returns the default
[SDL_AssertionHandler](SDL_AssertionHandler.html) that is called when an
assert triggers.

## Remarks

This returns the function pointer that is called by default when an
assertion is triggered. This is an internal function provided by SDL,
that is used for assertions when
[SDL_SetAssertionHandler](SDL_SetAssertionHandler.html)() hasn't been
used to provide a different function.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAssertionHandler](SDL_GetAssertionHandler.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAssert](CategoryAssert.html)
