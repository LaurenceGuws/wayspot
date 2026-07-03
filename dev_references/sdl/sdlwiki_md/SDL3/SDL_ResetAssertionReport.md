# SDL_ResetAssertionReport

Clear the list of all assertion failures.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_ResetAssertionReport(void);
```

</div>

## Remarks

This function will clear the list of all assertions triggered up to that
point. Immediately following this call,
[SDL_GetAssertionReport](SDL_GetAssertionReport.html) will return no
items. In addition, any previously-triggered assertions will be reset to
a trigger_count of zero, and their always_ignore state will be false.

## Thread Safety

This function is not thread safe. Other threads triggering an assertion,
or simultaneously calling this function may cause memory leaks or
crashes.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetAssertionReport](SDL_GetAssertionReport.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAssert](CategoryAssert.html)
