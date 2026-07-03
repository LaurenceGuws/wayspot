# CategoryProcess

Process control support.

These functions provide a cross-platform way to spawn and manage
OS-level processes.

You can create a new subprocess with
[SDL_CreateProcess](SDL_CreateProcess.html)() and optionally read and
write to it using [SDL_ReadProcess](SDL_ReadProcess.html)() or
[SDL_GetProcessInput](SDL_GetProcessInput.html)() and
[SDL_GetProcessOutput](SDL_GetProcessOutput.html)(). If more advanced
functionality like chaining input between processes is necessary, you
can use
[SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)().

You can get the status of a created process with
[SDL_WaitProcess](SDL_WaitProcess.html)(), or terminate the process with
[SDL_KillProcess](SDL_KillProcess.html)().

Don't forget to call [SDL_DestroyProcess](SDL_DestroyProcess.html)() to
clean up, whether the process process was killed, terminated on its own,
or is still running!

## Functions

- [SDL_CreateProcess](SDL_CreateProcess.html)
- [SDL_CreateProcessWithProperties](SDL_CreateProcessWithProperties.html)
- [SDL_DestroyProcess](SDL_DestroyProcess.html)
- [SDL_GetProcessInput](SDL_GetProcessInput.html)
- [SDL_GetProcessOutput](SDL_GetProcessOutput.html)
- [SDL_GetProcessProperties](SDL_GetProcessProperties.html)
- [SDL_KillProcess](SDL_KillProcess.html)
- [SDL_ReadProcess](SDL_ReadProcess.html)
- [SDL_WaitProcess](SDL_WaitProcess.html)

## Datatypes

- [SDL_Process](SDL_Process.html)

## Structs

- (none.)

## Enums

- [SDL_ProcessIO](SDL_ProcessIO.html)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
