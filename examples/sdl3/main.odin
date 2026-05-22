package main

import "core:fmt"
import "vendor:sdl3"
import ollay "../.."

main :: proc() {
    sdl_err :: proc() -> string { return string(sdl3.GetError()) }

    if !sdl3.Init({.VIDEO}) { panic(sdl_err()) }
    defer sdl3.Quit()

    window := sdl3.CreateWindow("ollay sdl3", 800, 600, {
        .RESIZABLE
    })
    if window == nil { panic(sdl_err()) }
    defer sdl3.DestroyWindow(window)

    renderer := sdl3.CreateRenderer(window, nil)
    if renderer == nil { panic(sdl_err()) }
    defer sdl3.DestroyRenderer(renderer)

    ctx := ollay.init()
    ctx.measure_text = measure_text

    style := ollay.DEFAULT_WINDOW_STYLE
    style.titlebar_font = load_font(`C:\Windows\Fonts\segoeui.ttf`, 16)
    style.close_btn_style.font = load_font(`C:\Windows\Fonts\georgia.ttf`, 12)
    defer unload_font(style.close_btn_style.font)
    defer unload_font(style.titlebar_font)

    running := true
    for running {
        mx, my: f32
        _ = sdl3.GetMouseState(&mx, &my)
        input := ollay.Input{
            mouse_pos  = {int(mx), int(my)},
            mouse_down = ctx.input.mouse_down,
        }

        event: sdl3.Event
        for sdl3.PollEvent(&event) {
            #partial switch event.type {
            case .QUIT:
                running = false
            case .MOUSE_BUTTON_DOWN:
                input.mouse_down[event.button.button - 1]    = true
                input.mouse_pressed[event.button.button - 1] = true
            case .MOUSE_BUTTON_UP:
                input.mouse_down[event.button.button - 1] = false
            }
        }

        ollay.begin_frame(&ctx, input)
        width, height: i32
        if !sdl3.GetWindowSizeInPixels(window, &width, &height) { panic(sdl_err()) }
        ollay.push(&ctx.clip_stack, ollay.Rect { 0, 0, int(width), int(height) })
        defer ollay.pop(&ctx.clip_stack)

        fmt.println(ctx.hover_layer)

        if ollay.window(&ctx, "test title", 0, 0, 300, 200, style = style) {
            // if ollay.window(&ctx, "window inside window", 0, 0, 30, 30) { defer ollay.end_window(&ctx) }
            defer ollay.end_window(&ctx)
        }

        if ollay.window(&ctx, "test title 2", 320, 10, 100, 300, closable = false, maximizable = false, style = style) {
            defer ollay.end_window(&ctx)
        }

        sdl3.SetRenderDrawColor(renderer, 40, 40, 40, 255)
        sdl3.RenderClear(renderer)

        for cmd in ctx.cmd_stack {
            switch c in cmd {
            case ollay.Draw_Rect:
                sdl3.SetRenderDrawColor(renderer, c.color.r, c.color.g, c.color.b, c.color.a)
                r := sdl3.FRect{f32(c.rect.x), f32(c.rect.y), f32(c.rect.w), f32(c.rect.h)}
                sdl3.RenderFillRect(renderer, &r)
            case ollay.Draw_Text:
                render_text(renderer, c)
            case ollay.Draw_Line:
                sdl3.SetRenderDrawColor(renderer, c.color.r, c.color.g, c.color.b, c.color.a)
                sdl3.RenderLine(renderer, f32(c.p1.x), f32(c.p1.y), f32(c.p2.x), f32(c.p2.y))
            case ollay.Draw_Clip:
                if c.rect.w > 0 && c.rect.h > 0 {
                    r := sdl3.Rect{i32(c.rect.x), i32(c.rect.y), i32(c.rect.w), i32(c.rect.h)}
                    sdl3.SetRenderClipRect(renderer, &r)
                } else {
                    sdl3.SetRenderClipRect(renderer, nil)
                }
            }
        }

        sdl3.RenderPresent(renderer)
    }
}
