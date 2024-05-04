const std = @import("std");
const rl = @import("raylib.zig");

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        {
            rl.ClearBackground(rl.RAYWHITE);

            rl.DrawText("Congrats! You created your first window!", 190, 200, 20, rl.LIGHTGRAY);
            rl.DrawFPS(10, 10);
        }
        rl.EndDrawing();
    }
}
