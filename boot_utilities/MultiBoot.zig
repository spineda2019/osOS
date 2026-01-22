//! bootutils.zig - Common utilities for boot configurations, like multiboot
//! Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
//!
//! This program is free software: you can redistribute it and/or modify
//! it under the terms of the GNU General Public License as published by
//! the Free Software Foundation, either version 3 of the License, or
//! (at your option) any later version.
//!
//! This program is distributed in the hope that it will be useful,
//! but WITHOUT ANY WARRANTY; without even the implied warranty of
//! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//! GNU General Public License for more details.
//!
//! You should have received a copy of the GNU General Public License
//! along with this program.  If not, see <https://www.gnu.org/licenses/>.

/// Multiboot header to be placed at the beginning of a kernel binary. Must be
/// marked extern to make it exportable. Will follow the C ABI of the target
/// architecture.
///
/// Offset    Type    Field Name    Note
/// 0         u32     magic         required
/// 4         u32     flags         required
/// 8         u32     checksum      required
/// 12        u32     header_addr   if flags.activate_address_configurations is set
/// 16        u32     load_addr     if flags.activate_address_configurations is set
/// 20        u32     load_end_addr if flags.activate_address_configurations is set
/// 24        u32     bss_end_addr  if flags.activate_address_configurations is set
/// 28        u32     entry_addr    if flags.activate_address_configurations is set
/// 32        u32     mode_type     if flags.include_video_mode_info is set
/// 36        u32     width         if flags.include_video_mode_info is set
/// 40        u32     height        if flags.include_video_mode_info is set
/// 44        u32     depth         if flags.include_video_mode_info is set
pub const V1 = extern struct {
    const Self = @This();

    /// MUST be set to the MultiBoot V1 Magic Number of 0x1BADB002
    magic_number: u32,

    flags: Flags,

    /// Calculated via a combination of the flags and magic number.
    checksum: u32,

    /// if flags.activate_address_configurations is set
    header_addr: u32,

    /// if flags.activate_address_configurations is set
    load_addr: u32,

    /// if flags.activate_address_configurations is set
    load_end_addr: u32,

    /// if flags.activate_address_configurations is set
    bss_end_addr: u32,

    /// if flags.activate_address_configurations is set
    entry_addr: u32,

    mode_type: VideoInformation.ModeType,

    width: u32,

    height: u32,

    depth: u32,

    pub const magic_number_value: u32 = 0x1BADB002;
    pub fn init(flags: Flags.InitInfo, video_info: VideoInformation) Self {
        return .{
            .magic_number = Self.magic_number_value,
            .flags = flags.flags,
            .checksum = 0 -% Self.magic_number_value -% @as(
                u32,
                @bitCast(flags.flags),
            ),
            .header_addr = flags.header_addr,
            .load_addr = flags.load_addr,
            .load_end_addr = flags.load_end_addr,
            .bss_end_addr = flags.bss_end_addr,
            .entry_addr = flags.entry_addr,
            .mode_type = video_info.mode_type,
            .width = video_info.width,
            .height = video_info.height,
            .depth = video_info.depth,
        };
    }

    pub const VideoInformation = struct {
        /// if flags.include_video_mode_info is set. 0 for linear graphics and
        /// 1 for EGA text mode.
        mode_type: ModeType,

        /// if flags.include_video_mode_info is set. Framebuffer width. Measured
        /// in pixels in graphics mode, or characters in text mode.
        width: u32,

        /// if flags.include_video_mode_info is set. Framebuffer height.
        /// Measured in pixels in graphics mode, or characters in text mode.
        height: u32,

        /// if flags.include_video_mode_info is set. Contains the number of bits
        /// per pixel in a graphics mode, and zero in a text mode. The value
        /// zero indicates that the OS image has no preference.
        depth: u32,

        pub const default: VideoInformation = .{
            .mode_type = .ega_text,
            .width = 80,
            .height = 25,
            .depth = 0,
        };

        pub const ModeType = enum(u32) {
            linear = 0,
            ega_text = 1,
        };
    };

    pub const Flags = packed struct(u32) {
        enforce_all_4kb_alignment: bool,
        include_memory_information: bool,
        include_video_mode_info: bool,
        _zeros: u13 = 0,
        activate_address_configurations: bool,
        _more_zeroes: u15 = 0,

        pub const cleared: Flags = .{
            .enforce_all_4kb_alignment = 0,
            .include_memory_information = 0,
            .include_video_mode_info = 0,
            ._zeros = 0,
            .activate_address_configurations = 0,
            ._more_zeroes = 0,
        };

        pub const InitInfo = struct {
            flags: Flags,
            header_addr: u32,
            load_addr: u32,
            load_end_addr: u32,
            bss_end_addr: u32,
            entry_addr: u32,

            pub const default: InitInfo = .{
                .flags = .cleared,
                .header_addr = undefined,
                .load_addr = undefined,
                .load_end_addr = undefined,
                .bss_end_addr = undefined,
                .entry_addr = undefined,
            };
        };
    };

    /// Per the MultiBoot V1 spec, ebx shall hold the physical address to a
    /// multiboot info struct that looks like this.
    pub const Info = extern struct {
        flags: InfoFlags,

        mem_lower: u32,
        mem_upper: u32,

        boot_device: u32,

        cmdline: u32,

        mods_count: u32,
        mods_addr: u32,

        syms: SymbolTable,

        mmap_length: u32,
        mmap_addr: u32,

        drives_length: u32,
        drives_addr: u32,

        config_table: u32,

        boot_loader_name: u32,

        apm_table: u32,

        vbe_control_info: u32,
        vbe_mode_info: u32,
        vbe_mode: u16,
        vbe_interface_seg: u16,
        vbe_interface_off: u16,
        vbe_interface_len: u16,

        framebuffer_addr_lower: u32,
        framebuffer_addr_higher: u32,
        framebuffer_pitch: u32,
        framebuffer_width: u32,
        framebuffer_height: u32,
        framebuffer_bpp: u8,
        framebuffer_type: u8,
        framebuffer_color_info: FrameBufferColorInfo,

        const InfoFlags = packed struct(u32) {
            valid_mem: bool,

            boot_device: bool,

            cmdline: bool,

            mods: bool,

            syms_aout: bool,
            syms_elf: bool,

            mmap: bool,

            drives: bool,

            config: bool,

            boot_loader_name: bool,

            apm_table: bool,

            vbe: bool,

            framebuffer: bool,

            _reserved: u19,
        };

        pub const MemMapEntry = extern struct {
            size: u32,
            addr_low: u32,
            addr_high: u32,
            len_low: u32,
            len_high: u32,
            entry_type: EntryType,

            pub const EntryType = enum(u32) {
                available = 1,
                reserved = 2,
                acpi_reclaimable = 3,
                nvs = 4,
                badram = 5,
            };
        };

        const SymbolTable = extern union {
            pub const AOutSymbolTable = extern struct {
                tabsize: u32,
                strsize: u32,
                addr: u32,
                _reserved: u32,
            };
            pub const ElfSectionTable = extern struct {
                num: u32,
                size: u32,
                addr: u32,
                shndx: u32,
            };

            aout: AOutSymbolTable,
            elf: ElfSectionTable,
        };

        const FrameBufferColorInfo = extern union {
            const PaletteInfo = extern struct {
                address: u32,
                num_colors: u16,
            };
            const RGBInfo = extern struct {
                red_field_position: u8,
                red_mask_size: u8,

                green_field_position: u8,
                green_mask_size: u8,

                blue_field_position: u8,
                blue_mask_size: u8,
            };

            palette_info: PaletteInfo,
            rgb_info: RGBInfo,
        };
    };
};
