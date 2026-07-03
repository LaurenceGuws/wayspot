# SDL_DestroyTray

Destroys a tray object.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_DestroyTray(SDL_Tray *tray);
```

</div>

## Function Parameters

|                              |          |                                |
|------------------------------|----------|--------------------------------|
| [SDL_Tray](SDL_Tray.html) \* | **tray** | the tray icon to be destroyed. |

## Remarks

This also destroys all associated menus and entries.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_CreateTray](SDL_CreateTray.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
