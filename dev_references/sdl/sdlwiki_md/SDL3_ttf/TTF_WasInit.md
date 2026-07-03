###### (This function is part of SDL_ttf, a separate library from SDL.)

# TTF_WasInit

Check if SDL_ttf is initialized.

## Header File

Defined in
[\<SDL3_ttf/SDL_ttf.h\>](https://github.com/libsdl-org/SDL_ttf/blob/main/include/SDL3_ttf/SDL_ttf.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
int TTF_WasInit(void);
```

</div>

## Return Value

(int) Returns the current number of initialization calls, that need to
eventually be paired with this many calls to
[TTF_Quit](TTF_Quit.html)().

## Remarks

This reports the number of times the library has been initialized by a
call to [TTF_Init](TTF_Init.html)(), without a paired deinitialization
request from [TTF_Quit](TTF_Quit.html)().

In short: if it's greater than zero, the library is currently
initialized and ready to work. If zero, it is not initialized.

Despite the return value being a signed integer, this function should
not return a negative number.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL_ttf 3.0.0.

## See Also

- [TTF_Init](TTF_Init.html)
- [TTF_Quit](TTF_Quit.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategorySDLTTF](CategorySDLTTF.html)
