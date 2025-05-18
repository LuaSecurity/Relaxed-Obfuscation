-- presets.lua for Relax Obfuscator
-- This Script is Part of the Relax Obfuscator (Fork of Prometheus by Levno_710)

-- Note: LuaVersion defaults to "Lua51" if not specified in a preset.
-- Note: VarNamePrefix defaults to "" if not specified.
-- Note: NameGenerator defaults to "MangledShuffled" if not specified.
-- Note: PrettyPrint defaults to false if not specified.
-- Note: Seed defaults to 0 (dynamic based on os.time()) if not specified.

return {
    ["Minify"] = {
        -- Purpose: Smallest possible output, readable variable names (if possible), no functional changes.
        -- LuaVersion = "Lua51", -- Default
        VarNamePrefix = "_", -- A common prefix for minified vars to avoid clashes
        NameGenerator = "Sequential", -- e.g., _0, _1, _2 (You'd need to add this generator type)
                                      -- Or keep "MangledShuffled" if you prefer less readable minified names
        PrettyPrint = false,
        -- Seed = 0, -- Default
        Steps = {
            -- Minification usually implies no heavy obfuscation steps.
            -- If you have specific "minifying" passes (like dead code removal without obfuscation), add them.
            -- For now, it's just about minimal names and no extra whitespace.
        }
    },

    ["Lite"] = { -- Renamed "Weak" to "Lite" for a friendlier tone
        -- Purpose: Basic obfuscation, minimal performance impact.
        -- NameGenerator = "MangledShuffled", -- Default (IlI1lI1l style)
        Steps = {
            {
                Name = "ConstantArray", -- Moves strings (and optionally numbers) to an array
                Settings = {
                    Treshold    = 2, -- Only group if 2 or more identical constants
                    StringsOnly = true,
                    Shuffle     = false,
                    Rotate      = false,
                }
            },
            {
                Name = "NumbersToExpressions", -- Simple number obfuscation
                Settings = {
                    Complexity = 1 -- A hypothetical setting for how complex expressions get
                }
            },
            {
                Name = "WrapInFunction", -- Standard wrapping
                Settings = {}
            },
        }
    },

    ["Default"] = { -- Replaces "Medium" as a good general-purpose option
        -- Purpose: Good balance of obfuscation and performance.
        Steps = {
            {
                Name = "EncryptStrings",
                Settings = {
                    -- KeyDerivation = "Dynamic", -- Hypothetical: key derived at runtime
                    -- DecoderComplexity = 1
                }
            },
            {
                Name = "NumbersToExpressions",
                Settings = {
                    Complexity = 2
                }
            },
            {
                Name = "IntegerEncoding", -- If available (encodes integers)
                Settings = {
                    Mode = "Arithmetic" -- e.g., 5 -> (2+3)*1
                }
            },
            {
                Name = "ConstantArray",
                Settings = {
                    Treshold    = 1, -- All eligible constants
                    StringsOnly = false, -- Include numbers too
                    Shuffle     = true,
                    Rotate      = true,
                    LocalWrapperTreshold = 1, -- Wrap accessors in local functions for more obscurity
                }
            },
            {
                Name = "ControlFlowFlattening", -- If available
                Settings = {
                    Intensity = "Medium"
                }
            },
            {
                Name = "Vmify", -- A single, solid Vmify pass
                Settings = {
                    -- OpcodeSet = "Standard",
                    -- InterpreterObfuscation = 1, -- Obfuscate the generated VM interpreter itself
                }
            },
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false, -- Don't rely on debug library
                    Checks = {"Checksum", "HookDetection"} -- Hypothetical specific checks
                }
            },
            {
                Name = "WrapInFunction",
                Settings = {}
            },
        }
    },

    ["Strong"] = {
        -- Purpose: Heavy obfuscation, performance impact is expected.
        Steps = {
            {
                Name = "EncryptStrings",
                Settings = {
                    -- KeyDerivation = "Layered",
                    -- DecoderComplexity = 2,
                    -- UseMultipleKeys = true
                }
            },
            {
                Name = "NumbersToExpressions",
                Settings = {
                    Complexity = 3
                }
            },
            {
                Name = "IntegerEncoding",
                Settings = {
                    Mode = "BitwiseAndArithmetic" -- More complex encoding
                }
            },
            {
                Name = "ConstantArray",
                Settings = {
                    Treshold    = 1,
                    StringsOnly = false,
                    Shuffle     = true,
                    Rotate      = true,
                    LocalWrapperTreshold = 0, -- Maximize use of local wrappers
                    EncryptIndexes = true -- Hypothetical: indexes into array are also obfuscated
                }
            },
            {
                Name = "ControlFlowFlattening",
                Settings = {
                    Intensity = "High",
                    UseOpaquePredicates = true -- Integrate opaque predicates into CFF
                }
            },
            {
                Name = "DeadCodeInjection", -- Add confusing, non-functional code
                Settings = {
                    Density = "Medium",
                    Complexity = 2
                }
            },
            {
                Name = "OpaquePredicates", -- Standalone opaque predicates in various places
                Settings = {
                    Frequency = "Medium"
                }
            },
            {
                Name = "Vmify", -- Vmify critical sections or the whole script
                Settings = {
                    -- OpcodeSet = "Extended",
                    -- InterpreterObfuscation = 2,
                    -- SelfModification = true -- VM interpreter modifies itself (very advanced)
                }
            },
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false,
                    Checks = {"Checksum", "HookDetection", "Environment", "Timing"},
                    Severity = "High" -- e.g., crash or corrupt on tamper
                }
            },
            {
                Name = "EnvironmentHardening", -- If available
                Settings = {}
            },
            {
                Name = "WrapInFunction",
                Settings = {
                    ChainDepth = 2 -- e.g. function() return function() ... end end
                }
            },
        }
    },

    ["Paranoid"] = { -- New preset for maximum (potentially overkill) obfuscation
        -- Purpose: Make reversing as painful as humanly possible. Expect significant size and performance overhead.
        LuaVersion = "Lua51", -- Or whatever your most advanced techniques target
        VarNamePrefix = "", -- Let MangledShuffled do its thing without a predictable prefix
        NameGenerator = "MangledShuffled",
        PrettyPrint = false,
        Seed = 0,
        Steps = {
            -- Layer 1: Initial transformations
            { Name = "EncryptStrings", Settings = { /* Max settings */ } },
            { Name = "NumbersToExpressions", Settings = { Complexity = 4 } },
            { Name = "IntegerEncoding", Settings = { Mode = "All" } },
            { Name = "ConstantArray", Settings = { /* Max settings, encrypt indexes */ } },
            { Name = "CallChaining", Settings = { Depth = 3 } }, -- Obfuscate function calls

            -- Layer 2: Structural obfuscation
            { Name = "ControlFlowFlattening", Settings = { Intensity = "Extreme", UseOpaquePredicates = true, Interleave = true } },
            { Name = "DeadCodeInjection", Settings = { Density = "High", Complexity = 3, Contextual = true } },
            { Name = "OpaquePredicates", Settings = { Frequency = "High", Types = {"Arithmetic", "LoopVariant"} } },

            -- Layer 3: Virtualization (Potentially multiple, different VMs or a VM whose interpreter is heavily obfuscated)
            -- Option A: One very complex VM
            {
                Name = "AdvancedVmify", -- A Vmify pass that's designed to be extremely robust
                Settings = {
                    Target = "FullScript",
                    Interpreter = {
                        ObfuscationPasses = {"EncryptStrings", "ControlFlowFlattening", "NumbersToExpressions"}, -- Obfuscate the VM interpreter itself!
                        SelfChecksumming = true,
                        DynamicDispatch = true -- VM opcodes resolved at runtime
                    },
                    Bytecode = {
                        Encryption = true,
                        Obfuscation = true -- Obfuscate the custom bytecode patterns
                    }
                }
            },
            -- Option B: Layered Vmify (if your Vmify can be structured this way)
            -- { Name = "Vmify", Settings = { Target = "ArithmeticLogic", InterpreterObfuscation = 1 } },
            -- { Name = "Vmify", Settings = { Target = "ControlFlow", InterpreterObfuscation = 1, InputIsVmBytecode = true } }, -- Second VM operates on first VM's output

            -- Layer 4: Final defenses
            {
                Name = "AntiTamper",
                Settings = {
                    UseDebug = false,
                    Checks = {"FullChecksum", "HookChain", "EnvironmentIntegrity", "TimingAnomalies", "MemoryPatterns"},
                    Severity = "TerminateAndCorrupt",
                    SelfRepairAttempts = 0 -- Or a low number for misdirection
                }
            },
            { Name = "EnvironmentHardening", Settings = { FullStrip = true } },

            -- Layer 5: Packaging
            {
                Name = "Packer", -- Final wrap, maybe into a single string to be loadstring'd, potentially with another layer of encryption/compression
                Settings = {
                    LoaderObfuscation = "High",
                    Compress = true
                }
            }
            -- Note: `WrapInFunction` might be implicitly handled by the Packer or a final Vmify stage.
        }
    }
}
