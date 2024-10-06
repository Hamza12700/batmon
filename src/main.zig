const std = @import("std");
const heap = std.heap;
const fs = std.fs;
const posix = std.posix;
const io = std.io;

pub fn main() !void {
  const stdout = io.getStdOut().writer();
  const home_env = std.posix.getenv("HOME") orelse {
    std.debug.print("Failed to get env varaible: HOME\n", .{});
    posix.exit(1);
  };

  var args = std.process.args();
  if (args.inner.count >= 2) {
    // Skip the binary path
    _ = args.skip();

    while (args.next()) |arg| {
      // TODO: add command for checking the battery status
      std.debug.print("{s}\n", .{arg});
    }
    return;
  }

  // Creating ArenaAllocator
  var arena_alloc = heap.ArenaAllocator.init(heap.page_allocator);
  defer arena_alloc.deinit();
  const alloc = arena_alloc.allocator();

  const config_path = try std.fmt.allocPrint(alloc, "{s}/batmon.ini", .{home_env});
  const config_file = fs.openFileAbsolute(config_path, .{ .mode = .read_write }) catch |err| switch (err) {
    error.FileNotFound => blk: {
      try stdout.print("Creating config file at: %s\n", .{});
      break :blk try writeConfig(config_path);
    },
    else => {
      std.debug.print("Unexpected error occur when reading the config file: {s}\n", .{config_path});
      std.debug.print("Error: {any}\n", .{err});
      posix.exit(1);
    }
  };
  defer config_file.close();
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

  const stdout = io.getStdOut().writer();
  try stdout.print("\nHalf   = 50\n", .{});
  try stdout.print("Mid    = 25\n", .{});
  try stdout.print("Low    = 10\n", .{});
  try stdout.print("Ticks  = 10s\n", .{});

  try stdout.print("You can change the config optins here: {s}\n", .{path});
  return file;
}
