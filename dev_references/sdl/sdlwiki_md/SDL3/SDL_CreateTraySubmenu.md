# SDL_CreateTraySubmenu

Create a submenu for a system tray entry.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
SDL_TrayMenu * SDL_CreateTraySubmenu(SDL_TrayEntry *entry);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | the tray entry to bind the menu to. |

## Return Value

([SDL_TrayMenu](SDL_TrayMenu.html) \*) Returns the newly created menu.

## Remarks

This should be called at most once per tray entry.

This function does the same thing as
[SDL_CreateTrayMenu](SDL_CreateTrayMenu.html), except that it takes a
[SDL_TrayEntry](SDL_TrayEntry.html) instead of a
[SDL_Tray](SDL_Tray.html).

A menu does not need to be destroyed; it will be destroyed with the
tray.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_InsertTrayEntryAt](SDL_InsertTrayEntryAt.html)
- [SDL_GetTraySubmenu](SDL_GetTraySubmenu.html)
- [SDL_GetTrayMenuParentEntry](SDL_GetTrayMenuParentEntry.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
