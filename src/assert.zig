const std = @import("std");
const debug = std.debug;

pub fn NoErr(err: anyerror, msg: anytype) void {
  debug.print("Assert failed: {s}\n", .{msg});
  debug.print("Error: {any}", .{err});
  std.posix.exit(1);
}
