# CategoryProperties

A property is a variable that can be created and retrieved by name at
runtime.

All properties are part of a property group
([SDL_PropertiesID](SDL_PropertiesID.html)). A property group can be
created with the [SDL_CreateProperties](SDL_CreateProperties.html)
function and destroyed with the
[SDL_DestroyProperties](SDL_DestroyProperties.html) function.

Properties can be added to and retrieved from a property group through
the following functions:

- [SDL_SetPointerProperty](SDL_SetPointerProperty.html) and
  [SDL_GetPointerProperty](SDL_GetPointerProperty.html) operate on
  `void*` pointer types.
- [SDL_SetStringProperty](SDL_SetStringProperty.html) and
  [SDL_GetStringProperty](SDL_GetStringProperty.html) operate on string
  types.
- [SDL_SetNumberProperty](SDL_SetNumberProperty.html) and
  [SDL_GetNumberProperty](SDL_GetNumberProperty.html) operate on signed
  64-bit integer types.
- [SDL_SetFloatProperty](SDL_SetFloatProperty.html) and
  [SDL_GetFloatProperty](SDL_GetFloatProperty.html) operate on floating
  point types.
- [SDL_SetBooleanProperty](SDL_SetBooleanProperty.html) and
  [SDL_GetBooleanProperty](SDL_GetBooleanProperty.html) operate on
  boolean types.

Properties can be removed from a group by using
[SDL_ClearProperty](SDL_ClearProperty.html).

## Functions

- [SDL_ClearProperty](SDL_ClearProperty.html)
- [SDL_CopyProperties](SDL_CopyProperties.html)
- [SDL_CreateProperties](SDL_CreateProperties.html)
- [SDL_DestroyProperties](SDL_DestroyProperties.html)
- [SDL_EnumerateProperties](SDL_EnumerateProperties.html)
- [SDL_GetBooleanProperty](SDL_GetBooleanProperty.html)
- [SDL_GetFloatProperty](SDL_GetFloatProperty.html)
- [SDL_GetGlobalProperties](SDL_GetGlobalProperties.html)
- [SDL_GetNumberProperty](SDL_GetNumberProperty.html)
- [SDL_GetPointerProperty](SDL_GetPointerProperty.html)
- [SDL_GetPropertyType](SDL_GetPropertyType.html)
- [SDL_GetStringProperty](SDL_GetStringProperty.html)
- [SDL_HasProperty](SDL_HasProperty.html)
- [SDL_LockProperties](SDL_LockProperties.html)
- [SDL_SetBooleanProperty](SDL_SetBooleanProperty.html)
- [SDL_SetFloatProperty](SDL_SetFloatProperty.html)
- [SDL_SetNumberProperty](SDL_SetNumberProperty.html)
- [SDL_SetPointerProperty](SDL_SetPointerProperty.html)
- [SDL_SetPointerPropertyWithCleanup](SDL_SetPointerPropertyWithCleanup.html)
- [SDL_SetStringProperty](SDL_SetStringProperty.html)
- [SDL_UnlockProperties](SDL_UnlockProperties.html)

## Datatypes

- [SDL_CleanupPropertyCallback](SDL_CleanupPropertyCallback.html)
- [SDL_EnumeratePropertiesCallback](SDL_EnumeratePropertiesCallback.html)
- [SDL_PropertiesID](SDL_PropertiesID.html)

## Structs

- (none.)

## Enums

- [SDL_PropertyType](SDL_PropertyType.html)

## Macros

- [SDL_PROP_NAME_STRING](SDL_PROP_NAME_STRING.html)

------------------------------------------------------------------------

[CategoryAPICategory](CategoryAPICategory.html)
