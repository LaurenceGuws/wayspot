# SDL_DialogFileFilter

An entry for filters for file dialogs.

## Header File

Defined in
[\<SDL3/SDL_dialog.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_dialog.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
typedef struct SDL_DialogFileFilter
{
    const char *name;
    const char *pattern;
} SDL_DialogFileFilter;
```

</div>

## Remarks

`name` is a user-readable label for the filter (for example, "Office
document").

`pattern` is a semicolon-separated list of file extensions (for example,
"doc;docx"). File extensions may only contain alphanumeric characters,
hyphens, underscores and periods. Alternatively, the whole string can be
a single asterisk ("\*"), which serves as an "All files" filter.

## Version

This struct is available since SDL 3.2.0.

## Code Examples

This structure is most often used as an array:

<div id="cb2" class="sourceCode">

``` sourceCode
const SDL_DialogFileFilter filters[] = {
    { "PNG images",  "png" },
    { "JPEG images", "jpg;jpeg" },
    { "All images",  "png;jpg;jpeg" },
    { "All files",   "*" }
};
```

</div>

## See Also

- [SDL_DialogFileCallback](SDL_DialogFileCallback.html)
- [SDL_ShowOpenFileDialog](SDL_ShowOpenFileDialog.html)
- [SDL_ShowSaveFileDialog](SDL_ShowSaveFileDialog.html)
- [SDL_ShowOpenFolderDialog](SDL_ShowOpenFolderDialog.html)
- [SDL_ShowFileDialogWithProperties](SDL_ShowFileDialogWithProperties.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIStruct](CategoryAPIStruct.html),
[CategoryDialog](CategoryDialog.html)
