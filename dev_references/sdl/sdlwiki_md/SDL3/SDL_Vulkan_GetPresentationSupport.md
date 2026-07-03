# SDL_Vulkan_GetPresentationSupport

Query support for presentation via a given physical device and queue
family.

## Header File

Defined in
[\<SDL3/SDL_vulkan.h\>](https://github.com/libsdl-org/SDL/blob/main/include/SDL3/SDL_vulkan.h)

## Syntax

<div id="cb1" class="sourceCode">

``` sourceCode
bool SDL_Vulkan_GetPresentationSupport(VkInstance instance,
                                           VkPhysicalDevice physicalDevice,
                                           Uint32 queueFamilyIndex);
```

</div>

## Function Parameters

|  |  |  |
|----|----|----|
| VkInstance | **instance** | the Vulkan instance handle. |
| VkPhysicalDevice | **physicalDevice** | a valid Vulkan physical device handle. |
| [Uint32](Uint32.html) | **queueFamilyIndex** | a valid queue family index for the given physical device. |

## Return Value

(bool) Returns true if supported, false if unsupported or an error
occurred.

## Remarks

The `instance` must have been created with extensions returned by
[SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)()
enabled.

## Version

This function is available since SDL 3.2.0.

## See Also

- [SDL_Vulkan_GetInstanceExtensions](SDL_Vulkan_GetInstanceExtensions.html)

------------------------------------------------------------------------

[CategoryAPI](CategoryAPI.html),
[CategoryAPIFunction](CategoryAPIFunction.html),
[CategoryVulkan](CategoryVulkan.html)
