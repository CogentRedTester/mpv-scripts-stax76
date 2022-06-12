
--[[
    This script changes options depending on what type of
    file is played. It uses the file extension to detect
    if the current file is a video, audio or image file.

    The changes happen not on every file load, but only
    when a mode change is detected.

    On mode change 3 things can be done:

    1. Change options
    2. Change key bindings
    3. Send messages

    The configuration is done in code.
]]--


function on_video_mode_activate()
    mp.set_property("osd-playing-msg", "${media-title}") -- in video mode use media-title for osd-playing-msg
end

function on_audio_mode_activate()
    mp.set_property("osd-playing-msg", "${filtered-metadata}") -- show MP3 tags in audio mode. In mpv.conf define: display-tags = Artist,Title,Album,Date,Genre,Rating,Comment,Description
end

function on_image_mode_activate()
    mp.command("no-osd set osd-playing-msg ''")               -- disable osd-playing-msg for images
    mp.command("no-osd set background '#1A2226'")             -- use dark grey background for images
    mp.command("script-message osc-visibility never no_osd")  -- disable osc for images
end

function on_video_mode_deactivate()
end

function on_audio_mode_deactivate()
end

function on_image_mode_deactivate()
    mp.command("no-osd set background '#000000'")             -- use black background for audio and video
    mp.command("script-message osc-visibility auto no_osd")   -- enable osc for audio and video
end

function on_type_change(old_ext, new_ext)
    if new_ext == ".gif" then
        mp.command("no-osd set osd-level 0")     -- disable OSD for GIF
        mp.command("no-osd set loop-file inf")   -- loop GIF files
    end

    if old_ext == ".gif" then
        mp.command("no-osd set osd-level 1")     -- enable OSD for anything except GIF
        mp.command("no-osd set loop-file no")    -- use loop-file=no for anything except GIF
    end
end

audio_mode_bindings = {
}

image_mode_bindings = {
    { "UP",     function () mp.command("no-osd add video-pan-y -0.02") end, { repeatable = true } },
    { "DOWN",   function () mp.command("no-osd add video-pan-y  0.02") end, { repeatable = true } },
    { "LEFT",   function () mp.command("playlist-prev") end,                { repeatable = true } },
    { "RIGHT",  function () mp.command("playlist-next") end,                { repeatable = true } },
    { "SPACE",  function () mp.command("playlist-next") end,                { repeatable = true } },
    { "BS",     function () mp.command("no-osd set video-pan-y 0; no-osd set video-zoom 0") end   },
}

image_file_extensions = { ".jpg", ".png", ".bmp", ".gif", ".webp" }
audio_file_extensions = { ".mp3", ".ogg", ".opus", ".flac", ".m4a", ".mka", ".ac3", ".dts", ".dtshd", ".dtshr", ".dtsma", ".eac3", ".mp2", ".mpa", ".thd", ".w64", ".wav", ".aac" }

----- end config

----- string

function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

----- path

function get_ext(path)
    if path == nil then return nil end
    local val = path:match("^.+(%.[^%./\\]+)$")
    if val == nil then return nil end
    return val:lower()
end

----- list

function list_contains(list, value)
    for _, v in pairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

----- mpv

-- msg = require 'mp.msg' --   msg.warn()   msg.error()
-- mp.osd_message("hello")

----- mpv key bindings

function add_bindings(definition)
    if type(active_bindings) ~= "table" then
        active_bindings = {}
    end

    local script_name = mp.get_script_name()

    for _, bind in ipairs(definition) do
        local name = script_name .. "_key_" .. (#active_bindings + 1)
        active_bindings[#active_bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2], bind[3])
    end
end

function remove_bindings()
    if type(active_bindings) == "table" then
        for _, name in ipairs(active_bindings) do
            mp.remove_key_binding(name)
        end
    end
end

----- image-mode

active_mode = "video"
last_type = nil

function enable_video_mode()
    if active_mode == "video" then return end
    active_mode = "video"
    remove_bindings()
    on_video_mode_activate()
end

function enable_audio_mode()
    if active_mode == "audio" then return end
    active_mode = "audio"
    remove_bindings()
    add_bindings(audio_mode_bindings)
    on_audio_mode_activate()
end

function enable_image_mode()
    if active_mode == "image" then return end
    active_mode = "image"
    remove_bindings()
    add_bindings(image_mode_bindings)
    on_image_mode_activate()
end

function disable_video_mode()
    if active_mode ~= "video" then return end
    active_mode = nil
    remove_bindings()
    on_video_mode_deactivate()
end

function disable_image_mode()
    if active_mode ~= "image" then return end
    active_mode = nil
    remove_bindings()
    on_image_mode_deactivate()
end

function disable_audio_mode()
    if active_mode ~= "audio" then return end
    active_mode = nil
    remove_bindings()
    on_audio_mode_deactivate()
end

function update(event)
    local ext = get_ext(mp.get_property("path"))

    if list_contains(image_file_extensions, ext) then
        disable_video_mode()
        disable_audio_mode()
        enable_image_mode()
    elseif list_contains(audio_file_extensions, ext) then
        disable_image_mode()
        disable_video_mode()
        enable_audio_mode()
    else
        disable_audio_mode()
        disable_image_mode()
        enable_video_mode()
    end

    if last_type ~= ext then
        on_type_change(last_type, ext)
        last_type = ext
    end
end

mp.register_event("start-file", update)
