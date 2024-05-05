const std = @import("std");
const rl = @import("raylib.zig");

const Direction = enum { up, down, left, right };

const Options = struct {
    screen_width: u64,
    screen_height: u64,
};

pub const State = struct {
    ball_position: rl.Vector2,
    should_quit: bool = false,

    const Self = @This();

    pub fn init(options: *const Options) Self {
        return Self{
            .ball_position = rl.Vector2{
                .x = @floatFromInt(options.screen_width / 2),
                .y = @floatFromInt(options.screen_height / 2),
            },
        };
    }

    pub fn quit(self: *Self) void {
        self.should_quit = true;
    }
    pub fn move_ball(self: *Self, dir: Direction) void {
        switch (dir) {
            Direction.up => self.ball_position.y -= 10,
            Direction.down => self.ball_position.y += 10,
            Direction.left => self.ball_position.x -= 10,
            Direction.right => self.ball_position.x += 10,
        }
    }
};

fn handle_key_event(state: *State) void {
    if (rl.IsKeyPressed(rl.KEY_Q)) {
        state.quit();
        return;
    }

    if (rl.IsKeyPressed(rl.KEY_UP) or rl.IsKeyPressedRepeat(rl.KEY_UP)) state.move_ball(Direction.up);
    if (rl.IsKeyPressed(rl.KEY_DOWN) or rl.IsKeyPressedRepeat(rl.KEY_DOWN)) state.move_ball(Direction.down);
    if (rl.IsKeyPressed(rl.KEY_LEFT) or rl.IsKeyPressedRepeat(rl.KEY_LEFT)) state.move_ball(Direction.left);
    if (rl.IsKeyPressed(rl.KEY_RIGHT) or rl.IsKeyPressedRepeat(rl.KEY_RIGHT)) state.move_ball(Direction.right);
}

// we perform some initialization logic
fn init(options: *const Options) void {
    // we want to exit the game ourselves
    rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.SetExitKey(rl.KEY_NULL); // we disable having an implicit exit key
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

fn draw(state: *State) void {
    rl.BeginDrawing();
    {
        rl.ClearBackground(rl.RAYWHITE);

        rl.DrawText("move the ball with arrow keys", 20, 10, 20, rl.DARKGRAY);
        rl.DrawCircleV(
            state.ball_position,
            50,
            rl.MAROON,
        );
    }
    rl.EndDrawing();
}

pub fn main() !void {
    const options = Options{
        .screen_width = 800,
        .screen_height = 450,
    };

    init(&options);
    defer deinit();

    var state = State.init(&options);

    while (!rl.WindowShouldClose() and !state.should_quit) {
        handle_key_event(&state);
        draw(&state);
    }
}
