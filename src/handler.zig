const std = @import("std");
const resp = @import("resp.zig");

pub const CommandHandler = struct {
    allocator: std.mem.Allocator,
    stream: std.net.Stream,

    pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream) CommandHandler {
        return CommandHandler{
            .allocator = allocator,
            .stream = stream,
        };
    }

    pub fn deinit(self: CommandHandler) void {
        self.commands.deinit();
    }

    pub fn handleCommand(self: CommandHandler, command: []const u8, args: []resp.Value) !resp.Value {
        if (std.mem.eql(u8, command, "ping")) {
            return self.ping(args);
        }

        return resp.Value.init(self.allocator);
    }

    pub fn ping(self: CommandHandler, args: []resp.Value) resp.Value {
        if (args.len == 0) {
            return resp.Value{
                .allocator = undefined,
                .typ = "string",
                .str = "pong",
                .num = 0,
                .bulk = "",
                .array = std.ArrayList(resp.Value).init(self.allocator),
            };
        }

        return resp.Value{
            .allocator = undefined,
            .typ = "string",
            .str = args[0].bulk,
            .num = 0,
            .bulk = "",
            .array = std.ArrayList(resp.Value).init(self.allocator),
        };
    }
};
