# CategoryVulkan

Functions for creating Vulkan surfaces on SDL windows.

For the most part, Vulkan operates independent of SDL, but it benefits
from a little support during setup.

Use
[SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)()
to get platform-specific bits for creating a VkInstance, then
[SDL_Vulkan_GetVkGetInstanceProcAddr](SDL_Vulkan_GetVkGetInstanceProcAddr.html)()
to get the appropriate function for querying Vulkan entry points. Then
[SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html)() will get you
the final pieces you need to prepare for rendering into an
[SDL_Window](SDL_Window.html) with Vulkan.

Unlike OpenGL, most of the details of "context" creation and window
buffer swapping are handled by the Vulkan API directly, so SDL doesn't
provide Vulkan equivalents of
[SDL_GL_SwapWindow](SDL_GL_SwapWindow.html)(), etc; they aren't
necessary.

## Functions

- [SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html)
- [SDL_Vulkan_DestroySurface](SDL_Vulkan_DestroySurface.html)
- [SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)
- [SDL_Vulkan_GetPresentationSupport](SDL_Vulkan_GetPresentationSupport.html)
- [SDL_Vulkan_GetVkGetInstanceProcAddr](SDL_Vulkan_GetVkGetInstanceProcAddr.html)
- [SDL_Vulkan_LoadLibrary](SDL_Vulkan_LoadLibrary.html)
- [SDL_Vulkan_UnloadLibrary](SDL_Vulkan_UnloadLibrary.html)

## Datatypes

- (none.)

## Structs

- (none.)

## Enums

- (none.)

## Macros

- (none.)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
