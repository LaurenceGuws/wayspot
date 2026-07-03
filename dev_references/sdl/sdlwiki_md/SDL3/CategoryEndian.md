# CategoryEndian

Functions converting endian-specific values to different byte orders.

These functions either unconditionally swap byte order
([SDL_Swap16](SDL_Swap16.html), [SDL_Swap32](SDL_Swap32.html),
[SDL_Swap64](SDL_Swap64.html), [SDL_SwapFloat](SDL_SwapFloat.html)), or
they swap to/from the system's native byte order
([SDL_Swap16LE](SDL_Swap16LE.html), [SDL_Swap16BE](SDL_Swap16BE.html),
[SDL_Swap32LE](SDL_Swap32LE.html), [SDL_Swap32BE](SDL_Swap32BE.html),
[SDL_Swap32LE](SDL_Swap32LE.html), [SDL_Swap32BE](SDL_Swap32BE.html),
[SDL_SwapFloatLE](SDL_SwapFloatLE.html),
[SDL_SwapFloatBE](SDL_SwapFloatBE.html)). In the latter case, the
functionality is provided by macros that become no-ops if a swap isn't
necessary: on an x86 (littleendian) processor,
[SDL_Swap32LE](SDL_Swap32LE.html) does nothing, but
[SDL_Swap32BE](SDL_Swap32BE.html) reverses the bytes of the data. On a
PowerPC processor (bigendian), the macros behavior is reversed.

The swap routines are inline functions, and attempt to use compiler
intrinsics, inline assembly, and other magic to make byteswapping
efficient.

## Functions

- [SDL_Swap16](SDL_Swap16.html)
- [SDL_Swap32](SDL_Swap32.html)
- [SDL_Swap64](SDL_Swap64.html)
- [SDL_SwapFloat](SDL_SwapFloat.html)

## Datatypes

- (none.)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- [SDL_BIG_ENDIAN](SDL_BIG_ENDIAN.html)
- [SDL_BYTEORDER](SDL_BYTEORDER.html)
- [SDL_FLOATWORDORDER](SDL_FLOATWORDORDER.html)
- [SDL_LIL_ENDIAN](SDL_LIL_ENDIAN.html)
- [SDL_Swap16BE](SDL_Swap16BE.html)
- [SDL_Swap16LE](SDL_Swap16LE.html)
- [SDL_Swap32BE](SDL_Swap32BE.html)
- [SDL_Swap32LE](SDL_Swap32LE.html)
- [SDL_Swap64BE](SDL_Swap64BE.html)
- [SDL_Swap64LE](SDL_Swap64LE.html)
- [SDL_SwapFloatBE](SDL_SwapFloatBE.html)
- [SDL_SwapFloatLE](SDL_SwapFloatLE.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
