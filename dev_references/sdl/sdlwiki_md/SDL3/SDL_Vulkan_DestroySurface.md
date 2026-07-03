# SDL_Vulkan_DestroySurface

Destroy the Vulkan rendering surface of a window.

## Header File

Defined in
[\<SDL3/SDL_vulkan.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_vulkan.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
void SDL_Vulkan_DestroySurface(VkInstance instance,
                           VkSurfaceKHR surface,
                           const struct VkAllocationCallbacks *allocator);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| VkInstance | **instance** | the Vulkan instance handle. |
| VkSurfaceKHR | **surface** | vkSurfaceKHR handle to destroy. |
| const struct VkAllocationCallbacks \* | **allocator** | a VkAllocationCallbacks struct, which lets the app set the allocator that destroys the surface. Can be NULL. |

## Remarks

This should be called before
[SDL_DestroyWindow](SDL_DestroyWindow.html), if
[SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html) was called
after [SDL_CreateWindow](SDL_CreateWindow.html).

The `instance` must have been created with extensions returned by
[SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)()
enabled and `surface` must have been created successfully by an
[SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html)() call.

If `allocator` is NULL, Vulkan will use the system default allocator.
This argument is passed directly to Vulkan and isn't used by SDL itself.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)
- [SDL_Vulkan_CreateSurface](SDL_Vulkan_CreateSurface.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVulkan](CategoryVulkan.html)
