// SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
// SPDX-License-Identifier: MIT

//! What the consumer's bindings contain, decided at compile time.
//!
//! `present` is built against whatever protocols the consumer generated, and
//! the core protocol and `xdg-shell` are all it can count on. The dma-buf and
//! explicit sync support needs `linux-dmabuf-v1` and `linux-drm-syncobj-v1`
//! as well, so the code that names their interfaces sits behind these, and
//! a consumer that never asked for them still compiles.

const protocols = @import("wayland-protocols");

/// `zwp_linux_dmabuf_v1` is in the bindings: `stable/linux-dmabuf/linux-dmabuf-v1.xml`.
pub const has_dmabuf = @hasDecl(protocols, "zwp") and @hasDecl(protocols.zwp, "LinuxDmabufV1");

/// `wp_linux_drm_syncobj_manager_v1` is in the bindings:
/// `staging/linux-drm-syncobj/linux-drm-syncobj-v1.xml`.
pub const has_syncobj = @hasDecl(protocols, "wp") and @hasDecl(protocols.wp, "LinuxDrmSyncobjManagerV1");
