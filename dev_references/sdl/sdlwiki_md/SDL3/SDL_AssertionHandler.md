# SDL_AssertionHandler

A callback that fires when an SDL assertion fails.

## Header File

Defined in
[\<SDL3/SDL_assert.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_assert.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef SDL_AssertState (SDLCALL *SDL_AssertionHandler)( const SDL_AssertData *data, void *userdata);
```

</div>

## Function Parameters

|  |  |
|----|----|
| **data** | a pointer to the [SDL_AssertData](SDL_AssertData.html) structure corresponding to the current assertion. |
| **userdata** | what was passed as `userdata` to [SDL_SetAssertionHandler](SDL_SetAssertionHandler.html)(). |

## Return Value

Returns an [SDL_AssertState](SDL_AssertState.html) value indicating how
to handle the failure.

## Thread Safety

This callback may be called from any thread that triggers an assert at
any time.

## Version

This datatype is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryAssert](CategoryAssert.html)
