#ifndef WAYSPOT_WAYLAND_PROTOCOL_H
#define WAYSPOT_WAYLAND_PROTOCOL_H

#include <stdint.h>
#include <wayland-client.h>

/*
 * SDL owns viewporter interface data; Wayspot owns layer-shell interface data.
 * Keep generated protocol calls behind this boundary while Zig's incremental
 * ELF linker cannot resolve their definitions and references across members.
 * Delete this pair when the generated headers translate and link with the same
 * single-owner rule in both ordinary and incremental builds.
 */

struct wp_viewport;
struct wp_viewporter;
struct zwlr_layer_shell_v1;
struct zwlr_layer_surface_v1;

enum {
    WAYSPOT_LAYER_BACKGROUND = 0,
    WAYSPOT_KEYBOARD_NONE = 0,
    WAYSPOT_ANCHOR_TOP = 1,
    WAYSPOT_ANCHOR_BOTTOM = 2,
    WAYSPOT_ANCHOR_LEFT = 4,
    WAYSPOT_ANCHOR_RIGHT = 8,
};

struct wayspot_layer_listener {
    void (*configure)(void *, struct zwlr_layer_surface_v1 *, uint32_t, uint32_t, uint32_t);
    void (*closed)(void *, struct zwlr_layer_surface_v1 *);
};

const struct wl_interface *wayspot_viewporter_interface(void);
const struct wl_interface *wayspot_layer_shell_interface(void);

void wayspot_viewporter_destroy(struct wp_viewporter *);
struct wp_viewport *wayspot_viewporter_get_viewport(struct wp_viewporter *, struct wl_surface *);
void wayspot_viewport_destroy(struct wp_viewport *);
void wayspot_viewport_set_destination(struct wp_viewport *, int32_t, int32_t);

void wayspot_layer_shell_destroy(struct zwlr_layer_shell_v1 *);
struct zwlr_layer_surface_v1 *wayspot_layer_shell_get_surface(
    struct zwlr_layer_shell_v1 *,
    struct wl_surface *,
    struct wl_output *,
    uint32_t,
    const char *);
int wayspot_layer_surface_add_listener(
    struct zwlr_layer_surface_v1 *,
    const struct wayspot_layer_listener *,
    void *);
void wayspot_layer_surface_set_size(struct zwlr_layer_surface_v1 *, uint32_t, uint32_t);
void wayspot_layer_surface_set_anchor(struct zwlr_layer_surface_v1 *, uint32_t);
void wayspot_layer_surface_set_exclusive_zone(struct zwlr_layer_surface_v1 *, int32_t);
void wayspot_layer_surface_set_keyboard(struct zwlr_layer_surface_v1 *, uint32_t);
void wayspot_layer_surface_ack_configure(struct zwlr_layer_surface_v1 *, uint32_t);
void wayspot_layer_surface_destroy(struct zwlr_layer_surface_v1 *);

#endif
