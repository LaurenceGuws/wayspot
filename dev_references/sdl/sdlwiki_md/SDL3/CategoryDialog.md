# CategoryDialog

File dialog support.

SDL offers file dialogs, to let users select files with native GUI
interfaces. There are "open" dialogs, "save" dialogs, and folder
selection dialogs. The app can control some details, such as filtering
to specific files, or whether multiple files can be selected by the
user.

Note that launching a file dialog is a non-blocking operation; control
returns to the app immediately, and a callback is called later (possibly
in another thread) when the user makes a choice.

## Functions

- [SDL_ShowFileDialogWithProperties](SDL_ShowFileDialogWithProperties.html)
- [SDL_ShowOpenFileDialog](SDL_ShowOpenFileDialog.html)
- [SDL_ShowOpenFolderDialog](SDL_ShowOpenFolderDialog.html)
- [SDL_ShowSaveFileDialog](SDL_ShowSaveFileDialog.html)

## Datatypes

- [SDL_DialogFileCallback](SDL_DialogFileCallback.html)

## Structs

- [SDL_DialogFileFilter](SDL_DialogFileFilter.html)

## Enums

- [SDL_FileDialogType](SDL_FileDialogType.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
