# SDL_GetRectEnclosingPointsFloat

Calculate a minimal rectangle enclosing a set of points with float
precision.

## Header File

Defined in
[\<SDL3/SDL_rect.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_rect.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetRectEnclosingPointsFloat(const SDL_FPoint *points, int count, const SDL_FRect *clip, SDL_FRect *result);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| const [SDL_FPoint](SDL_FPoint.html) \* | **points** | an array of [SDL_FPoint](SDL_FPoint.html) structures representing points to be enclosed. |
| int | **count** | the number of structures in the `points` array. |
| const [SDL_FRect](SDL_FRect.html) \* | **clip** | an [SDL_FRect](SDL_FRect.html) used for clipping or NULL to enclose all points. |
| [SDL_FRect](SDL_FRect.html) \* | **result** | an [SDL_FRect](SDL_FRect.html) structure filled in with the minimal enclosing rectangle. |

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
