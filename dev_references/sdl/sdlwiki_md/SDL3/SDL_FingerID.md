# SDL_FingerID

A unique ID for a single finger on a touch device.

## Header File

Defined in
[\<SDL3/SDL_touch.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_touch.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef Uint64 SDL_FingerID;
```

</div>

## Remarks

This ID is valid for the time the finger (stylus, etc) is touching and
will be unique for all fingers currently in contact, so this ID tracks
the lifetime of a single continuous touch. This value may represent an
index, a pointer, or some other unique ID, depending on the platform.

The value 0 is an invalid ID.

## Version

This datatype is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryTouch](CategoryTouch.html)
