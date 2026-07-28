const syscall = @import("syscall.zig");

pub const console = struct {
    pub fn readChar() u8 {}

    pub fn readLine() []const u8 {}

    pub fn print(_: []const u8) void {}

    pub fn printLine(_: []const u8) void {}
};

/// Ripped from the man pages. I doubt I'll 100% follow posix
const ReadError = error{
    /// The file descriptor fd refers to a file other than a socket and has been
    /// marked nonblocking (O_NONBLOCK), and the read would block.  See open(2)
    /// for further details on the O_NONBLOCK flag.
    again,

    /// The file descriptor fd refers to a socket  and  has  been  marked
    /// nonblocking  (O_NONBLOCK),  and  the  read  would  block. POSIX.1-2001
    /// allows either error to be returned for this case, and does not require
    /// these constants to have the same value, so a portable application
    /// should check for both possibilities.
    wouldblock,

    /// fd is not a valid file descriptor or is not open for reading.
    badfile,

    ///buf is outside your accessible address space.
    fault,

    ///  The call was interrupted by a signal before any data was read.
    ///  see signal(7).
    intr,

    /// fd is attached to an object which is unsuitable for reading; or the file
    /// was opened with the O_DIRECT flag, and  either  the address specified in
    /// buf, the value specified in count, or the file offset is not suitably
    /// aligned.
    inval,

    /// I/O  error.  This will happen for example when the process is in a
    /// background process group, tries to read from its controling terminal,
    /// and either it is ignoring or blocking SIGTTIN or its process group is
    /// orphaned.  It may also occur when there is a low-level I/O error while
    /// reading from a disk or tape.  A further possible cause of EIO on
    /// networked  filesystems  is when  an advisory lock had been taken out on
    /// the file descriptor and this lock has been lost. See the Lost locks
    /// section of fcntl(2) for further details.
    io,

    /// fd refers to a directory.
    isdir,
};

pub fn read() ReadError!usize {
    const syscall_num: comptime_int = syscall.syscallNum("read");
    @compileLog(syscall_num);
}
