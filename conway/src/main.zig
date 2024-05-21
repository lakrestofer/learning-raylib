// std lib imports
const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const time = std.time;
// external lib imports
const rl = @import("raylib.zig");
// std lib type imports
const Allocator = mem.Allocator;

// type definitions
const Options = struct {
    screen_width: u64,
    screen_height: u64,
};

pub const GraphicsState = struct {
    buffer_width: usize, // width in number of pixels
    buffer_height: usize, // height in number of pixels
    pixels: []rl.Color, // h * w size vector
    texture: rl.Texture2D, // the texture to draw to the screen
    allocator: Allocator,

    const Self = @This();
    pub fn init(buffer_width: usize, buffer_height: usize, allocator: Allocator) !Self {
        const pixels: []rl.Color = try allocator.alloc(
            rl.Color,
            buffer_width * buffer_height,
        );
        @memset(pixels, rl.WHITE);

        const image = rl.Image{
            .data = @ptrCast(pixels),
            .width = @intCast(buffer_width),
            .height = @intCast(buffer_height),
            .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
            .mipmaps = 1,
        };

        const texture = rl.LoadTextureFromImage(image);

        return Self{
            .pixels = pixels,
            .texture = texture,
            .buffer_width = buffer_width,
            .buffer_height = buffer_height,
            .allocator = allocator,
        };
    }
    pub fn render(self: Self, state: *State) void {
        std.debug.assert(state.grid.width < self.buffer_width);
        std.debug.assert(state.grid.height < self.buffer_height);
        // pixels per logical cell
        const gw = state.grid.width;
        const gh = state.grid.height;
        const cw: usize = self.buffer_width / gw;
        const ch: usize = self.buffer_height / gh;
        const bw = self.buffer_width;
        const bh = self.buffer_height;

        for (0..bh) |y| {
            for (0..bw) |x| {
                if (x == 0 or y == 0 or x == (bw - 1) or y == (bh - 1)) {
                    self.pixels[pos(x, y, bw, bh)] = rl.BLACK;
                    continue;
                }

                const cx = x / cw;
                const cy = y / ch;

                if (state.grid.grid[pos(cx, cy, gw, gh)]) {
                    self.pixels[pos(x, y, bw, bh)] = rl.BLACK;
                } else {
                    self.pixels[pos(x, y, bw, bh)] = rl.WHITE;
                }
            }
        }

        rl.UpdateTexture(self.texture, @ptrCast(self.pixels));
        rl.DrawText("up: +speed, down: -speed, space; pause, r: reset", @intCast(20), @intCast(state.options.screen_height - 40), 20, rl.GRAY);
    }

    pub fn deinit(self: Self) void {
        rl.UnloadTexture(self.texture);
        self.allocator.free(self.pixels);
    }
};

pub const State = struct {
    grid: Grid,
    options: Options,
    paused: bool,
    update_interval: i64, // time in ms between updates
    time_since_update: i64 = 0, // time in ms since last simulation update step
    should_quit: bool = false,

    const Self = @This();

    pub fn init(grid: Grid, update_interval: i64, options: Options) Self {
        return Self{
            .grid = grid,
            .options = options,
            .update_interval = update_interval,
            .paused = true,
        };
    }

    pub fn deinit(self: Self) void {
        self.grid.deinit();
    }

    pub fn quit(self: *Self) void {
        self.should_quit = true;
    }
};

fn handle_event(state: *State, clickable_grid: *ClickableGrid) void {
    if (rl.IsKeyPressed(rl.KEY_Q)) {
        state.should_quit = true;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_SPACE)) {
        state.paused = !state.paused;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_R)) {
        @memset(state.grid.grid, false);
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_UP)) {
        state.update_interval -= 50;
        return;
    }
    if (rl.IsKeyPressed(rl.KEY_DOWN)) {
        state.update_interval += 50;
        return;
    }
    if (state.update_interval <= 50) {
        state.update_interval = 50;
    }
    if (state.update_interval >= 1000) {
        state.update_interval = 1000;
    }

    const mp = rl.GetMousePosition();
    for (clickable_grid.grid, 0..) |cell, i| {
        if (rl.CheckCollisionPointRec(mp, cell)) {
            if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                state.grid.grid[i] = !state.grid.grid[i];
            }
            if (rl.IsMouseButtonDown(rl.MOUSE_BUTTON_LEFT)) {
                state.grid.grid[i] = true;
            }
        }
    }
}

fn progress_simulation_time(state: *State, delta: i64) void {
    // === update time ===
    state.time_since_update += delta;
    if (state.time_since_update <= state.update_interval) {
        return;
    }
    state.time_since_update = 0;
    // === update grid state ===
    // copy the board state into the workbuffer
    @memcpy(state.grid.workbuffer, state.grid.grid);

    const W = state.grid.width; // width
    const H = state.grid.height; // height
    const temp = state.grid.workbuffer;

    for (0..W) |y| {
        for (0..H) |x| {
            const i = pos(x, y, W, H);
            var nc: usize = 0;
            for (neighbors(x, y, W, H)) |j| if (temp[j]) {
                nc += 1;
            };
            update_cell(&state.grid.grid[i], nc);
        }
    }
}

// we perform some initialization logic
fn init(options: Options) void {
    // we want to exit the game ourselves
    rl.SetExitKey(0); // we disable having an implicit exit key
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.SetTargetFPS(20);
    rl.InitWindow(
        @intCast(options.screen_width),
        @intCast(options.screen_height),
        "raylib [core] example - basic window",
    ); // set window size
}
fn deinit() void {
    rl.CloseWindow();
}

fn draw(graphics: *GraphicsState, screen_width: usize, screen_height: usize) void {
    // signal to raylib when we start and stop drawing
    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.WHITE);
    rl.DrawTexture(
        graphics.texture,
        @intCast(screen_width / 2 - graphics.buffer_width / 2),
        @intCast(screen_height / 2 - graphics.buffer_height / 2),
        rl.WHITE,
    );
}
const ClickableGrid = struct {
    x: usize,
    y: usize,
    w: usize, // width and height in pixels
    h: usize,
    cw: usize, // width and height in cells
    ch: usize,
    outer: rl.Rectangle, // the outer bounding box
    grid: []rl.Rectangle, // the bounding box for each cell
    allocator: Allocator,

    const Self = @This();

    fn init(
        x: usize,
        y: usize,
        w: usize,
        h: usize,
        cw: usize,
        ch: usize,
        allocator: Allocator,
    ) !Self {
        const outer = rl.Rectangle{
            .x = @floatFromInt(x),
            .y = @floatFromInt(y),
            .width = @floatFromInt(w),
            .height = @floatFromInt(h),
        };

        const grid = try allocator.alloc(rl.Rectangle, cw * ch);
        const cpw = w / cw;
        const cph = h / ch;

        for (0..ch) |cy| {
            const cpy = cy * cph + y;
            for (0..ch) |cx| {
                // position in pixels
                const cpx = cx * cpw + x;
                grid[cy * cw + cx] = rl.Rectangle{
                    .x = @floatFromInt(cpx),
                    .y = @floatFromInt(cpy),
                    .width = @floatFromInt(cpw),
                    .height = @floatFromInt(cph),
                };
            }
        }

        return Self{
            .x = x,
            .y = y,
            .outer = outer,
            .grid = grid,
            .w = w,
            .h = h,
            .cw = cw,
            .ch = ch,
            .allocator = allocator,
        };
    }
    fn deinit(self: *Self) void {
        self.allocator.free(self.grid);
    }
};

const Grid = struct {
    grid: []bool,
    workbuffer: []bool,
    width: usize, // width and height in cells
    height: usize,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, width: usize, height: usize) !Self {
        const grid: []bool = try allocator.alloc(bool, width * height);
        const workbuffer: []bool = try allocator.alloc(bool, width * height);
        @memset(grid, false);

        return Self{
            .grid = grid,
            .workbuffer = workbuffer,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }
    fn deinit(self: Self) void {
        self.allocator.free(self.grid);
        self.allocator.free(self.workbuffer);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    const options = Options{
        .screen_width = 600,
        .screen_height = 600,
    };
    init(options); // loads gl context and starts window
    defer deinit();

    // init state
    const grid = try Grid.init(
        gpa_allocator,
        50,
        50,
    );
    var state = State.init(grid, 100, options);
    defer state.deinit();
    var graphics = try GraphicsState.init(
        options.screen_width - 100, // width of grid in pixels
        options.screen_height - 100, // height of grid in pixels
        gpa_allocator,
    );
    defer graphics.deinit();
    graphics.render(&state);
    var clickable_grid = try ClickableGrid.init(
        options.screen_width / 2 - graphics.buffer_width / 2,
        options.screen_width / 2 - graphics.buffer_width / 2,
        graphics.buffer_width,
        graphics.buffer_height,
        grid.width,
        grid.height,
        gpa_allocator,
    );
    defer clickable_grid.deinit();

    var previous = time.milliTimestamp();
    while (!rl.WindowShouldClose() and !state.should_quit) {
        // update simulation time
        const current = time.milliTimestamp();
        const delta = current - previous;
        previous = current;

        // update state based on input
        handle_event(&state, &clickable_grid);
        // update state based on elapsed time
        if (!state.paused) {
            progress_simulation_time(&state, delta);
        }

        // render
        graphics.render(&state);
        draw(&graphics, options.screen_width, options.screen_height);
    }
}

fn update_cell(cell: *bool, nc: usize) void {
    const alive: bool = cell.*;

    if (alive and nc < 2) {
        cell.* = false;
        return;
    }
    if (alive and nc == 2 and nc == 3) {
        cell.* = true;
        return;
    }
    if (alive and nc > 3) {
        cell.* = false;
        return;
    }

    if (!alive and nc == 3) {
        cell.* = true;
    }
}

fn pos(x: usize, y: usize, w: usize, h: usize) usize {
    const res = y * w + x;
    std.debug.assert(res < w * h);
    return res;
}

const Pos = struct { isize, isize };
const NEIGHBOR_DIFF = [8]Pos{
    .{ 1, 0 },
    .{ 1, 1 },
    .{ 0, 1 },
    .{ -1, 1 },
    .{ -1, 0 },
    .{ -1, -1 },
    .{ 0, -1 },
    .{ 1, -1 },
};

fn neighbors(
    x: usize,
    y: usize,
    W: usize,
    H: usize,
) [8]usize {
    var res: [8]usize = undefined;
    const ix: isize = @intCast(x);
    const iy: isize = @intCast(y);
    const iW: isize = @intCast(W);
    const iH: isize = @intCast(H);
    for (NEIGHBOR_DIFF, 0..) |diff, i| {
        const nx = @mod(ix + diff.@"0", iW);
        const ny = @mod(iy + diff.@"1", iH);
        res[i] = @intCast(ny * iW + nx);
    }
    return res;
}
