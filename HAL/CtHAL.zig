const CtHAL = @This();

const IAsm = @import("IAsm.zig");
const ContextTools = @import("osprocess").ContextTools;

assembly_wrappers: IAsm,

ctx_tools: ContextTools,
