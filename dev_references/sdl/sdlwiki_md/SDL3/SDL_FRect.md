# SDL_FRect

A rectangle stored using floating point values.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_FRect
{
    float x;
    float y;
    float w;
    float h;
} SDL_FRect;
```

</div>

## Remarks

The origin of the coordinate space is in the top-left, with increasing
values moving down and right. The properties `x` and `y` represent the
coordinates of the top-left corner of the rectangle.

## Version

This struct is available since SDL 3.2.0.

## See Also

- [SDL_RectEmptyFloat](SDL_RectEmptyFloat.html)
- [SDL_RectsEqualFloat](SDL_RectsEqualFloat.html)
- [SDL_RectsEqualEpsilon](SDL_RectsEqualEpsilon.html)
- [SDL_HasRectIntersectionFloat](SDL_HasRectIntersectionFloat.html)
- [SDL_GetRectIntersectionFloat](SDL_GetRectIntersectionFloat.html)
- [SDL_GetRectAndLineIntersectionFloat](SDL_GetRectAndLineIntersectionFloat.html)
- [SDL_GetRectUnionFloat](SDL_GetRectUnionFloat.html)
- [SDL_GetRectEnclosingPointsFloat](SDL_GetRectEnclosingPointsFloat.html)
- [SDL_PointInRectFloat](SDL_PointInRectFloat.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryRect](CategoryRect.html)
