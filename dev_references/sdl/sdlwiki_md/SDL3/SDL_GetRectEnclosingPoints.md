# SDL_GetRectEnclosingPoints

Calculate a minimal rectangle enclosing a set of points.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRectEnclosingPoints(const SDL_Point *points, int count, const SDL_Rect *clip, SDL_Rect *result);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_Point](SDL_Point.html) \* | **points** | an array of [SDL_Point](SDL_Point.html) structures representing points to be enclosed. |
| int | **count** | the number of structures in the `points` array. |
| const [SDL_Rect](SDL_Rect.html) \* | **clip** | an [SDL_Rect](SDL_Rect.html) used for clipping or NULL to enclose all points. |
| [SDL_Rect](SDL_Rect.html) \* | **result** | an [SDL_Rect](SDL_Rect.html) structure filled in with the minimal enclosing rectangle. |

## Return Value

(bool) Returns true if any points were enclosed or false if all the
points were outside of the clipping rectangle.

## Remarks

If `clip` is not NULL then only points inside of the clipping rectangle
are considered.

## Version

This function is available since SDL 3.2.0.

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryRect](CategoryRect.html)
