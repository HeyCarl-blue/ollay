package ollay

import "core:log"
import "core:testing"

render_dummy :: proc (ctx: ^Context) {
    for cmd in ctx.cmd_stack {
        #partial switch c in cmd {
        case Draw_Rect:
            log.infof("rect  x=%d y=%d w=%d h=%d  rgba(%d,%d,%d,%d)",
                c.rect.x, c.rect.y, c.rect.w, c.rect.h,
                c.color.r, c.color.g, c.color.b, c.color.a)
        case Draw_Text:
            log.infof("text  pos=(%d,%d)  %q", c.pos.x, c.pos.y, c.text)
        }
    }
}

@(test)
test_draw_rect :: proc (t: ^testing.T) {
    ctx := init()

    if window(&ctx, "prova", 0, 0, 800, 600) {
        defer end_window(&ctx)
        draw_rect(&ctx, Rect { 10, 20, 100, 50 }, RED)
        draw_rect(&ctx, Rect { 200, 300, 64, 64 }, BLUE)
        draw_rect(&ctx, Rect { 750, 550, 100, 100 }, GREEN)
    }

    testing.expect(t, len(ctx.cmd_stack) == 3, "expected 3 draw commands")

    log.info("--- dummy render output ---")
    render_dummy(&ctx)
    destroy(&ctx)
}
