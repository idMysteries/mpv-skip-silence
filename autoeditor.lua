-- mpv integration with auto-editor (https://github.com/WyattBlue/auto-editor)

local utils = require "mp.utils"
local msg = require "mp.msg"
local options = require "mp.options"

local AUTO_EDITOR_BIN = "auto-editor"

local config = {
    auto_run = false,
    restore_speed = 1.0,
    silence_speed = 2.5,
    mincut = 60,
    threshold = 4,
    margin = "20,6",
}

options.read_options(config, "autoeditor")

local in_silence = false
local time_observer = nil
local cmd_in_progress = false

local function update_playback_speed(speed)
    mp.set_property("speed", speed)
    msg.info("Speed set to: " .. speed)
end

local function process_segment(segment, frame)
    if frame >= segment[1] and frame < segment[2] then
        local is_silence = segment[3] == 99999
        if is_silence ~= in_silence then
            in_silence = is_silence
            
            if is_silence then
				local current_speed = mp.get_property_number("speed")
                if current_speed ~= config.silence_speed then
                    config.restore_speed = current_speed
                end
                update_playback_speed(config.silence_speed)
            else
                update_playback_speed(config.restore_speed)
            end
        end
        return true
    end
    return false
end

local function load_segments(json)
    if time_observer then
        mp.unobserve_property(time_observer)
        time_observer = nil
        in_silence = false
        update_playback_speed(config.restore_speed)
    end
    
    local parsed_content = utils.parse_json(json)
    if not parsed_content then
        msg.error("Failed to parse JSON: " .. json)
        return
    end
    
    local segments = parsed_content["chunks"]
    if #segments < 1 then return end
    
    mp.osd_message("auto-editor: Loaded " .. #segments .. " segments")
    
    time_observer = function(_, time)
        local frame = mp.get_property_number("estimated-frame-number") or 0
        for _, segment in ipairs(segments) do
            if process_segment(segment, frame) then
                break
            end
        end
    end
    
    mp.observe_property("time-pos", "number", time_observer)
end

local function execute_auto_editor()
    if cmd_in_progress then
        mp.osd_message("auto-editor: An analysis is already in progress")
        return
    end
    
    local file = mp.get_property("path")
    local auto_editor_args = {
        "--export", "timeline:api=1",
        "--quiet",
        "--progress", "none",
        "--margin", config.margin,
        "--edit", string.format("audio:mincut=%d,threshold=%d%%", config.mincut, config.threshold)
    }
    
    local cmd = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {AUTO_EDITOR_BIN, file, table.unpack(auto_editor_args)}
    }
    
    mp.osd_message("auto-editor: Running analysis")
    cmd_in_progress = true
    
    mp.command_native_async(cmd, function(success, result, error)
        cmd_in_progress = false
        if success then
            load_segments(result.stdout)
		else
            msg.error("Auto-editor error: " .. (error or "Unknown error"))
            mp.osd_message("Auto-editor failed: " .. (error or "Unknown error"))
        end
    end)
end

local function auto_start_analysis()
    if config.auto_run then
        execute_auto_editor()
    end
end

mp.add_key_binding("E", "run-auto-editor", execute_auto_editor)
mp.register_event("file-loaded", auto_start_analysis)

local function display_settings()
    local settings_str = string.format(
        "Auto-editor settings:\n" ..
        "Auto-run: %s\n" ..
        "Restore speed: %.2f\n" ..
        "Silence speed: %.2f\n" ..
        "Mincut: %d\n" ..
        "Threshold: %d%%\n" ..
        "Margin: %s",
        tostring(config.auto_run),
        config.restore_speed,
        config.silence_speed,
        config.mincut,
        config.threshold,
        config.margin
    )
    mp.osd_message(settings_str, 5)
    msg.info(settings_str)
end

mp.add_key_binding("Ctrl+E", "print-auto-editor-settings", display_settings)
