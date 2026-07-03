# SDL_COLORSPACETRANSFER

A macro to retrieve the transfer characteristics of an
[SDL_Colorspace](SDL_Colorspace.html).

## Header File

Defined in
[\<SDL3/SDL_pixels.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_pixels.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
#define SDL_COLORSPACETRANSFER(cspace)   (SDL_TransferCharacteristics)(((cspace) >> 5) & 0x1F)
```

</div>

## Macro Parameters

|            |                                                    |
|------------|----------------------------------------------------|
| **cspace** | an [SDL_Colorspace](SDL_Colorspace.html) to check. |

## Return Value

Returns the
[SDL_TransferCharacteristics](SDL_TransferCharacteristics.html) of
`cspace`.

## Thread Safety

It is safe to call this macro from any thread.

## Version

This macro is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIMacro](CategoryAPIMacro.html),
[CategoryPixels](CategoryPixels.html)
