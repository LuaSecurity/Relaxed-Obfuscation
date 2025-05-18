-- config.lua for Relax Obfuscator
-- This Script is Part of the Relax Obfuscator (Fork of Prometheus by Levno_710)
--
-- In this Script, some Global config Variables are defined

-- Using local variables for internal constants to avoid polluting the global scope
-- and to make them slightly less obvious if someone just `require`s and iterates _G.
local OBfuscator_NAME     = "Relax Obfuscator" -- Changed Name
local OBfuscator_REVISION  = "Beta" -- Or your current revision
local OBfuscator_VERSION   = "v0.1-fork" -- Differentiate from original Prometheus
local OBfuscator_AUTHOR    = "YourName/Handle" -- Original author + your fork credit if desired
                                         -- e.g., "levno-710 & YourName"

-- CommandLine Argument Processing
-- This part is fine, but ensure `arg` is available in the environment
-- where this script is run. In some embedding scenarios, `arg` might be nil.
if _G.arg then -- Check if arg exists
    for _, currArg in pairs(_G.arg) do
        if currArg == "--CI_RELEASE_NAME" then -- Make CI flags more specific
            local releaseName = string.gsub(string.format("%s-%s-%s", OBfuscator_NAME, OBfuscator_REVISION, OBfuscator_VERSION), "%s+", "-") -- Ensure single dashes
            print(releaseName)
        end
        
        if currArg == "--OBFUSCATOR_FULL_VERSION" then -- Make flag more specific
            print(OBfuscator_VERSION)
        end

        if currArg == "--OBFUSCATOR_NAME" then
            print(OBfuscator_NAME)
        end
    end
end

-- Configuration table to be returned
local config_table = {
    ObfuscatorName = OBfuscator_NAME,
    ObfuscatorNameUpper = string.upper(OBfuscator_NAME),
    ObfuscatorNameAndVersion = string.format("%s %s", OBfuscator_NAME, OBfuscator_VERSION),
    ObfuscatorVersion = OBfuscator_VERSION,
    ObfuscatorRevision = OBfuscator_REVISION,
    ObfuscatorAuthor = OBfuscator_AUTHOR,

    -- IdentPrefix: Critical for avoiding collisions.
    -- Make it more unique and less guessable if desired.
    -- Using non-ASCII characters can sometimes make it harder for simple text searches,
    -- but ensure your Lua environment and parser handle them correctly.
    -- For max safety, stick to ASCII but make it complex.
    IdentPrefix = "__relax_obf_v1__", -- More specific prefix
                                      -- Consider adding a random component during the build
                                      -- of Relax Obfuscator itself, so your internal IdentPrefix
                                      -- is not static in distributed versions of the obfuscator.

    -- Unparser settings (Whitespace)
    -- These are fine as they are for functionality.
    -- If you wanted to be "tricky," you could make these functions that return
    -- the space/tab, or pull them from an encoded source, but it's likely overkill
    -- for these specific values.
    SPACE = " ",
    TAB   = "\t", -- Used by the unparser for pretty printing (if enabled)

    -- Default settings for obfuscation passes (can be overridden by presets)
    -- This is a good place to put defaults that presets might not specify.
    DefaultLuaVersion = "Lua51",
    DefaultVarNamePrefix = "",
    DefaultNameGenerator = "MangledShuffled", -- e.g., IlI1lI1l
    DefaultPrettyPrint = false,
    DefaultSeed = 0, -- 0 typically means use os.time() or a similar dynamic source

    -- Internal constants or flags (example)
    -- These might control behavior within the obfuscator itself.
    InternalDebugMode = false, -- Should be false for releases
    MaxRecursiveDepth = 100,   -- Safety limit for recursive operations
}

-- To make it "bulletproof" or "undumpable" in the context of this file,
-- the primary method is to NOT ship this as a plain .lua file.
-- Instead, this module would be:
-- 1. Obfuscated by Relax Obfuscator itself (a bootstrap version).
-- 2. Compiled to bytecode.
-- 3. Potentially encrypted.
-- 4. Loaded by a secure loader in your main `relax_obfuscator.lua` entry point.

-- If you want to make the returned table harder to modify *after* it's loaded
-- (though this is more about runtime integrity than anti-dumping),
-- the `util.readonly(Config)` approach you have in your main entrypoint is good.
-- You could also implement a simple freeze function here if `util` isn't available yet.

local function simple_freeze(tbl)
    return setmetatable({}, {
        __index = tbl,
        __newindex = function(t, k, v)
            error("Attempt to modify a read-only configuration table (key: " .. tostring(k) .. ")", 2)
        end,
        __metatable = false -- Hide the metatable
    })
end

-- Return a "frozen" version of the config table.
return simple_freeze(config_table)
-- Or, if you expect `util.readonly` to be available when this is first required
-- (e.g., if util is loaded first and config is loaded via a mechanism that provides it),
-- you could conceptually do:
-- return YourObfuscatorCore.util.readonly(config_table)
-- But for a self-contained config.lua, simple_freeze is more direct.
