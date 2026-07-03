# SDL_IOStream

The read/write operation structure.

## Header File

Defined in
[\<SDL3/SDL_iostream.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_iostream.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_IOStream SDL_IOStream;
```

</div>

## Remarks

This operates as an opaque handle. There are several APIs to create
various types of I/O streams, or an app can supply an
[SDL_IOStreamInterface](SDL_IOStreamInterface.html) to
[SDL_OpenIO](SDL_OpenIO.html)() to provide their own stream
implementation behind this struct's abstract interface.

## Version

This struct is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryIOStream](CategoryIOStream.html)
