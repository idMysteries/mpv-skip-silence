-- MPV integration with auto-editor (https://github.com/WyattBlue/auto-editor)

local utils = require "mp.utils"
local msg = require "mp.msg"
local options = require "mp.options"

local AUTO_EDITOR_BIN = "auto-editor"

local config = {
    enabled = false,
    restore_speed = 1.0,
    silence_speed = 2.5,
    threshold = "4%",
    margin = "0.1s,0.2s",
    mincut = "1s",
}
options.read_options(config)

local time_observer = nil
local cmd_in_progress = false

local function update_playback_speed(speed)
    mp.set_property("speed", speed)
    msg.info("Speed set to: " .. speed)
end

local function is_local_file(file_path)
    if not file_path then
        return false
    end
    local file_info = utils.file_info(file_path)
    return file_info ~= nil and file_info.is_file
end

local function load_segments(json)
    if time_observer then
        mp.unobserve_property(time_observer)
        time_observer = nil
        update_playback_speed(config.restore_speed)
    end

    local parsed_content = utils.parse_json(json)
    if not parsed_content then
        msg.error("Failed to parse JSON.")
        return
    end

    local segments = parsed_content["chunks"]
    if not segments or #segments < 1 then
        msg.warn("No segments found.")
        return
    end

    mp.osd_message("Loaded " .. #segments .. " segments")
    msg.info("Loaded " .. #segments .. " segments")

    local current_segment = nil
    time_observer = function(_, time)
        local frame = mp.get_property_number("estimated-frame-number") or 0
        if current_segment and frame >= current_segment[1] and frame < current_segment[2] then
            return
        end
        for _, segment in ipairs(segments) do
            if frame >= segment[1] and frame < segment[2] then
                current_segment = segment
                if segment[3] == 99999 then
                    local current_speed = mp.get_property_number("speed")
                    if current_speed < config.silence_speed then
                        config.restore_speed = current_speed
                        update_playback_speed(config.silence_speed)
                    end
                else
                    update_playback_speed(config.restore_speed)
                end
                return
            end
        end
        current_segment = nil
    end

    mp.observe_property("time-pos", "number", time_observer)
end

local function execute_auto_editor()
    if cmd_in_progress then
        mp.osd_message("Analysis is already in progress")
        msg.info("Analysis is already in progress")
        return
    end

    local file = mp.get_property("path")
    if not is_local_file(file) then
        mp.osd_message("auto-editor: disabled for network streams")
        msg.info("Disabled for network streams")
        return
    end

    local audio_stream_index = (mp.get_property_number("aid") or 1) - 1

    local auto_editor_args = {
        file,
        "--export", "timeline:api=1",
        "--quiet",
        "--no-cache",
        "--progress", "none",
        "--margin", config.margin,
        "--edit", string.format("audio:stream=%d,threshold=%s,mincut=%s", audio_stream_index, config.threshold, config.mincut)
    }

    local cmd = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {AUTO_EDITOR_BIN, unpack(auto_editor_args)}
    }

    mp.osd_message("Running analysis")
    msg.info("Running analysis")
    cmd_in_progress = true

    mp.command_native_async(cmd, function(success, result, error)
        cmd_in_progress = false
        if success then
            load_segments(result.stdout)
        else
            local err_msg = error or "Unknown error"
            msg.error("Error: " .. err_msg)
            mp.osd_message("Error: " .. err_msg)
        end
    end)
end

local function auto_start_analysis()
    if config.enabled then
        if is_local_file(mp.get_property("path")) then
            execute_auto_editor()
        else
            mp.osd_message("auto-editor: disabled for network streams")
            msg.info("Disabled for network streams")
        end
    end
end

local function display_settings()
    local settings_str = string.format(
        "Auto-editor settings:\n" ..
        "Auto-run: %s\n" ..
        "Restore speed: %.2f\n" ..
        "Silence speed: %.2f\n" ..
        "Threshold: %s\n" ..
        "Margin: %s",
        tostring(config.enabled),
        config.restore_speed,
        config.silence_speed,
        config.threshold,
        config.margin
    )
    mp.osd_message(settings_str, 5)
    msg.info(settings_str)
end

mp.add_key_binding("E", "run-auto-editor", execute_auto_editor)
mp.add_key_binding("Ctrl+E", "print-auto-editor-settings", display_settings)
mp.register_event("file-loaded", auto_start_analysis)
