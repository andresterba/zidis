const std = @import("std");
const resp = @import("resp.zig");
const commands = @import("handler.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // defer _ = gpa.deinit();
    // const allocator = gpa.allocator();

    const loopback = try std.net.Ip4Address.parse("127.0.0.1", 6379);
    const localhost = std.net.Address{ .in = loopback };
    var server = try localhost.listen(.{
        .reuse_port = true,
    });
    defer server.deinit();

    const addr = server.listen_address;
    std.debug.print("Listening on {}, access this port to end the program\n", .{addr.getPort()});

    var client = try server.accept();
    defer client.stream.close();

    std.debug.print("Connection received! {} is sending data.\n", .{client.address});

    const run: bool = true;

    var list = std.ArrayList(u8).init(allocator);
    defer list.deinit();

    const repl = resp.ResponseHandler.init(allocator, client.stream);
    const ch = commands.CommandHandler.init(allocator, client.stream);

    while (run) {
        const value = try repl.read();
        std.debug.print("Value {any}\n", .{value});

        if (!std.mem.eql(u8, value.typ, "array")) {
            std.debug.print("Invalid request, expected array", .{});
            continue;
        }

        if (value.array.items.len == 0) {
            std.debug.print("Invalid request, exepcted array length > 0", .{});
            continue;
        }

        const command = value.array.items[0].bulk;
        const args = value.array.items[1..];

        std.debug.print("Command {s}\n", .{command});
        std.debug.print("Args: {any}\n", .{args});

        const response = try ch.handleCommand(command, args);
        std.debug.print("Response.str {s}\n", .{response.str});
        _ = try repl.write(response);
    }
    // _ = try client.stream.write("+PONG\r\n");

    // const message = try client.stream.reader().readAllAlloc(allocator, 1024);
    // defer allocator.free(message);

    // std.debug.print("{} says:\n{s}\n", .{ client.address, message });
}
