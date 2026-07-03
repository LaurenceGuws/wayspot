# SDL_ReportAssertion

Never call this directly.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_AssertState SDL_ReportAssertion(SDL_AssertData *data,
                                const char *func,
                                const char *file, int line);
```

</div>

## Function Parameters

|                                          |          |                        |
|------------------------------------------|----------|------------------------|
| [SDL_AssertData](SDL_AssertData.html) \* | **data** | assert data structure. |
| const char \*                            | **func** | function name.         |
| const char \*                            | **file** | file name.             |
| int                                      | **line** | line number.           |

## Return Value

([SDL_AssertState](SDL_AssertState.html)) Returns assert state.

## Remarks

Use the [SDL_assert](SDL_assert.html) macros instead.

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryAssert](CategoryAssert.html)
