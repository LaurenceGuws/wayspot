# SDL_GetTrayEntryChecked

Gets whether or not an entry is checked.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_GetTrayEntryChecked(SDL_TrayEntry *entry);
```

</div>

## Function Parameters

|                                        |           |                       |
|----------------------------------------|-----------|-----------------------|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | the entry to be read. |

## Return Value

(bool) Returns true if the entry is checked; false otherwise.

## Remarks

The entry must have been created with the
[SDL_TRAYENTRY_CHECKBOX](SDL_TRAYENTRY_CHECKBOX.html) flag.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTrayEntries](SDL_GetTrayEntries.html)
- [SDL_InsertTrayEntryAt](SDL_InsertTrayEntryAt.html)
- [SDL_SetTrayEntryChecked](SDL_SetTrayEntryChecked.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
