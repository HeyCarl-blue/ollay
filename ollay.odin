package ollay

// ======= CONSTS ===========
CONTAINER_POOL_SIZE       :: 100
CONTAINER_STACK_SIZE      :: 100
LAYOUT_STACK_SIZE         :: 100
CLIP_STACK_SIZE           :: 100
LAYER_STACK_SIZE          :: 100
ID_STACK_SIZE             :: 100
COMMAND_LIST_STACK_SIZE   :: 1024
COMMAND_STACK_SIZE        :: 1024

// ======= FONTS =============
Font :: distinct rawptr

// ========== STACK ==========
Stack :: struct($T: typeid, $N: int) {
    idx:    int,
    items:  [N]T
}
push :: proc (stack: ^Stack($T, $N), item: T) {
    if stack.idx == len(stack.items) { panic("Can't push the stack. Reached the end") }
    stack.items[stack.idx] = item
    stack.idx += 1
}
pop :: proc (stack: ^Stack($T, $N)) -> T {
    if stack.idx == 0 { panic("Can't pop the stack. Reached the end") }
    stack.idx -= 1;
    return stack.items[stack.idx]
}
peek :: proc (stack: Stack($T, $N)) -> T {
    if stack.idx == 0 { panic("Can't peek the stack. It is empty") }
    return stack.items[stack.idx - 1]
}
clear :: proc (stack: ^Stack($T, $N)) {
    stack.idx = 0
}

// =========== HEAP ===========

// ========== COLORS ==========
Color :: [4]u8

WHITE   :: Color { 255, 255, 255, 255 }
RED     :: Color { 255,   0,   0, 255 }
GREEN   :: Color {   0, 255,   0, 255 }
BLUE    :: Color {   0,   0, 255, 255 }
BLACK   :: Color {   0,   0,   0, 255 }

@(private)
_hex_digit :: proc(c: byte) -> u8 {
    switch c {
    case '0'..='9': return c - '0'
    case 'a'..='f': return c - 'a' + 10
    case 'A'..='F': return c - 'A' + 10
    }
    panic("hex_color: invalid hex character")
}
hex_color :: proc(s: string) -> Color {
    if len(s) == 0 || s[0] != '#' do panic("hex_color: missing '#'")
    h := s[1:]

    nib :: #force_inline proc(c: byte) -> u8 { return _hex_digit(c) }
    byt :: #force_inline proc(hi, lo: byte) -> u8 { return _hex_digit(hi) << 4 | _hex_digit(lo) }

    switch len(h) {
    case 1:
        v := nib(h[0]) * 17
        return Color{v, v, v, 255}
    case 3:
        return Color{nib(h[0]) * 17, nib(h[1]) * 17, nib(h[2]) * 17, 255}
    case 4:
        return Color{nib(h[0]) * 17, nib(h[1]) * 17, nib(h[2]) * 17, nib(h[3]) * 17}
    case 6:
        return Color{byt(h[0], h[1]), byt(h[2], h[3]), byt(h[4], h[5]), 255}
    case 8:
        return Color{byt(h[0], h[1]), byt(h[2], h[3]), byt(h[4], h[5]), byt(h[6], h[7])}
    }
    panic("hex_color: unsupported length")
}

// ========== COMMANDS =======
Draw_Rect :: struct { rect: Rect, color: Color }
// Draw_Rounded_Rect :: struct { rect: Rect, color: Color, radiuses: [4]int }
Draw_Text :: struct { pos: [2]int, text: string, color: Color, font: Font }
Draw_Clip :: struct { rect: Rect }
Draw_Line :: struct { p1, p2: [2]int, color: Color }
Cmd  :: union  { Draw_Rect, Draw_Text, Draw_Clip, Draw_Line }

draw_rect :: proc (ctx: ^Context, rect: Rect, color: Color) {
    r := rect_intersection(rect, peek(ctx.clip_stack))
    append(&ctx.cmd_stack, Draw_Rect { r, color })
}
draw_text :: proc (ctx: ^Context, pos: [2]int, text: string, color: Color, font: Font) {
    append(&ctx.cmd_stack, Draw_Text { pos, text, color, font })
}
draw_line :: proc (ctx: ^Context, p1, p2: [2]int, color: Color) {
    append(&ctx.cmd_stack, Draw_Line { p1, p2, color })
}
set_clip :: proc (ctx: ^Context, rect: Rect) {
    append(&ctx.cmd_stack, Draw_Clip { rect })
}
draw_frame :: proc (ctx: ^Context, rect: Rect, color: Color, border_size: int) {
    draw_rect(ctx, Rect { rect.x + border_size, rect.y, rect.w - 2 * border_size, border_size }, color)
    draw_rect(ctx, Rect { rect.x + border_size, rect.y + rect.h - border_size, rect.w - 2 * border_size, border_size }, color)
    draw_rect(ctx, Rect { rect.x, rect.y, border_size, rect.h }, color)
    draw_rect(ctx, Rect { rect.x + rect.w - border_size, rect.y, border_size, rect.h }, color)
}
draw_border :: proc (ctx: ^Context, rect: Rect, color: Color, border_size: int) {
    if border_size > 0 {
        draw_frame(ctx, expand_rect(rect, border_size), color, border_size)
    }
} 

// ========== ID ==========
Id :: u64
@(optimization_mode="favor_size")
get_id :: proc (data: []byte, seed := u64(0xcbf29ce484222325)) -> Id {
	h: u64 = seed
	for b in data {
		h = (h ~ u64(b)) * 0x100000001b3
	}
	return h
}

// ========== RECT ==========
Rect :: struct { x, y, w, h: int }
rect_contains :: proc (r: Rect, pos: [2]int) -> bool {
    return pos.x >= r.x && pos.x < r.x + r.w && pos.y >= r.y && pos.y < r.y + r.h
}
rect_intersection :: proc (r1, r2: Rect) -> Rect {
    x1 := max(r1.x, r2.x)
    y1 := max(r1.y, r2.y)
    x2 := min(r1.x + r1.w, r2.x + r2.w)
    y2 := min(r1.y + r1.h, r2.y + r2.h)
    if x2 < x1 { x2 = x1 }
    if y2 < y1 { y2 = y1 }
    return Rect { x1, y1, x2 - x1, y2 - y1 }
}
expand_rect :: proc (rect: Rect, n: int) -> Rect {
    return Rect { rect.x - n/2, rect.y - n/2, rect.w + n/2, rect.h + n/2 }
}
stretch_rect :: proc (rect: ^Rect, dx: int, dy: int) {
    rect.w += dx
    rect.h += dy
}
center_vertically :: proc (child: Rect, parent: Rect) -> int {
    return parent.y + abs(parent.h - child.h) / 2
}
center_horizontally :: proc (child: Rect, parent: Rect) -> int {
    return parent.x + abs(parent.w - child.w) / 2
}
center :: proc (child: Rect, parent: Rect) -> [2]int {
    return {
        parent.x + abs(parent.w - child.w) / 2,
        parent.y + abs(parent.h - child.h) / 2
    }
}

// ========== POOL ==========
Pool_Item :: struct($T: typeid) { id: Id, last_update: int, item: T }
pool_get :: proc (pool: []Pool_Item($T), id: Id) -> (int, bool) {
    for item, idx in pool {
        if item.id == id { return idx, true }
    }
    return -1, false
}
pool_alloc :: proc (pool: []Pool_Item($T), current_frame: int, id: Id, item: T) -> int {
    oldest_idx: int
    oldest_frame := current_frame
    for item, idx in pool {
        if item.last_update < oldest_frame { oldest_idx = idx }
    }
    pool[oldest_idx] = Pool_Item(T) { id, current_frame, item }
    return oldest_idx
}
pool_update :: proc (pool: []Pool_Item($T), current_frame: int, idx: int) { pool[idx].last_update = current_frame }

// ========== INPUT ==========
Input :: struct {
    mouse_pos:      [2]int,
    mouse_delta:    [2]int,
    mouse_down:     [3]bool,
    mouse_pressed:  [3]bool,
    scroll:         [2]bool,
}

// ========== CONTAINER ==========
Container :: struct {
    rect:   Rect,
    unmaximized_rect: Rect,
    closed: bool,
    minimized: bool,
    maximized: bool,
    drag_focus: bool,
    resize_focus: bool,
}
is_visible :: proc (container: Container) -> bool {
    return !(container.minimized || container.closed)
}

// ========== LAYER ==========
Layer :: struct {
    container: Container,
    zindex: int,
}
bring_into_focus :: proc (ctx: ^Context, layer: ^Layer) {
    ctx.last_zindex += 1
    layer.zindex = ctx.last_zindex
}

// ========== LAYOUT ==========
Row_Layout :: struct {
    rect: Rect,
}

Layout :: union {
    Row_Layout
}

// ========== STYLE ==========
Window_Style :: struct {
    // VALUES
    border_size:        int,
    titlebar_size:      int,
    titlebar_margin:    int,
    // COLORS
    bg_color:            Color,
    border_color:        Color,
    container_color:     Color,
    titlebar_text_color: Color,
    // FONTS
    titlebar_font: Font,
    // STYLES
    close_btn_style:    Button_Style,
    maximize_btn_style: Button_Style,
    minimize_btn_style: Button_Style
}

DEFAULT_WINDOW_STYLE :: Window_Style {
    border_size     = 1,
    titlebar_size   = 25,
    titlebar_margin = 5,

    bg_color            = WHITE,
    container_color     = Color { 247, 135,  98, 255 },
    border_color        = Color { 247, 135,  98, 255 },
    titlebar_text_color = BLACK,

    close_btn_style    = DEFAULT_WINDOW_CLOSE_BUTTON_STYLE,
    maximize_btn_style = DEFAULT_WINDOW_MINIMIZE_BUTTON_STYLE,
    minimize_btn_style = DEFAULT_WINDOW_MINIMIZE_BUTTON_STYLE
}

Button_Style :: struct {
    // VALUES
    border_size:    int,
    padding:        int,
    // COLORS
    text_color:     Color,
    border_color:   Color,
    bg_color:       Color,
    hover_bg_color: Color,
    // FONTS
    font:           Font,
}

DEFAULT_WINDOW_CLOSE_BUTTON_STYLE :: Button_Style {
    border_size    = 1,
    padding        = 5,
    text_color     = BLACK,
    border_color   = BLACK,
    bg_color       = WHITE,
    hover_bg_color = Color { 186, 53, 38, 255 },
}

DEFAULT_WINDOW_MINIMIZE_BUTTON_STYLE :: Button_Style {
    border_size    = 1,
    padding        = 5,
    text_color     = BLACK,
    border_color   = BLACK,
    bg_color       = WHITE,
    hover_bg_color = Color { 92, 51, 251, 255 },
}

// ========== CONTEXT ==========
Context :: struct {
    // CALLBACKS
    measure_text:   proc(font: Font, text: string) -> [2]int,
    // VARS
    input:          Input,
    hovered:        Id,
    focused:        Id,
    curr_frame:     u32,
    last_zindex:    int,
    curr_zindex:    int,
    hover_layer:    Container,
    focus_layer:    Container,
    // STACKS
    cmd_stack:    Stack(Cmd_List, COMMAND_STACK_SIZE),
    clip_stack:   Stack(Rect, CLIP_STACK_SIZE),
    id_stack:     Stack(Id, ID_STACK_SIZE),
    cont_stack:   Stack(Container, CONTAINER_STACK_SIZE),
    layout_stack: Stack(Layout, LAYOUT_STACK_SIZE),
    layer_stack:  Stack(Layer, LAYER_STACK_SIZE),
    // POOLS
    cont_pool: [CONTAINER_POOL_SIZE]Pool_Item(Container)
}
init :: proc () -> Context {
    return Context {

    }
}
begin_frame :: proc (ctx: ^Context, input: Input) {
    clear(&ctx.cmd_stack)
    ctx.clip_stack.idx = 0
    ctx.id_stack.idx   = 0
    ctx.focused        = 0
    input := input
    input.mouse_delta = input.mouse_pos - ctx.input.mouse_pos
    ctx.input = input
    ctx.curr_frame += 1
}
begin_layer :: proc (ctx: ^Context, layer: ^Layer) {
    push(&ctx.cont_stack, layer.container)
    push(&ctx.layer_stack, layer^)

    push(&ctx.clip_stack, layer.container.rect)
}
end_layer :: proc (ctx: ^Context) {
    pop(&ctx.cont_stack)
    pop(&ctx.layer_stack)
    pop(&ctx.clip_stack)
}
