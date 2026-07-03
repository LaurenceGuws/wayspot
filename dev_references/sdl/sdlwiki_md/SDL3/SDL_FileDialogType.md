# SDL_FileDialogType

Various types of file dialogs.

## Header File

Defined in
[\<SDL3/SDL_dialog.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_dialog.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef enum SDL_FileDialogType
{
    SDL_FILEDIALOG_OPENFILE,
    SDL_FILEDIALOG_SAVEFILE,
    SDL_FILEDIALOG_OPENFOLDER
} SDL_FileDialogType;
```

</div>

## Remarks

This is used by
[SDL_ShowFileDialogWithProperties](SDL_ShowFileDialogWithProperties.html)()
to decide what kind of dialog to present to the user.

## Version

This enum is available since SDL 3.2.0.

## See Also

- [SDL_ShowFileDialogWithProperties](SDL_ShowFileDialogWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIEnum](CategoryAPIEnum.html),
[CategoryDialog](CategoryDialog.html)
