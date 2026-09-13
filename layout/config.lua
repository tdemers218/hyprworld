return {
    -- Keep a visible strip of neighboring cells around the focused window.
    peek_x = 48,
    peek_y = 48,
    gap_x = 12,
    gap_y = 12,

    -- Window dimensions are fractions of one grid cell. The largest preset
    -- still preserves the configured edge peeks.
    width_steps = { 0.50, 0.67, 0.85, 1.00 },
    height_steps = { 0.50, 0.67, 0.85, 1.00 },
    default_width_step = 3,
    default_height_step = 3,

    -- Zoom scales the entire workspace without changing individual tile sizes.
    zoom_steps = { 0.65, 0.80, 1.00, 1.25 },
    default_zoom_step = 3,
    max_zoom_margin = 10,

    -- First hover focuses immediately; suppress further hover focus briefly.
    mouse_focus_cooldown_ms = 550,
}
