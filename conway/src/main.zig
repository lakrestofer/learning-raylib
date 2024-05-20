// std lib imports
const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
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
        const cw: usize = self.buffer_width / state.grid.width;
        const ch: usize = self.buffer_height / state.grid.height;
        const bw = self.buffer_width;
        const bh = self.buffer_height;

        for (0..bh) |y| {
            for (0..bw) |x| {
                if (x == 0 or y == 0 or x == (bw - 1) or y == (bh - 1)) {
                    self.pixels[y * bw + x] = rl.BLACK;
                    continue;
                }

                const cx = x / cw;
                const cy = y / ch;

                if (state.grid.grid[cy * state.grid.width + cx]) {
                    self.pixels[y * bw + x] = rl.BLACK;
                } else {
                    self.pixels[y * bh + x] = rl.WHITE;
                }
            }
        }

        // for (0..self.buffer_height) |y| {
        //     for (0..self.buffer_height) |x| {
        //         if ((x / cell_width + y / cell_height) % 2 == 0) {
        //             self.pixels[y * self.buffer_width + x] = rl.BLACK;
        //         } else {
        //             self.pixels[y * self.buffer_height + x] = rl.WHITE;
        //         }
        //     }
        // }

        rl.UpdateTexture(self.texture, @ptrCast(self.pixels));
    }

    pub fn deinit(self: Self) void {
        rl.UnloadTexture(self.texture);
        self.allocator.free(self.pixels);
    }
};

pub const State = struct {
    grid: Grid,
    color_counter: usize = 0,
    color: rl.Color = rl.RED,
    options: Options,
    should_quit: bool = false,

    const Self = @This();

    pub fn init(grid: Grid, graphics: GraphicsState, options: Options) Self {
        return Self{ .grid = grid, .graphics = graphics, .options = options };
    }

    pub fn deinit(self: Self) void {
        self.grid.deinit();
    }

    pub fn toggleColor(self: *Self) void {
        switch (self.color_counter) {
            0 => {
                self.color_counter = 1;
                self.color = rl.GREEN;
            },
            1 => {
                self.color_counter = 2;
                self.color = rl.BLUE;
            },
            2 => {
                self.color_counter = 0;
                self.color = rl.RED;
            },
        }
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

    const mp = rl.GetMousePosition();
    for (clickable_grid.grid, 0..) |cell, i| {
        if (rl.CheckCollisionPointRec(mp, cell) and rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT)) {
            if (builtin.mode == .Debug) {
                rl.TraceLog(rl.LOG_INFO, "clicked cell [%i]", @as(i64, @intCast(i)));
            }
            state.grid.grid[i] = !state.grid.grid[i];
        }
    }
}

// we perform some initialization logic
fn init(options: Options) void {
    // we want to exit the game ourselves
    rl.SetExitKey(0); // we disable having an implicit exit key
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.SetTargetFPS(60);
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
    width: usize, // width and height in cells
    height: usize,
    allocator: Allocator,

    const Self = @This();

    fn init(allocator: Allocator, width: usize, height: usize) !Self {
        const grid: []bool = try allocator.alloc(bool, width * height);
        @memset(grid, false);

        return Self{
            .grid = grid,
            .width = width,
            .height = height,
            .allocator = allocator,
        };
    }
    fn deinit(self: Self) void {
        self.allocator.free(self.grid);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const gpa_allocator = gpa.allocator();

    const options = Options{
        .screen_width = 500,
        .screen_height = 500,
    };
    init(options); // loads gl context and starts window
    defer deinit();

    // init state
    const grid = try Grid.init(
        gpa_allocator,
        50,
        50,
    );
    var state = State{
        .grid = grid,
        .options = options,
    };
    defer state.deinit();
    var graphics = try GraphicsState.init(
        350, // width of grid in pixels
        350, // height of grid in pixels
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

    while (!rl.WindowShouldClose() and !state.should_quit) {
        handle_event(&state, &clickable_grid); // update state
        graphics.render(&state);
        draw(&graphics, options.screen_width, options.screen_height);
    }
}
