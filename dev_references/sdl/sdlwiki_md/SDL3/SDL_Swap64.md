# SDL_Swap64

Byte-swap an unsigned 64-bit number.

## Header File

Defined in
[\<SDL3/SDL_endian.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_endian.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_FORCE_INLINE Uint64 SDL_Swap64(Uint64 x);
```

</div>

## Function Parameters

|                       |       |                         |
|-----------------------|-------|-------------------------|
| [Uint64](Uint64.html) | **x** | the value to byte-swap. |

## Return Value

([Uint64](Uint64.html)) Returns `x`, with its bytes in the opposite
endian order.

## Remarks

This will always byte-swap the value, whether it's currently in the
native byteorder of the system or not. You should use
[SDL_Swap64LE](SDL_Swap64LE.html) or [SDL_Swap64BE](SDL_Swap64BE.html)
instead, in most cases.

Note that this is a forced-inline function in a header, and not a public
API function available in the SDL library (which is to say, the code is
embedded in the calling program and the linker and dynamic loader will
not be able to find this function inside SDL itself).

## Thread Safety

It is safe to call this function from any thread.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryEndian](CategoryEndian.html)
