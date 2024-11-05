const std = @import("std");

// const REDIS_TYPE_STRING: u8 = "+";
// const REDIS_TYPE_ERROR: u8 = "-";
// const REDIS_TYPE_INTEGER: u8 = ":";
// const REDIS_TYPE_BULK: u8 = "$";
// const REDIS_TYPE_ARRAY: u8 = "*";

pub const Value = struct {
    allocator: std.mem.Allocator,
    typ: []const u8,
    str: []const u8,
    num: u64,
    bulk: []u8,
    array: std.ArrayList(Value),

    pub fn init(allocator: std.mem.Allocator) Value {
        return Value{
            .allocator = allocator,
            .typ = "",
            .str = "",
            .num = 0,
            .bulk = "",
            .array = std.ArrayList(Value).init(allocator),
        };
    }

    pub fn deinit(self: Value) void {
        self.array.deinit();
    }

    pub fn marshal(self: Value) ![]const u8 {
        if (std.mem.eql(u8, self.typ, "string")) {
            return self.marshalString();
        } else {
            std.debug.print("no marshaller for typ {any}!\n", .{self.typ});
        }

        const default = [1]u8{1};

        return &default;
    }

    fn marshalString(self: Value) ![]const u8 {
        std.debug.print("Marshall string {any}!\n", .{self.typ});

        // const typePrefix = [_]u8{'+'};
        // const newLinePostfix = [_]u8{ '\r', '\n' };

        // const result = try std.mem.concat(self.allocator, u8, &.{ &typePrefix, self.str, &newLinePostfix });

        // std.debug.print("Marshall string result {any}!\n", .{result});

        // return result;

        const testResult = [_]u8{ '+', 'p', 'o', 'n', 'g', '\r', '\n' };

        return &testResult;
    }
};

pub const ResponseHandler = struct {
    allocator: std.mem.Allocator,
    stream: std.net.Stream,

    pub fn init(allocator: std.mem.Allocator, stream: std.net.Stream) ResponseHandler {
        return ResponseHandler{
            .allocator = allocator,
            .stream = stream,
        };
    }

    pub fn read(self: ResponseHandler) (anyerror!Value) {
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();

        // The first read byte indentifies the typ of a redis command.
        const readByte = try self.stream.reader().readByte();
        std.debug.print("[read] read byte {any}: {u}\n", .{ readByte, readByte });

        switch (readByte) {
            // 42 == "*"
            42 => {
                return self.readArray();
            },
            // 36 == "$"
            36 => {
                return self.readBulkString();
            },
            else => {
                std.debug.print("unkown type {any}\n", .{readByte});
            },
        }

        return Value.init(self.allocator);
    }

    fn readLine(self: ResponseHandler) anyerror![]u8 {
        var readBytesCounter: u64 = 0;
        var line = std.ArrayList(u8).init(self.allocator);
        defer line.deinit();

        // const line = try self.allocator.alloc(u64, 10);

        while (true) {
            const readByte = try self.stream.reader().readByte();
            std.debug.print("[readLine] read byte {any}: {u}\n", .{ readByte, readByte });

            try line.append(readByte);
            readBytesCounter += 1;

            const arraySize = line.items.len;
            const arrayPositionBeforeLineBreak = arraySize -% 2;

            if ((arraySize >= 2) and (line.items[arrayPositionBeforeLineBreak] == '\r')) {
                break;
            }
        }
        std.debug.print("[readLine] read {d} bytes\n", .{readBytesCounter});

        const arraySize = line.items.len;
        _ = line.orderedRemove(arraySize -% 1);

        const arraySize2 = line.items.len;
        _ = line.orderedRemove(arraySize2 -% 1);

        const lineReturn = line.toOwnedSlice();
        std.debug.print("[readLine] line: {any}\n", .{lineReturn});

        // return line without \r\n.
        return lineReturn;
    }

    fn readInteger(self: ResponseHandler) anyerror!u64 {
        // const readByte = try self.stream.reader().readByte();
        // const bytes = [1]u8{readByte};

        const readBytes = try self.readLine();

        const size = try std.fmt.parseInt(u64, readBytes, 10);
        std.debug.print("size of array is {d}\n", .{size});

        return size;
    }

    // readArray reads an array of RESP values.
    // Example:
    //
    //	*2 -> read size of array
    //	$5
    //	hello
    //	$5
    //	world
    //
    // The array has a length of 2 and contains two bulk strings: hello and world
    fn readArray(self: ResponseHandler) !Value {
        var value = Value.init(self.allocator);
        value.typ = "array";

        // read size of array
        const size = try self.readInteger();
        std.debug.print("size of array is {d}\n", .{size});

        for (size) |_| {
            const val = try self.read();

            _ = try value.array.append(val);
        }

        return value;
    }

    // readBulkString reads a bulk string from the reader.
    // Example:
    // $5 -> size of bulk string
    // hello
    // The bulk string has a length of 5 and contains the string hello.
    fn readBulkString(self: ResponseHandler) !Value {
        var value = Value.init(self.allocator);
        value.typ = "bulk";

        // read size of bulk string
        const size = try self.readInteger();

        const bulk = try self.allocator.alloc(u8, size);

        for (0..size) |i| {
            const readByte = try self.stream.reader().readByte();
            bulk[i] = readByte;
        }
        // consume \r\n
        _ = try self.stream.reader().readByte();
        _ = try self.stream.reader().readByte();

        value.bulk = bulk;

        return value;
    }

    pub fn write(self: ResponseHandler, v: Value) !void {
        const bytes = try v.marshal();

        std.debug.print("[write] bytes {any}", .{bytes});

        _ = try self.stream.write(bytes);
    }
};
