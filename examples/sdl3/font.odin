package main

import "core:strings"
import "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import ollay "../.."

load_font :: proc(path: string, size: f32) -> ollay.Font {
    if !ttf.Init() { panic(string(sdl3.GetError())) }
    cpath := strings.clone_to_cstring(path, context.temp_allocator)
    font := ttf.OpenFont(cpath, size)
    if font == nil { panic(string(sdl3.GetError())) }
    return ollay.Font(font)
}

unload_font :: proc(font: ollay.Font) {
    ttf.CloseFont((^ttf.Font)(font))
}

measure_text :: proc(font: ollay.Font, text: string) -> [2]int {
    if font == nil {
        return {len(text) * sdl3.DEBUG_TEXT_FONT_CHARACTER_SIZE, sdl3.DEBUG_TEXT_FONT_CHARACTER_SIZE}
    }
    w, h: i32
    ctext := strings.clone_to_cstring(text, context.temp_allocator)
    ttf.GetStringSize((^ttf.Font)(font), ctext, 0, &w, &h)
    return {int(w), int(h)}
}

render_text :: proc(renderer: ^sdl3.Renderer, cmd: ollay.Draw_Text) {
    ctext := strings.clone_to_cstring(cmd.text, context.temp_allocator)
    if cmd.font == nil {
        sdl3.SetRenderDrawColor(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
        sdl3.RenderDebugText(renderer, f32(cmd.pos.x), f32(cmd.pos.y), ctext)
        return
    }
    fg := sdl3.Color{cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a}
    surface := ttf.RenderText_Blended((^ttf.Font)(cmd.font), ctext, 0, fg)
    if surface == nil { return }
    w, h := surface.w, surface.h
    texture := sdl3.CreateTextureFromSurface(renderer, surface)
    sdl3.DestroySurface(surface)
    if texture == nil { return }
    defer sdl3.DestroyTexture(texture)
    dst := sdl3.FRect{f32(cmd.pos.x), f32(cmd.pos.y), f32(w), f32(h)}
    sdl3.RenderTexture(renderer, texture, nil, &dst)
}
