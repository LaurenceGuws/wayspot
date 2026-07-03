# SDL_Vulkan_CreateSurface

Create a Vulkan rendering surface for a window.

## Header File

Defined in
[\<SDL3/SDL_vulkan.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_vulkan.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_Vulkan_CreateSurface(SDL_Window *window,
                                  VkInstance instance,
                                  const struct VkAllocationCallbacks *allocator,
                                  VkSurfaceKHR *surface);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| [SDL_Window](SDL_Window.html) \* | **window** | the window to which to attach the Vulkan surface. |
| VkInstance | **instance** | the Vulkan instance handle. |
| const struct VkAllocationCallbacks \* | **allocator** | a VkAllocationCallbacks struct, which lets the app set the allocator that creates the surface. Can be NULL. |
| VkSurfaceKHR \* | **surface** | a pointer to a VkSurfaceKHR handle to output the newly created surface. |

## Return Value

(bool) Returns true on success or false on failure; call
[SDL_GetError](SDL_GetError.html)() for more information.

## Remarks

The `window` must have been created with the
[`SDL_WINDOW_VULKAN`](SDL_WINDOW_VULKAN.html) flag and `instance` must
have been created with extensions returned by
[SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)()
enabled.

If `allocator` is NULL, Vulkan will use the system default allocator.
This argument is passed directly to Vulkan and isn't used by SDL itself.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)
- [SDL_Vulkan_DestroySurface](SDL_Vulkan_DestroySurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVulkan](CategoryVulkan.html)
