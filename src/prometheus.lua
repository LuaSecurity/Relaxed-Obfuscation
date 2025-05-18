-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- prometheus.lua
-- This file is the entrypoint for Prometheus

-- WARNING: The "bulletproof" and "undumpable" nature primarily comes from
-- how the core obfuscator modules are protected (e.g., pre-obfuscated,
-- compiled to bytecode, encrypted) and the advanced techniques implemented
-- within those modules to protect the outputted scripts. This entrypoint
-- is kept relatively simple to load the heavily protected core.

-- Minimal necessary global state alteration
local _G = _G;
local pcall = pcall;
local type = type;
local setmetatable = setmetatable;
local package = package;
local debug = debug;
local math = math;
local string = string;
local table = table;
local io = io; -- For loading encrypted files, if needed

-- Centralized error handling for early setup
local function critical_error(msg)
    -- In a real "bulletproof" scenario, you might do something more drastic
    -- or less obvious than printing, e.g., silent exit or intentional crash.
    print("Prometheus Critical Error: " .. msg);
    -- Example: os.exit(1) or while true do end
    return nil; -- Or error(msg) to halt
end

-- Custom secure loader (Conceptual - needs a real decryption function)
-- This is where a significant part of the "undumpable" aspect for the
-- obfuscator itself would lie. The 'decrypt_and_load_bytecode' function
-- would be highly obfuscated, potentially written in C, or its key very well hidden.
local function secure_load_module(module_name_encrypted, decryption_key)
    -- In a real scenario, 'module_name_encrypted' might be a path to an encrypted file
    -- or the encrypted content itself if embedded.
    -- This is a placeholder for your decryption and loading logic.

    -- 1. Locate/Access the encrypted module data
    local encrypted_data;
    local f, err = io.open(module_name_encrypted, "rb");
    if not f then
        return critical_error("Failed to open encrypted module: " .. module_name_encrypted .. " (" .. (err or "unknown error") .. ")");
    end
    encrypted_data = f:read("*a");
    f:close();

    if not encrypted_data then
        return critical_error("Failed to read encrypted module: " .. module_name_encrypted);
    end

    -- 2. Decrypt the data (DECRYPT_FUNC is your highly protected decryption routine)
    -- The DECRYPT_FUNC itself would be a prime target for obfuscation/protection.
    -- For example, DECRYPT_FUNC could be a C function, or heavily obfuscated Lua.
    local byte_code, dec_err = DECRYPT_FUNC(encrypted_data, decryption_key); -- Implement DECRYPT_FUNC
    if not byte_code then
        return critical_error("Failed to decrypt module: " .. module_name_encrypted .. " (" .. (dec_err or "decryption failed") .. ")");
    end

    -- 3. Load the decrypted bytecode
    local func, load_err = load(byte_code, "@" .. module_name_encrypted:gsub("%.enc$", ""), "b"); -- "b" for binary chunk
    if not func then
        return critical_error("Failed to load decrypted module: " .. (load_err or "load error"));
    end

    -- 4. Execute to get the module table
    local ok, result = pcall(func);
    if not ok then
        return critical_error("Failed to execute decrypted module: " .. (result or "execution error"));
    end
    return result;
end

-- Example: Your decryption function (MUST BE SECURED/OBFUSCATED HEAVILY)
-- This is a TOY example. Real crypto is needed.
local SUPER_SECRET_KEY_MATERIAL = "my_very_secret_key_part_that_is_itself_obfuscated_or_derived";
function DECRYPT_FUNC(data, key_material_ignored_for_toy_example)
    -- In a real system, key_material_ignored_for_toy_example would be used.
    -- This is a simple XOR cipher for demonstration. DO NOT USE IN PRODUCTION.
    local key = SUPER_SECRET_KEY_MATERIAL;
    local key_len = #key;
    local decrypted_bytes = {};
    for i = 1, #data do
        decrypted_bytes[i] = string.char(string.byte(data, i) ~ string.byte(key, (i-1)%key_len + 1));
    end
    return table.concat(decrypted_bytes);
end


-- Configure package.path for require (if still needed for non-encrypted parts or initial loader)
local script_path_str;
local ok_path, path_info = pcall(function() return debug.getinfo(2, "S").source:sub(2) end);
if ok_path and type(path_info) == "string" then
    script_path_str = path_info:match("(.*[/%\\])");
else
    -- Fallback or error if path cannot be determined.
    -- This is critical. If script_path fails, loading modules will fail.
    -- For a "bulletproof" system, you might embed a known relative path
    -- or have a C component provide the base path.
    return critical_error("Could not determine script path. Debug info might be stripped or altered.");
end

local oldPkgPath = package.path;
if script_path_str then
    package.path = script_path_str .. "?.lua;" .. script_path_str .. "?.luac;" .. package.path;
    -- If using encrypted modules, you might not even need to modify package.path
    -- if 'secure_load_module' handles paths directly.
else
    -- Handle missing script_path_str (e.g., error out, or assume current dir)
    -- For now, we'll let it proceed, but 'secure_load_module' would need full paths.
end


-- Math.random Fix for Lua5.1 (Good for compatibility)
if not pcall(function() return math.random(1, 2^40); end) then
    local oldMathRandom = math.random;
    math.random = function(a, b)
        if not a and not b then -- Fixed condition: was 'not a and b'
            return oldMathRandom();
        end
        if not b then
            b = a; a = 1; -- Fixed: math.random(x) means math.random(1,x)
        end
        if a > b then a, b = b, a; end
        local diff = b - a;
        if diff < 0 then -- Should not happen if a<=b
             critical_error("math.random range error after swap"); return a;
        end

        if diff > 2147483647 then -- 2^31 - 1
            -- This part of the fix is for very large ranges, common in LuaJIT but not standard 5.1 math.random limits
            -- Standard math.random uses doubles, so precision is the issue for large integers.
            -- The original fix might be specific to a certain Lua implementation or for generating
            -- numbers beyond typical integer limits by using floating point arithmetic.
            -- For standard Lua 5.1, math.random(a,b) should work if a,b are within integer limits.
            -- If aiming for numbers larger than 2^31, this floating point approach is one way.
            return math.floor(oldMathRandom() * (diff + 1) + a); -- +1 for inclusive range
        else
            return oldMathRandom(a, b);
        end
    end
end

-- newproxy polyfill (Good for compatibility)
_G.newproxy = _G.newproxy or function(arg)
    -- The original newproxy(true) creates a userdata with a metatable that can have __gc etc.
    -- newproxy(false) or newproxy() creates a userdata with no metatable.
    -- This polyfill is a simplification. For true 'newproxy' behavior with finalizers,
    -- a C implementation or a more complex Lua proxy table trick is needed.
    -- What's here is fine for many use cases where just a unique, un-interfering table is needed.
    if arg == true then -- Match original behavior for newproxy(true) more closely
        local u = newproxy(false); -- Get a bare userdata
        setmetatable(u, {}); -- Give it an empty metatable
        return u;
    elseif arg == false or arg == nil then
        -- Standard newproxy(false) / newproxy() returns a bare userdata.
        -- Lua 5.2+ don't have newproxy. Creating a unique table is a common substitute.
        -- However, `newproxy` creates a USERDATA, not a table. This matters for `type()`.
        -- A more accurate polyfill for `newproxy(false)` if a real userdata is needed
        -- and `newproxy` is truly absent (like in Lua 5.2+ when not built with compat):
        -- return coroutine.create(function() end) -- This is a userdata (thread)
        -- For simplicity, returning a table is often "good enough" if type doesn't matter.
        -- The original polyfill was:
        -- if arg then return setmetatable({}, {}); end return {};
        -- Let's stick to a closer approximation if type matters, or the simple table if not.
        -- Given this is for an obfuscator which might run on various Lua versions:
        return {}; -- Simplest, but returns a table, not userdata.
                   -- If you need actual userdata for some obfuscation trick, this needs to be rethought.
    end
    return {}; -- Fallback
end


-- Determine the key for decrypting modules.
-- This key itself should be protected.
-- e.g., derived from machine specific info, fetched, split into parts,
-- or heavily obfuscated in a C component.
-- For this example, we use the one defined near DECRYPT_FUNC
local MODULE_DECRYPTION_KEY = SUPER_SECRET_KEY_MATERIAL;


-- Require Prometheus Submodules (Now using the secure loader)
-- The paths here would point to your encrypted files.
-- Example: "prometheus/pipeline.luac.enc"
local PipelineModName  = script_path_str .. "prometheus/pipeline.obf"; -- Adjust extension
local HighlightModName = script_path_str .. "highlightlua.obf";
local ColorsModName    = script_path_str .. "colors.obf";
local LoggerModName    = script_path_str .. "logger.obf";
local PresetsModName   = script_path_str .. "presets.obf";
local ConfigModName    = script_path_str .. "config.obf";
local UtilModName      = script_path_str .. "prometheus/util.obf";

-- Actual loading, assuming DECRYPT_FUNC and secure_load_module are robustly defined above
-- and your modules have been pre-processed (obfuscated, bytecompiled, encrypted)
local Pipeline  = secure_load_module(PipelineModName, MODULE_DECRYPTION_KEY);
local highlight = secure_load_module(HighlightModName, MODULE_DECRYPTION_KEY);
local colors    = secure_load_module(ColorsModName, MODULE_DECRYPTION_KEY);
local Logger    = secure_load_module(LoggerModName, MODULE_DECRYPTION_KEY);
local Presets   = secure_load_module(PresetsModName, MODULE_DECRYPTION_KEY);
local Config    = secure_load_module(ConfigModName, MODULE_DECRYPTION_KEY);
local util      = secure_load_module(UtilModName, MODULE_DECRYPTION_KEY);

-- Critical check: Ensure all modules loaded
if not (Pipeline and highlight and colors and Logger and Presets and Config and util) then
    -- Error already printed by secure_load_module, but we need to halt.
    -- In a prod system, this might trigger a more subtle failure.
    return critical_error("One or more core Prometheus modules failed to load securely.");
end

-- Restore package.path (if it was modified and you want to sandbox subsequent requires)
package.path = oldPkgPath;
oldPkgPath = nil; -- Clear reference

-- Tamper-proofing the loaded modules (conceptual)
-- The 'util.readonly' is a good start for config.
-- For other modules, you might freeze them or replace their metatables
-- to prevent modification, if they aren't already designed to be immutable.
-- This is more about runtime integrity than anti-dumping.

if util and util.readonly then
    Config = util.readonly(Config); -- Readonly for Config is good.
else
    critical_error("Prometheus util module or readonly function not available after load.");
    -- Cannot proceed if core utils are broken
    return nil;
end


-- Self-destruct sensitive functions or data after initialization if they are no longer needed
DECRYPT_FUNC = nil;
SUPER_SECRET_KEY_MATERIAL = nil;
MODULE_DECRYPTION_KEY = nil;
secure_load_module = nil;
-- Any other sensitive setup functions should be nilled out.

-- Final check before exporting
if not (Pipeline and highlight and colors and Logger and Presets and Config) then
    -- This is a fallback, should have been caught earlier.
    -- Silently fail or cause a less obvious error.
    local m = {}
    setmetatable(m, { __index = function() critical_error("Prometheus is not operational."); return function() end end})
    return m;
end

-- Export
return {
    Pipeline  = Pipeline;
    colors    = colors;
    Config    = Config; -- Already readonly
    Logger    = Logger;
    highlight = highlight;
    Presets   = Presets;
    -- Not exporting 'util' by default unless it's part of the public API.
}-- This Script is Part of the Prometheus Obfuscator by Levno_710
--
-- prometheus.lua
-- This file is the entrypoint for Prometheus

-- WARNING: The "bulletproof" and "undumpable" nature primarily comes from
-- how the core obfuscator modules are protected (e.g., pre-obfuscated,
-- compiled to bytecode, encrypted) and the advanced techniques implemented
-- within those modules to protect the outputted scripts. This entrypoint
-- is kept relatively simple to load the heavily protected core.

-- Minimal necessary global state alteration
local _G = _G;
local pcall = pcall;
local type = type;
local setmetatable = setmetatable;
local package = package;
local debug = debug;
local math = math;
local string = string;
local table = table;
local io = io; -- For loading encrypted files, if needed

-- Centralized error handling for early setup
local function critical_error(msg)
    -- In a real "bulletproof" scenario, you might do something more drastic
    -- or less obvious than printing, e.g., silent exit or intentional crash.
    print("Prometheus Critical Error: " .. msg);
    -- Example: os.exit(1) or while true do end
    return nil; -- Or error(msg) to halt
end

-- Custom secure loader (Conceptual - needs a real decryption function)
-- This is where a significant part of the "undumpable" aspect for the
-- obfuscator itself would lie. The 'decrypt_and_load_bytecode' function
-- would be highly obfuscated, potentially written in C, or its key very well hidden.
local function secure_load_module(module_name_encrypted, decryption_key)
    -- In a real scenario, 'module_name_encrypted' might be a path to an encrypted file
    -- or the encrypted content itself if embedded.
    -- This is a placeholder for your decryption and loading logic.

    -- 1. Locate/Access the encrypted module data
    local encrypted_data;
    local f, err = io.open(module_name_encrypted, "rb");
    if not f then
        return critical_error("Failed to open encrypted module: " .. module_name_encrypted .. " (" .. (err or "unknown error") .. ")");
    end
    encrypted_data = f:read("*a");
    f:close();

    if not encrypted_data then
        return critical_error("Failed to read encrypted module: " .. module_name_encrypted);
    end

    -- 2. Decrypt the data (DECRYPT_FUNC is your highly protected decryption routine)
    -- The DECRYPT_FUNC itself would be a prime target for obfuscation/protection.
    -- For example, DECRYPT_FUNC could be a C function, or heavily obfuscated Lua.
    local byte_code, dec_err = DECRYPT_FUNC(encrypted_data, decryption_key); -- Implement DECRYPT_FUNC
    if not byte_code then
        return critical_error("Failed to decrypt module: " .. module_name_encrypted .. " (" .. (dec_err or "decryption failed") .. ")");
    end

    -- 3. Load the decrypted bytecode
    local func, load_err = load(byte_code, "@" .. module_name_encrypted:gsub("%.enc$", ""), "b"); -- "b" for binary chunk
    if not func then
        return critical_error("Failed to load decrypted module: " .. (load_err or "load error"));
    end

    -- 4. Execute to get the module table
    local ok, result = pcall(func);
    if not ok then
        return critical_error("Failed to execute decrypted module: " .. (result or "execution error"));
    end
    return result;
end

-- Example: Your decryption function (MUST BE SECURED/OBFUSCATED HEAVILY)
-- This is a TOY example. Real crypto is needed.
local SUPER_SECRET_KEY_MATERIAL = "my_very_secret_key_part_that_is_itself_obfuscated_or_derived";
function DECRYPT_FUNC(data, key_material_ignored_for_toy_example)
    -- In a real system, key_material_ignored_for_toy_example would be used.
    -- This is a simple XOR cipher for demonstration. DO NOT USE IN PRODUCTION.
    local key = SUPER_SECRET_KEY_MATERIAL;
    local key_len = #key;
    local decrypted_bytes = {};
    for i = 1, #data do
        decrypted_bytes[i] = string.char(string.byte(data, i) ~ string.byte(key, (i-1)%key_len + 1));
    end
    return table.concat(decrypted_bytes);
end


-- Configure package.path for require (if still needed for non-encrypted parts or initial loader)
local script_path_str;
local ok_path, path_info = pcall(function() return debug.getinfo(2, "S").source:sub(2) end);
if ok_path and type(path_info) == "string" then
    script_path_str = path_info:match("(.*[/%\\])");
else
    -- Fallback or error if path cannot be determined.
    -- This is critical. If script_path fails, loading modules will fail.
    -- For a "bulletproof" system, you might embed a known relative path
    -- or have a C component provide the base path.
    return critical_error("Could not determine script path. Debug info might be stripped or altered.");
end

local oldPkgPath = package.path;
if script_path_str then
    package.path = script_path_str .. "?.lua;" .. script_path_str .. "?.luac;" .. package.path;
    -- If using encrypted modules, you might not even need to modify package.path
    -- if 'secure_load_module' handles paths directly.
else
    -- Handle missing script_path_str (e.g., error out, or assume current dir)
    -- For now, we'll let it proceed, but 'secure_load_module' would need full paths.
end


-- Math.random Fix for Lua5.1 (Good for compatibility)
if not pcall(function() return math.random(1, 2^40); end) then
    local oldMathRandom = math.random;
    math.random = function(a, b)
        if not a and not b then -- Fixed condition: was 'not a and b'
            return oldMathRandom();
        end
        if not b then
            b = a; a = 1; -- Fixed: math.random(x) means math.random(1,x)
        end
        if a > b then a, b = b, a; end
        local diff = b - a;
        if diff < 0 then -- Should not happen if a<=b
             critical_error("math.random range error after swap"); return a;
        end

        if diff > 2147483647 then -- 2^31 - 1
            -- This part of the fix is for very large ranges, common in LuaJIT but not standard 5.1 math.random limits
            -- Standard math.random uses doubles, so precision is the issue for large integers.
            -- The original fix might be specific to a certain Lua implementation or for generating
            -- numbers beyond typical integer limits by using floating point arithmetic.
            -- For standard Lua 5.1, math.random(a,b) should work if a,b are within integer limits.
            -- If aiming for numbers larger than 2^31, this floating point approach is one way.
            return math.floor(oldMathRandom() * (diff + 1) + a); -- +1 for inclusive range
        else
            return oldMathRandom(a, b);
        end
    end
end

-- newproxy polyfill (Good for compatibility)
_G.newproxy = _G.newproxy or function(arg)
    -- The original newproxy(true) creates a userdata with a metatable that can have __gc etc.
    -- newproxy(false) or newproxy() creates a userdata with no metatable.
    -- This polyfill is a simplification. For true 'newproxy' behavior with finalizers,
    -- a C implementation or a more complex Lua proxy table trick is needed.
    -- What's here is fine for many use cases where just a unique, un-interfering table is needed.
    if arg == true then -- Match original behavior for newproxy(true) more closely
        local u = newproxy(false); -- Get a bare userdata
        setmetatable(u, {}); -- Give it an empty metatable
        return u;
    elseif arg == false or arg == nil then
        -- Standard newproxy(false) / newproxy() returns a bare userdata.
        -- Lua 5.2+ don't have newproxy. Creating a unique table is a common substitute.
        -- However, `newproxy` creates a USERDATA, not a table. This matters for `type()`.
        -- A more accurate polyfill for `newproxy(false)` if a real userdata is needed
        -- and `newproxy` is truly absent (like in Lua 5.2+ when not built with compat):
        -- return coroutine.create(function() end) -- This is a userdata (thread)
        -- For simplicity, returning a table is often "good enough" if type doesn't matter.
        -- The original polyfill was:
        -- if arg then return setmetatable({}, {}); end return {};
        -- Let's stick to a closer approximation if type matters, or the simple table if not.
        -- Given this is for an obfuscator which might run on various Lua versions:
        return {}; -- Simplest, but returns a table, not userdata.
                   -- If you need actual userdata for some obfuscation trick, this needs to be rethought.
    end
    return {}; -- Fallback
end


-- Determine the key for decrypting modules.
-- This key itself should be protected.
-- e.g., derived from machine specific info, fetched, split into parts,
-- or heavily obfuscated in a C component.
-- For this example, we use the one defined near DECRYPT_FUNC
local MODULE_DECRYPTION_KEY = SUPER_SECRET_KEY_MATERIAL;


-- Require Prometheus Submodules (Now using the secure loader)
-- The paths here would point to your encrypted files.
-- Example: "prometheus/pipeline.luac.enc"
local PipelineModName  = script_path_str .. "prometheus/pipeline.obf"; -- Adjust extension
local HighlightModName = script_path_str .. "highlightlua.obf";
local ColorsModName    = script_path_str .. "colors.obf";
local LoggerModName    = script_path_str .. "logger.obf";
local PresetsModName   = script_path_str .. "presets.obf";
local ConfigModName    = script_path_str .. "config.obf";
local UtilModName      = script_path_str .. "prometheus/util.obf";

-- Actual loading, assuming DECRYPT_FUNC and secure_load_module are robustly defined above
-- and your modules have been pre-processed (obfuscated, bytecompiled, encrypted)
local Pipeline  = secure_load_module(PipelineModName, MODULE_DECRYPTION_KEY);
local highlight = secure_load_module(HighlightModName, MODULE_DECRYPTION_KEY);
local colors    = secure_load_module(ColorsModName, MODULE_DECRYPTION_KEY);
local Logger    = secure_load_module(LoggerModName, MODULE_DECRYPTION_KEY);
local Presets   = secure_load_module(PresetsModName, MODULE_DECRYPTION_KEY);
local Config    = secure_load_module(ConfigModName, MODULE_DECRYPTION_KEY);
local util      = secure_load_module(UtilModName, MODULE_DECRYPTION_KEY);

-- Critical check: Ensure all modules loaded
if not (Pipeline and highlight and colors and Logger and Presets and Config and util) then
    -- Error already printed by secure_load_module, but we need to halt.
    -- In a prod system, this might trigger a more subtle failure.
    return critical_error("One or more core Prometheus modules failed to load securely.");
end

-- Restore package.path (if it was modified and you want to sandbox subsequent requires)
package.path = oldPkgPath;
oldPkgPath = nil; -- Clear reference

-- Tamper-proofing the loaded modules (conceptual)
-- The 'util.readonly' is a good start for config.
-- For other modules, you might freeze them or replace their metatables
-- to prevent modification, if they aren't already designed to be immutable.
-- This is more about runtime integrity than anti-dumping.

if util and util.readonly then
    Config = util.readonly(Config); -- Readonly for Config is good.
else
    critical_error("Prometheus util module or readonly function not available after load.");
    -- Cannot proceed if core utils are broken
    return nil;
end


-- Self-destruct sensitive functions or data after initialization if they are no longer needed
DECRYPT_FUNC = nil;
SUPER_SECRET_KEY_MATERIAL = nil;
MODULE_DECRYPTION_KEY = nil;
secure_load_module = nil;
-- Any other sensitive setup functions should be nilled out.

-- Final check before exporting
if not (Pipeline and highlight and colors and Logger and Presets and Config) then
    -- This is a fallback, should have been caught earlier.
    -- Silently fail or cause a less obvious error.
    local m = {}
    setmetatable(m, { __index = function() critical_error("Prometheus is not operational."); return function() end end})
    return m;
end

-- Export
return {
    Pipeline  = Pipeline;
    colors    = colors;
    Config    = Config; -- Already readonly
    Logger    = Logger;
    highlight = highlight;
    Presets   = Presets;
    -- Not exporting 'util' by default unless it's part of the public API.
}
