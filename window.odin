package ollay

MIN_H :: 100
RESIZE_RECT_SIZE :: 15

draw_close_btn :: proc (ctx: ^Context, container: ^Container, btn_size: int, rect: Rect, style: Button_Style) {
    hovered := rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed[0] {
        container.closed = true
    }
    btn_bg := hovered ? style.hover_bg_color : style.bg_color
    draw_rect(ctx, rect, btn_bg)
    draw_border(ctx, rect, style.border_color, style.border_size)

    cx   := rect.x + rect.w / 2
    cy   := rect.y + rect.h / 2
    half := btn_size / 4
    draw_line(ctx, {cx - half, cy - half}, {cx + half, cy + half}, style.text_color)
    draw_line(ctx, {cx + half, cy - half}, {cx - half, cy + half}, style.text_color)
}

draw_minimize_btn :: proc (ctx: ^Context, container: ^Container, btn_size: int, rect: Rect, style: Button_Style) {
    hovered := rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed[0] {
        container.minimized = true
    }
    btn_bg := hovered ? style.hover_bg_color : style.bg_color
    draw_rect(ctx, rect, btn_bg)
    draw_border(ctx, rect, style.border_color, style.border_size)

    cx   := rect.x + rect.w / 2
    cy   := rect.y + rect.h / 2
    half := btn_size / 4
    draw_line(ctx, {cx - half, cy + half}, {cx + half, cy + half}, style.text_color)
}

draw_maximize_btn :: proc (ctx: ^Context, container: ^Container, btn_size: int, rect: Rect, style: Button_Style) {
    hovered := rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed[0] {
        container.maximized = !container.maximized
    }
    btn_bg := hovered ? style.hover_bg_color : style.bg_color
    draw_rect(ctx, rect, btn_bg)
    draw_border(ctx, rect, style.border_color, style.border_size)

    cx   := rect.x + btn_size / 4 + 1
    cy   := rect.y + btn_size / 4 + 1
    half := btn_size / 2
    draw_frame(ctx, Rect { cx, cy, half, half }, style.text_color, 1)
}

window :: proc (
    ctx: ^Context,
    title: string,
    x := 0, y := 0, w := 800, h := 600,
    closable := true,
    minimizable := true,
    maximizable := true,
    resizable := true,
    draggable := true,
    style := DEFAULT_WINDOW_STYLE
) -> bool {
    id := get_id(transmute([]byte)title)
    push(&ctx.id_stack, id)

    clip := peek(ctx.clip_stack)

    idx, found := pool_get(ctx.cont_pool[:], id)
    if !found {
        ctx.last_zindex += 1
        idx = pool_alloc(ctx.cont_pool[:], ctx.curr_frame, id, Container {
            rect    = Rect{
                clip.x + x,
                clip.y + y,
                min(w, clip.x + x + clip.w),
                min(h, clip.y + y + clip.h)
            },
            unmaximized_rect = Rect{x, y, w, h},
            zindex  = ctx.last_zindex,
        })
    } else {
        cont := ctx.cont_pool[idx].item
        if cont.closed || cont.minimized { return false }
        pool_update(ctx.cont_pool[:], ctx.curr_frame, idx)
    }

    textbox: [2]int
    if ctx.measure_text != nil {
        textbox = ctx.measure_text(style.titlebar_font, title)
    }

    btn_size := style.titlebar_size - 2 * style.titlebar_margin

    min_w := textbox.x
    min_h := 100
    if closable { min_w += btn_size + (style.border_size + style.titlebar_margin) * 2 }
    if minimizable { min_w += btn_size + (style.border_size + style.titlebar_margin) * 2 }
    if maximizable { min_w += btn_size + (style.border_size + style.titlebar_margin) * 2 }

    container := &ctx.cont_pool[idx].item
    if !container.maximized {
        container.unmaximized_rect.w = max(container.unmaximized_rect.w, min_w)
    }
    maximized_rect := Rect { clip.x + style.border_size, clip.y + style.border_size, clip.w - style.border_size, clip.h - style.border_size }
    container.rect = container.maximized ? maximized_rect : container.unmaximized_rect
    rect      := container.rect

    begin_layer(ctx, container)

    // Draw container
    draw_rect(ctx, rect, style.container_color)

    // Draw body
    body := Rect { rect.x + 1, rect.y + style.titlebar_size + 1, rect.w - 2, rect.h - style.titlebar_size - 2 }
    draw_rect(ctx, body, style.bg_color)
    defer push(&ctx.clip_stack, body)

    // Draw borders
    draw_border(ctx, body, BLACK, 1)
    draw_border(ctx, rect, style.border_color, style.border_size)

    // Drag on titlebar
    titlebar := Rect{rect.x, rect.y, rect.w, style.titlebar_size}
    if rect_contains(rect, ctx.input.mouse_pos) { ctx.hovered = id }
    
    if ctx.focused == 0 && !container.resize_focus && rect_contains(titlebar, ctx.input.mouse_pos) && ctx.input.mouse_pressed[0] {
        container.drag_focus = true
        ctx.focused = id
    }
    if draggable && container.drag_focus {
        if ctx.input.mouse_down[0] {
            ctx.focused = id
            dest_x := rect.x + ctx.input.mouse_delta.x
            min_x  := clip.x
            max_x  := clip.x + clip.w - rect.w

            dest_y := rect.y + ctx.input.mouse_delta.y
            min_y  := clip.y
            max_y  := clip.y + clip.h - rect.h

            rect.x = clamp(dest_x, min_x, max_x)
            rect.y = clamp(dest_y, min_y, max_y)

            container.rect = rect
        } else {
            container.drag_focus = false
        }
    }

    // Resize on lower-right rect
    resize_rect := Rect { rect.x + rect.w - style.border_size - RESIZE_RECT_SIZE, rect.y + rect.h - style.border_size - RESIZE_RECT_SIZE, RESIZE_RECT_SIZE, RESIZE_RECT_SIZE }
    if ctx.focused == 0 && !container.drag_focus && rect_contains(resize_rect, ctx.input.mouse_pos) && ctx.input.mouse_pressed[0] {
        container.resize_focus = true
        ctx.focused = id
    }
    if resizable {
        // Render oblique lines
        x_inc := resize_rect.w / 3
        y_inc := resize_rect.h / 3

        p00: [2]int = { resize_rect.x, resize_rect.y + resize_rect.h - style.border_size - 1 }
        p01: [2]int = { resize_rect.x + resize_rect.w - style.border_size - 1, resize_rect.y }
        draw_line(ctx, p00, p01, style.border_color)

        p10: [2]int = { p00.x + x_inc, p00.y }
        p11: [2]int = { p01.x, p01.y + y_inc }
        draw_line(ctx, p10, p11, style.border_color)

        p20: [2]int = { p10.x + x_inc, p10.y }
        p21: [2]int = { p11.x, p11.y + y_inc }
        draw_line(ctx, p20, p21, style.border_color)
    }
    if resizable && container.resize_focus {
        if ctx.input.mouse_down[0] {
            ctx.focused = id
            low_dx := min_w - rect.w
            low_dy := min_h - rect.h
            up_dx  := clip.x + clip.w - rect.x - rect.w
            up_dy  := clip.y + clip.h - rect.y - rect.h

            dx := min(max(ctx.input.mouse_delta.x, low_dx), up_dx)
            dy := min(max(ctx.input.mouse_delta.y, low_dy), up_dy)

            if dx != 0 || dy != 0 { container.maximized = false }

            stretch_rect(&rect, dx, dy)
            container.rect = rect
        } else {
            container.resize_focus = false
        }
    }

    if !container.maximized { container.unmaximized_rect = rect }

    // Draw titlebar
    text_rect := Rect { 0, 0, textbox[0], textbox[1] }
    text_x := titlebar.x + style.titlebar_margin
    text_y := center_vertically(text_rect, titlebar)

    title_clip := Rect { rect.x + style.titlebar_margin, rect.y, rect.w - 2 * style.titlebar_margin, style.titlebar_size }
    set_clip(ctx, title_clip)
    draw_text(ctx, {text_x, text_y}, title, style.titlebar_text_color, style.titlebar_font)
    set_clip(ctx, Rect{})

    // Draw titlebar buttons
    btn_rect := Rect{
        rect.x + rect.w - style.titlebar_margin - btn_size,
        rect.y + style.titlebar_margin,
        btn_size, btn_size,
    }
    if closable {
        draw_close_btn(ctx, container, btn_size, btn_rect, style.close_btn_style)
        btn_rect.x -= btn_size + style.titlebar_margin
    }

    if maximizable {
        draw_maximize_btn(ctx, container, btn_size, btn_rect, style.maximize_btn_style)
        btn_rect.x -= btn_size + style.titlebar_margin
    }

    if resizable {
        draw_minimize_btn(ctx, container, btn_size, btn_rect, style.minimize_btn_style)
        btn_rect.x -= btn_size + style.titlebar_margin
    }

    return true
}

end_window :: proc (ctx: ^Context) {
    pop(&ctx.id_stack)
    pop(&ctx.clip_stack)
    end_layer(ctx)
}
