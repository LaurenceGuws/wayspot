# SDL_CompareCallback

A callback used with SDL sorting and binary search functions.

## Header File

Defined in
[\<SDL3/SDL_stdinc.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_stdinc.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef int (SDLCALL *SDL_CompareCallback)(const void *a, const void *b);
```

</div>

## Function Parameters

|       |                                                 |
|-------|-------------------------------------------------|
| **a** | a pointer to the first element being compared.  |
| **b** | a pointer to the second element being compared. |

## Return Value

Returns -1 if `a` should be sorted before `b`, 1 if `b` should be sorted
before `a`, 0 if they are equal. If two elements are equal, their order
in the sorted array is undefined.

## Version

This callback is available since SDL 3.2.0.

## See Also

- [SDL_bsearch](SDL_bsearch.html)
- [SDL_qsort](SDL_qsort.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIDatatype](CategoryAPIDatatype.html),
[CategoryStdinc](CategoryStdinc.html)
