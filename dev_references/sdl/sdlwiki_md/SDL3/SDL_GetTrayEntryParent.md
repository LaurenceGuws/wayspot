# SDL_GetTrayEntryParent

Gets the menu containing a certain tray entry.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_TrayMenu * SDL_GetTrayEntryParent(SDL_TrayEntry *entry);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | the entry for which to get the parent menu. |

## Return Value

([SDL_TrayMenu](SDL_TrayMenu.html) \*) Returns the parent menu.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_InsertTrayEntryAt](SDL_InsertTrayEntryAt.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
