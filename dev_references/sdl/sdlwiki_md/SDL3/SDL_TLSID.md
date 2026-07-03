# SDL_TLSID

Thread local storage ID.

## Header File

Defined in
[\<SDL3/SDL_thread.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_thread.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef SDL_AtomicInt SDL_TLSID;
```

</div>

## Remarks

0 is the invalid ID. An app can create these and then set data for these
IDs that is unique to each thread.

## Version

This datatype is available since SDL 3.2.0.

## See Also

- [SDL_GetTLS](SDL_GetTLS.html)
- [SDL_SetTLS](SDL_SetTLS.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryThread](CategoryThread.html)
