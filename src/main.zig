const std = @import("std");
const assert = @import("./assert.zig");
const heap = std.heap;
const fs = std.fs;
const posix = std.posix;
const io = std.io;
const mem = std.mem;
const fmt = std.fmt;

const BAT_CAPASCITY = "/sys/class/power_supply/BAT0/capacity";
const BAT_STATUS = "/sys/class/power_supply/BAT0/status";

const Config = struct {
  ticker: u16,
  half: u8,
  mid: u8,
  low: u8,

  /// Set fields to default options
  fn defualt(self: *Config) void {
    self.half = 50;
    self.mid = 25;
    self.low = 10;
    self.ticker = 10;
  }
};

pub fn main() !void {
  const stdout = io.getStdOut().writer();
  const home_env = std.posix.getenv("HOME") orelse {
    std.debug.print("Failed to get env varaible: HOME\n", .{});
    posix.exit(1);
  };

  var capascity_buf: [3]u8 = undefined;
  var status_buf: [12]u8 = undefined;

  var args = std.process.args();
  if (args.inner.count >= 2) {
    // Skip the binary path
    _ = args.skip();

    while (args.next()) |arg| {
      if (mem.eql(u8, arg, "s") or mem.eql(u8, arg, "status")) {
        _ = try readFileAbsolute(BAT_CAPASCITY).read(&capascity_buf);
        _ = try readFileAbsolute(BAT_STATUS).read(&status_buf);

        try stdout.print("Battery Capascity: {s}", .{capascity_buf});
        try stdout.print("Battery Status: {s}", .{status_buf});
        return;
      }

      std.debug.print("Command not found: {s}\n", .{arg});
      posix.exit(1);
    }
    return;
  }

  // Creating ArenaAllocator
  var arena_alloc = heap.ArenaAllocator.init(heap.page_allocator);
  defer arena_alloc.deinit();
  const alloc = arena_alloc.allocator();
  var config = Config{
    .ticker = 0,
    .mid = 0,
    .half = 0,
    .low = 0
  };

  const config_path = try fmt.allocPrint(alloc, "{s}/batmon.ini", .{home_env});
  const config_file = fs.openFileAbsolute(config_path, .{ .mode = .read_write }) catch |err| switch (err) {
    error.FileNotFound => blk: {
      try stdout.print("Creating config file at: {s}\n", .{config_path});
      config.defualt();

      break :blk try writeConfig(config_path);
    },
    else => {
      assert.NoErr(err, "Unexpected error occur when reading the config file at `$HOME/batmon.ini`");
      return;
    }
  };

  if (config.ticker == 0) {
    const end_pos = try config_file.getEndPos();
    const config_contents = config_file.readToEndAlloc(alloc, end_pos) catch |err| {
      assert.NoErr(err, "Failed to read config file into a heap allocated buffer");
      return;
    };

    var lines = mem.splitAny(u8, config_contents, "\n");
    while (lines.next()) |line| {
      std.debug.print("{s}", .{line});
    }
    return;
  }
  config_file.close();

  while (true) {
    _ = try readFileAbsolute(BAT_CAPASCITY).read(&capascity_buf);
    _ = try readFileAbsolute(BAT_STATUS).read(&status_buf);

    const capacity = fmt.parseUnsigned(u8, mem.trimRight(u8, &capascity_buf, "\n"), 10) catch |err| {
      assert.NoErr(err, "Error parsing battery capascity value into an unsigned int");
      return;
    };

    try stdout.print("{d}\n", .{capacity});
    posix.nanosleep(1, 0);
  }
}

fn readFileAbsolute(path: []const u8) fs.File {
  return fs.openFileAbsolute(path, .{}) catch |err| {
    if (err == error.FileNotFound) {
      std.debug.print("File not found: {s}\n", .{path});
      std.debug.print("Error: {any}\n", .{err});
      posix.exit(1);
    } else {
      std.debug.print("Failed to read file: {s}\n", .{path});
      std.debug.print("Error: {any}\n", .{err});
      posix.exit(1);
    }
  };
}

/// Write default config options to file
fn writeConfig(path: []const u8) !fs.File {
  const file = fs.createFileAbsolute(path, .{}) catch |err| {
    std.debug.print("Failed to create config file at: {s}\n", .{path});
    std.debug.print("Error: {any}\n", .{err});
    posix.exit(1);
  };
  try file.writeAll("[Batmon]\n\n");

  try file.writeAll("# Warn if battery is blow/equal to 50%\n");
  try file.writeAll("Half = 50\n\n");

  try file.writeAll("# Warn if battery is blow/equal to 25%\n");
  try file.writeAll("Mid = 25\n\n");

  try file.writeAll("# Warn if battery is blow/equal to 10%\n");
  try file.writeAll("Low = 10\n\n");

  try file.writeAll("# Time to Tick every x amount of seconds\n");
  try file.writeAll("Ticks = 10s");

  return file;
}
