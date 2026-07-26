//! RtHAL.zig - The Runtime Hardware Abstraction Layer interface for osOS.
//!
//! Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//! Under the GPL version 3 or later. Check the source for the full license
//! notice.
//*
//* This program is free software: you can redistribute it and/or modify
//* it under the terms of the GNU General Public License as published by
//* the Free Software Foundation, either version 3 of the License, or
//* (at your option) any later version.
//*
//* This program is distributed in the hope that it will be useful,
//* but WITHOUT ANY WARRANTY; without even the implied warranty of
//* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//* GNU General Public License for more details.
//*
//* You should have received a copy of the GNU General Public License
//* along with this program.  If not, see <https://www.gnu.org/licenses/>.

const RtHal = @This();
const IWriter = @import("osformat").IWriter;

serial_io: IWriter,
terminal: IWriter,
