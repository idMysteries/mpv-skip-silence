/* mpv integration with auto-editor (https://github.com/WyattBlue/auto-editor)
 *
 * Changelog:
 * https://github.com/idMysteries/mpv-skip-silence/commits
 * == v3 (2022/03/28)
 * Made the script work with the new version of auto-editor
 * == v2 (2022/02/01)
 * The script can now invoke auto-editor automatically with a keybind.
 *
 * Limitations:
 * 1. The video must have a constant frame-rate; variable frame rate sources,
 *    sources with frame skips will have issues.
 *
 * Copyright 2022 Tatsuyuki Ishi <ishitatsuyuki@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var AUTO_EDITOR_BIN = "auto-editor";
var AUTO_EDITOR_ARGS = ["--export_as_json", "-mcut", "60", "-t", "0.04"];
var SILENCE_SPEED = 3;

var in_silence = false;
var restore_speed = 1.0;

var timeObserver;

var cmdInProgress = false;

function runAutoEditor() {
	if (cmdInProgress) {
		mp.osd_message("auto-editor: An analysis is already in progress");
		return;
	}
	var file = mp.get_property("path");
	var cmd = {
		name: "subprocess",
		playback_only: false,
		args: [AUTO_EDITOR_BIN, file].concat(AUTO_EDITOR_ARGS)
	};
	mp.osd_message("auto-editor: Running analysis");
	cmdInProgress = true;
	mp.command_native_async(cmd, function (success, result, error) {
		cmdInProgress = false;
		if (success) {
			load();
		} else {
			mp.msg.error(error);
		}
	});
}

function load() {
	unload(); // Unload previous callbacks
	var file = mp.get_property("path");
	file = file.replace(/\.[^.]+$/, ".json");
	var content;
	try {
		content = JSON.parse(mp.utils.read_file(file));
	} catch (e) {
		return;
	}
  
	var segments = content["chunks"]
	if (segments.length < 1) return;
  
	mp.osd_message(
		"auto-editor: Loaded " + segments.length + " segments"
	);
  
	var current_segment = segments[0];
  
	timeObserver = function (_name, time) {
		var frame = mp.get_property_number("estimated-frame-number");
	
		if (frame >= current_segment[0] && frame < current_segment[1]) {
			if (current_segment[2] === 99999) {
				if (in_silence === false){
					in_silence = true;
					restore_speed = mp.get_property_number("speed");
					mp.set_property("speed", SILENCE_SPEED);
				}
			}
			else {
				if (in_silence){
					in_silence = false;
					mp.set_property("speed", restore_speed);
				}
			}
		}
		else {
			for (var i = 0; i < segments.length; i++) {
				if (frame < segments[i][1]) {
					current_segment = segments[i];
					break;
				}
			}
		}
	};
	mp.observe_property("time-pos", "number", timeObserver);
}

function unload() {
	if (timeObserver != null) {
		mp.unobserve_property(timeObserver);
		timeObserver = null;
	}
}

mp.register_event("start-file", load);
mp.register_event("end-file", unload);
mp.add_key_binding("E", "run-auto-editor", runAutoEditor);
