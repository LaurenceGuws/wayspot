# SDL_GetTrayEntryLabel

Gets the label of an entry.

## Header File

Defined in
[\<SDL3/SDL_tray.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_tray.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
const char * SDL_GetTrayEntryLabel(SDL_TrayEntry *entry);
```

</div>

## Function Parameters

|                                        |           |                       |
|----------------------------------------|-----------|-----------------------|
| [SDL_TrayEntry](SDL_TrayEntry.html) \* | **entry** | the entry to be read. |

## Return Value

(const char \*) Returns the label of the entry in UTF-8 encoding.

## Remarks

If the returned value is NULL, the entry is a separator.

## Thread Safety

This function should be called on the thread that created the tray.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_GetTrayEntries](SDL_GetTrayEntries.html)
- [SDL_InsertTrayEntryAt](SDL_InsertTrayEntryAt.html)
- [SDL_SetTrayEntryLabel](SDL_SetTrayEntryLabel.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryTray](CategoryTray.html)
