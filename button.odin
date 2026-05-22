package ollay

button :: proc (
    ctx: ^Context,
    rect: Rect,
    style: Button_Style,
) -> bool {
    hovered := rect_contains(rect, ctx.input.mouse_pos)
    if hovered && ctx.input.mouse_pressed[0] {
        return true
    }

    return false
}