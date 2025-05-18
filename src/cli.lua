-- cli.lua for Relax Obfuscator
-- This script contains the Code for the Relax Obfuscator CLI

-- Strict mode and localized globals for cleaner scope and minor obfuscation
local _G = _G
local string = string
local table = table
local io = io
local os = os
local pcall = pcall
local loadstring = loadstring or load -- Lua 5.1 uses loadstring, 5.2+ uses load
local setfenv = setfenv -- Only available in Lua 5.1 or compatibility mode
local debug = debug -- Only for script_path, ideally minimized

--[[
    Securely load the Relax Obfuscator engine.
    In a "bulletproof" setup, 'relax_obfuscator_core.lua' (or a similar name)
    would be the entrypoint we discussed previously, which handles loading
    its own encrypted/obfuscated modules. This CLI script itself might also
    be lightly obfuscated or bytecompiled, but its main job is to call
    the heavily protected core.
--]]
local RelaxObfuscator
local script_path_str
local old_package_path = package.path

local function get_script_path()
    -- Using debug.getinfo is common but can be a point of failure if debug is stripped/altered.
    -- For a CLI tool distributed to users, a more robust method might involve
    -- finding the executable's path or assuming a relative structure.
    local success, info = pcall(function() return debug.getinfo(2, "S") end)
    if success and info and info.source and info.source:sub(1,1) == "@" then
        local path = info.source:sub(2)
        return path:match("(.*[/%\\])")
    end
    -- Fallback: current directory (less reliable for finding sibling modules)
    return "./"
end

script_path_str = get_script_path()
package.path = script_path_str .. "?.lua;" .. script_path_str .. "?.luac;" .. package.path

local ok, core_module = pcall(function()
    ---@diagnostic disable-next-line: different-requires
    return require("relax_obfuscator_core") -- This is your main protected entrypoint
end)

if not ok or not core_module then
    io.stderr:write("CRITICAL ERROR: Failed to load Relax Obfuscator engine.\n")
    if core_module then -- Contains error message from pcall
        io.stderr:write("Reason: " .. tostring(core_module) .. "\n")
    end
    io.stderr:write("Please ensure Relax Obfuscator is installed correctly.\n")
    os.exit(2) -- Use a distinct exit code for core load failure
end
RelaxObfuscator = core_module
package.path = old_package_path -- Restore package.path
old_package_path = nil
script_path_str = nil -- Don't need it anymore

-- Set default log level if not already set by core
RelaxObfuscator.Logger.logLevel = RelaxObfuscator.Logger.logLevel or RelaxObfuscator.Logger.LogLevel.Info

-- Utility functions (localized)
local function file_exists(filePath)
    local f, err = io.open(filePath, "rb")
    if f then f:close() end
    return f ~= nil
end

-- Improved string.split that handles empty fields if sep is repeated
-- and respects Lua patterns if sep is a pattern character.
local function string_split(str_to_split, sep)
    if sep == nil then sep = "%s" end -- Default to whitespace
    local fields = {}
    local pattern = string.format("([^%s]*)%s", sep, sep) -- Capture content before separator
    local last_pos = 1
    string.gsub(str_to_split .. sep, pattern, function(c, pos)
        fields[#fields + 1] = c
        last_pos = pos
    end)
    -- If the string doesn't end with a separator, gsub might miss the last field
    -- or if the string is empty. This original gsub approach is more for non-empty fields.
    -- A simpler approach for basic separators:
    if #sep == 1 then -- Simple character separator
        fields = {}
        local current_field = ""
        for i = 1, #str_to_split do
            local char = str_to_split:sub(i,i)
            if char == sep then
                table.insert(fields, current_field)
                current_field = ""
            else
                current_field = current_field .. char
            end
        end
        table.insert(fields, current_field) -- Add the last field
        return fields
    else -- For pattern separators, the original gsub is better but may need tweaks for edge cases
        fields = {}
        local pat = string.format("([^%s]+)", sep)
        string.gsub(str_to_split, pat, function(c) fields[#fields+1] = c end)
        return fields
    end
end
-- Note: Lua 5.3+ has string.gmatch which can be used more elegantly for splitting.
-- For wider compatibility, a manual loop or the gsub trick is common.
-- The provided original string.split is generally fine for simple cases.

local function read_file_lines(filePath)
    if not file_exists(filePath) then return {} end
    local lines = {}
    for line in io.lines(filePath) do
      lines[#lines + 1] = line
    end
    return lines
end

local function read_file_content(filePath)
    local f, err = io.open(filePath, "rb")
    if not f then
        RelaxObfuscator.Logger:error(string.format("Cannot open file \"%s\": %s", filePath, err or "unknown error"))
        return nil -- Error handled by logger, which might exit
    end
    local content = f:read("*a")
    f:close()
    if not content then
         RelaxObfuscator.Logger:error(string.format("Cannot read file content from \"%s\"", filePath))
         return nil
    end
    return content
end


-- CLI State
local obfuscation_config
local source_file_path
local output_file_path
local selected_lua_version
local force_pretty_print

RelaxObfuscator.colors.enabled = true -- Default, can be overridden

-- Argument Parsing
local cli_args = _G.arg or {}
local i = 1
while i <= #cli_args do
    local current_arg = cli_args[i]

    if current_arg:sub(1, 2) == "--" then
        local option = current_arg
        local value
        -- Check if next argument is a value for this option or another option
        if i + 1 <= #cli_args and cli_args[i+1]:sub(1,2) ~= "--" then
            value = cli_args[i+1]
        end

        if option == "--preset" or option == "-p" then
            if not value then RelaxObfuscator.Logger:error("Missing value for option " .. option); goto next_arg end
            if obfuscation_config then RelaxObfuscator.Logger:warn("Configuration/Preset specified multiple times. Last one takes precedence.") end
            local preset = RelaxObfuscator.Presets[value]
            if not preset then
                RelaxObfuscator.Logger:error(string.format("Preset \"%s\" not found!", tostring(value)))
            else
                -- Deep copy the preset to avoid modifying the original in RelaxObfuscator.Presets
                obfuscation_config = RelaxObfuscator.util and RelaxObfuscator.util.deepCopy and RelaxObfuscator.util.deepCopy(preset) or preset
            end
            i = i + 1 -- Consumed value
        elseif option == "--config" or option == "-c" then
            if not value then RelaxObfuscator.Logger:error("Missing value for option " .. option); goto next_arg end
            if obfuscation_config then RelaxObfuscator.Logger:warn("Configuration/Preset specified multiple times. Last one takes precedence.") end
            local config_file_path = tostring(value)
            local config_content = read_file_content(config_file_path)
            if config_content then
                local func, err = loadstring(config_content, "@" .. config_file_path)
                if not func then
                    RelaxObfuscator.Logger:error(string.format("Error loading config file \"%s\": %s", config_file_path, err or "unknown error"))
                else
                    if setfenv then -- Lua 5.1
                        -- Basic sandboxing: provide a new empty environment.
                        -- More advanced sandboxing might involve providing specific safe globals.
                        local sandbox_env = {}
                        -- Optionally, provide very safe globals if the config needs them
                        -- sandbox_env.print = print 
                        -- sandbox_env.string = string
                        -- sandbox_env.table = table
                        setfenv(func, sandbox_env)
                    else -- Lua 5.2+ (load has _ENV parameter for sandboxing)
                        -- load(config_content, "@" .. config_file_path, "t", {}) would be an option
                        -- but for simplicity, assume config files are trusted or sandboxing is more complex.
                        -- The `loadstring` above doesn't allow specifying _ENV directly for 5.2+.
                        -- You'd use `load(reader_func, chunkname, mode, env)`
                        RelaxObfuscator.Logger:warn("Sandboxing config files with setfenv is not available in this Lua version. Config will run in current environment.")
                    end

                    local success_call, result = pcall(func)
                    if not success_call then
                        RelaxObfuscator.Logger:error(string.format("Error executing config file \"%s\": %s", config_file_path, result or "unknown error"))
                    elseif type(result) ~= "table" then
                        RelaxObfuscator.Logger:error(string.format("Config file \"%s\" did not return a table.", config_file_path))
                    else
                        obfuscation_config = result
                    end
                end
            end
            i = i + 1 -- Consumed value
        elseif option == "--out" or option == "-o" then
            if not value then RelaxObfuscator.Logger:error("Missing value for option " .. option); goto next_arg end
            if output_file_path then RelaxObfuscator.Logger:warn("Output file specified multiple times. Last one takes precedence.") end
            output_file_path = value
            i = i + 1 -- Consumed value
        elseif option == "--nocolors" then
            RelaxObfuscator.colors.enabled = false
        elseif option == "--lua51" then
            selected_lua_version = "Lua51"
        elseif option == "--luau" then
            selected_lua_version = "LuaU"
        -- Add other Lua versions as needed: --lua52, --lua53, --lua54, --luajit
        elseif option == "--pretty" then
            force_pretty_print = true
        elseif option == "--nopretty" then -- Explicitly disable pretty print
            force_pretty_print = false
        elseif option == "--verbose" or option == "-v" then
            RelaxObfuscator.Logger.logLevel = RelaxObfuscator.Logger.LogLevel.Debug
        elseif option == "--quiet" or option == "-q" then
            RelaxObfuscator.Logger.logLevel = RelaxObfuscator.Logger.LogLevel.Error
        elseif option == "--saveerrors" then
            RelaxObfuscator.Logger.errorCallback = function(...)
                local logger_name = RelaxObfuscator.Config and RelaxObfuscator.Config.ObfuscatorNameUpper or "RELAX_OBFUSCATOR"
                local error_prefix = logger_name .. ": "
                local colored_message = RelaxObfuscator.colors(error_prefix .. ..., "red")
                
                -- Print to stderr for console visibility
                io.stderr:write(colored_message .. "\n")
                
                local args_tbl = {...}
                local raw_message = table.concat(args_tbl, " ")
                
                local error_file_name
                if source_file_path then
                     error_file_name = source_file_path:match("(.+)%.[^%.]+$") or source_file_path -- try to remove extension
                     error_file_name = error_file_name .. ".error.txt"
                else
                    error_file_name = "relax_obfuscator.error.txt"
                end

                local h, err_io = io.open(error_file_name, "w")
                if h then
                    h:write("Error reported by Relax Obfuscator:\n")
                    h:write(raw_message)
                    h:close()
                    io.stderr:write("Error details saved to: " .. error_file_name .. "\n")
                else
                    io.stderr:write("Failed to save error details to file: " .. (err_io or "unknown I/O error") .. "\n")
                end

                os.exit(1)
            end
        elseif option == "--version" then
            local ro_version = RelaxObfuscator.Config and RelaxObfuscator.Config.ObfuscatorNameAndVersion or "Relax Obfuscator (version unknown)"
            print(ro_version)
            os.exit(0)
        elseif option == "--help" or option == "-h" then
            local ro_name = RelaxObfuscator.Config and RelaxObfuscator.Config.ObfuscatorName or "Relax Obfuscator"
            print(string.format("%s - Lua Obfuscator", ro_name))
            print("Usage: lua cli.lua [options] <sourcefile>")
            print("\nOptions:")
            print("  <sourcefile>             Path to the Lua script to obfuscate.")
            print("  --preset <name>, -p <name> Select a built-in obfuscation preset (e.g., Minify, Lite, Default, Strong, Paranoid).")
            print("  --config <file>, -c <file> Use a custom Lua configuration file returning a config table.")
            print("  --out <file>, -o <file>  Specify the output file path.")
            print("  --lua51                  Set target Lua version to 5.1.")
            print("  --luau                   Set target Lua version to Luau.")
            -- Add other Lua versions here
            print("  --pretty                 Enable pretty printing of the output (overrides preset).")
            print("  --nopretty               Disable pretty printing of the output (overrides preset).")
            print("  --nocolors               Disable colored output in the console.")
            print("  --saveerrors             Save error messages to a .error.txt file next to the source file.")
            print("  --verbose, -v            Enable verbose logging.")
            print("  --quiet, -q              Suppress informational and warning messages (only errors).")
            print("  --version                Display obfuscator version and exit.")
            print("  --help, -h               Display this help message and exit.")
            print("\nIf no preset or config is specified, 'Minify' is used by default.")
            print("If no output file is specified, it defaults to '<sourcefile>.obfuscated.lua'.")
            os.exit(0)
        else
            RelaxObfuscator.Logger:warn(string.format("Unknown option \"%s\" ignored.", option))
        end
    else
        if source_file_path then
            RelaxObfuscator.Logger:error(string.format("Unexpected argument \"%s\". Source file already specified as \"%s\".", current_arg, source_file_path))
        else
            source_file_path = tostring(current_arg)
        end
    end
    ::next_arg::
    i = i + 1
end

-- Validate inputs and set defaults
if not source_file_path then
    RelaxObfuscator.Logger:error("No input file specified. Use --help for usage information.")
end

if not file_exists(source_file_path) then
    RelaxObfuscator.Logger:error(string.format("Input file \"%s\" not found!", source_file_path))
end

if not obfuscation_config then
    local default_preset_name = "Minify" -- Or "Lite" or "Default" as your preferred default
    RelaxObfuscator.Logger:warn("No configuration specified, falling back to '" .. default_preset_name .. "' preset.")
    obfuscation_config = RelaxObfuscator.util and RelaxObfuscator.util.deepCopy and RelaxObfuscator.util.deepCopy(RelaxObfuscator.Presets[default_preset_name]) or RelaxObfuscator.Presets[default_preset_name]
    if not obfuscation_config then
        RelaxObfuscator.Logger:error("Default preset '" .. default_preset_name .. "' is missing! Cannot proceed.")
    end
end

-- Apply command-line overrides to the loaded config
obfuscation_config.LuaVersion = selected_lua_version or obfuscation_config.LuaVersion
if force_pretty_print ~= nil then
    obfuscation_config.PrettyPrint = force_pretty_print
end

-- Determine output file path if not specified
if not output_file_path then
    if source_file_path:match("%.lua$") then -- Ends with .lua
        output_file_path = source_file_path:gsub("%.lua$", ".obfuscated.lua")
    elseif source_file_path:match("%.luau$") then -- Ends with .luau
         output_file_path = source_file_path:gsub("%.luau$", ".obfuscated.luau")
    else
        output_file_path = source_file_path .. ".obfuscated.lua" -- Default extension
    end
end

-- Read source file content
RelaxObfuscator.Logger:info(string.format("Processing \"%s\"...", source_file_path))
local source_code = read_file_content(source_file_path)
if not source_code then
    RelaxObfuscator.Logger:error("Failed to read source code. Aborting.") -- Should have been caught by read_file_content
end

-- Create and apply pipeline
local pipeline, err_pipeline = RelaxObfuscator.Pipeline:fromConfig(obfuscation_config)
if not pipeline then
    RelaxObfuscator.Logger:error("Failed to create obfuscation pipeline: " .. (err_pipeline or "unknown error"))
end

local obfuscated_code, err_apply = pipeline:apply(source_code, source_file_path)
if not obfuscated_code then
    RelaxObfuscator.Logger:error("Obfuscation pipeline failed: " .. (err_apply or "unknown error"))
end

-- Write output
RelaxObfuscator.Logger:info(string.format("Writing output to \"%s\"", output_file_path))
local out_handle, err_io_w = io.open(output_file_path, "w")
if not out_handle then
    RelaxObfuscator.Logger:error(string.format("Could not open output file \"%s\" for writing: %s", output_file_path, err_io_w or "unknown I/O error"))
end
local success_write, err_write = out_handle:write(obfuscated_code)
if not success_write then
     RelaxObfuscator.Logger:error(string.format("Could not write to output file \"%s\": %s", output_file_path, err_write or "unknown I/O error"))
end
out_handle:close()

RelaxObfuscator.Logger:info("Obfuscation complete.")
