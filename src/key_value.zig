const std = @import("std");
const t = @import("t.zig");

const mem = std.mem;
const ascii = std.ascii;
const Allocator = std.mem.Allocator;

pub const KeyValue = struct {
	len: usize,
	names: [][]u8,
	values: [][]const u8,
	allocator: Allocator,

	const Self = @This();

	pub fn init(allocator: Allocator, max: usize) !Self {
		const names = try allocator.alloc([]u8, max);
		const values = try allocator.alloc([]const u8, max);
		return Self{
			.len = 0,
			.names = names,
			.values = values,
			.allocator = allocator,
		};
	}

	pub fn deinit(self: *Self) void {
		self.allocator.free(self.names);
		self.allocator.free(self.values);
	}

	pub fn add(self: *Self, name: []u8, value: []const u8) void {
		const len = self.len;
		var names = self.names;
		if (len == names.len) {
			return;
		}

		for (name, 0..) |c, i| {
			name[i] = ascii.toLower(c);
		}

		names[len] = name;
		self.values[len] = value;
		self.len = len + 1;
	}

	pub fn get(self: *Self, needle: []const u8) ?[]const u8 {
		const names = self.names[0..self.len];
		for (names, 0..) |name, i| {
			if (mem.eql(u8, name, needle)) {
				return self.values[i];
			}
		}

		return null;
	}

	pub fn reset(self: *Self) void {
		self.len = 0;
	}
};

test "key_value: get" {
	var allocator = t.allocator;
	const variations = [_][]const u8{ "content-type", "Content-Type", "cONTENT-tYPE", "CONTENT-TYPE" };
	for (variations) |header| {
		var kv = try KeyValue.init(allocator, 2);
		var name = t.mutableString(header);
		kv.add(name, "application/json");

		try t.expectEqual(@as(?[]const u8, "application/json"), kv.get("content-type"));

		kv.reset();
		try t.expectEqual(@as(?[]const u8, null), kv.get("content-type"));
		kv.add(name, "application/json2");
		try t.expectEqual(@as(?[]const u8, "application/json2"), kv.get("content-type"));

		kv.deinit();
		allocator.free(name);
	}
}

test "key_value: ignores beyond max" {
	var kv = try KeyValue.init(t.allocator, 2);
	var n1 = t.mutableString("content-length");
	kv.add(n1, "cl");

	var n2 = t.mutableString("host");
	kv.add(n2, "www");

	var n3 = t.mutableString("authorization");
	kv.add(n3, "hack");

	try t.expectEqual(@as(?[]const u8, "cl"), kv.get("content-length"));
	try t.expectEqual(@as(?[]const u8, "www"), kv.get("host"));
	try t.expectEqual(@as(?[]const u8, null), kv.get("authorization"));

	kv.deinit();
	t.clearMutableString(n1);
	t.clearMutableString(n2);
	t.clearMutableString(n3);
}