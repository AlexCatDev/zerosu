//Importing same file in other file results in different types lol

//Player.zig:
//const c = @cInclude("SDL2/SDL.h");

//Other.zig
//const c = @cInclude("SDL2/SDL.h");
//Player.c.SDL_EVENT // Other.c.SDL_EVENT are different types XDDDD

//Including CImports.zig makes them share the same c type ig
pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("GLES2/gl2.h");
});
