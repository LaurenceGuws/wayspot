# SDL_Rect

A rectangle, with the origin at the upper left (using integers).

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_Rect
{
    int x, y;
    int w, h;
} SDL_Rect;
```

</div>

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_RectEmpty](SDL_RectEmpty.html)
- [SDL_RectsEqual](SDL_RectsEqual.html)
- [SDL_HasRectIntersection](SDL_HasRectIntersection.html)
- [SDL_GetRectIntersection](SDL_GetRectIntersection.html)
- [SDL_GetRectAndLineIntersection](SDL_GetRectAndLineIntersection.html)
- [SDL_GetRectUnion](SDL_GetRectUnion.html)
- [SDL_GetRectEnclosingPoints](SDL_GetRectEnclosingPoints.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryRect](CategoryRect.html)
