require "import"
import "android.widget.*"
import "android.view.*"
import "android.os.*"
import "java.io.*"
import "android.app.AlertDialog"
import "android.content.Intent"
import "android.net.Uri"
import "android.text.TextWatcher"
import "android.graphics.drawable.GradientDrawable"
import "android.content.Context"
import "android.widget.Toast"
import "com.androlua.Http"
import "android.widget.ListView"
import "android.widget.ArrayAdapter"
import "android.widget.SearchView"
import "android.view.inputmethod.InputMethodManager"
import "cjson"
import "android.graphics.Color"
import "android.provider.MediaStore"
import "android.app.DownloadManager"
import "android.text.InputType"
import "android.widget.LinearLayout$LayoutParams"
import "android.graphics.Typeface"
import "java.net.URLEncoder"
import "java.lang.System"
import "android.media.ToneGenerator"
import "android.media.AudioManager"
import "android.os.Vibrator"
import "android.os.Build"
import "android.os.VibrationEffect"
import "android.os.Looper"
import "android.app.*"
import "android.content.*"

local ctx = activity or service

local File = luajava.bindClass("java.io.File")
local FileOutputStream = luajava.bindClass("java.io.FileOutputStream")
local FileWriter = luajava.bindClass("java.io.FileWriter")
local BufferedWriter = luajava.bindClass("java.io.BufferedWriter")
local BufferedReader = luajava.bindClass("java.io.BufferedReader")
local FileReader = luajava.bindClass("java.io.FileReader")
local Thread = luajava.bindClass("java.lang.Thread")

local sdCard = tostring(Environment.getExternalStorageDirectory())
local EXT_PATH = sdCard .. "/解说/Plugins/"
local TOOL_PATH = sdCard .. "/解说/Tools/"

local appName = "Jieshuo Resources for Coding By Tech For V I"

-- UPDATE SYSTEM CONFIGURATION
local CURRENT_VERSION = "2.0"
local VERSION_URL = "https://jieshuo-resources-for-coding-by-tec.vercel.app/version.txt"
local UPDATE_CODE_URL = "https://jieshuo-resources-for-coding-by-tec.vercel.app/main.lua"
local NEW_FEATURES_URL = "https://jieshuo-resources-for-coding-by-tec.vercel.app/new%20features.txt"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/Jieshuo resources for coding by Tech for V i/main.lua"

local updateInProgress = false
local prefs = ctx.getSharedPreferences("JieshuoResourcesPrefs", Context.MODE_PRIVATE)

-- Server Configuration for all options
local BASE_URL = "https://jieshuo-resources-for-coding-by-tec.vercel.app/"
local SERVER_FILES = {
    ["Jieshuo Services"] = "JIESHUO SERVICES",
    ["Jieshuo Activities"] = "JIESHUO ACTIVITIES",
    ["Jieshuo API Help"] = "JIESHUO API HELP",
    ["Jieshuo Sintex"] = "JIESHUO SINTEX",
    ["Language with code name"] = "LANGUAGE WITH CODE NAME",
    ["Jieshuo Functions"] = "JIESHUO FUNCTIONS",
    ["Open Source Code"] = "OPEN SOURCE/root code.txt",
    ["About & Support"] = "ABOUT & SUPPORT",
}

-- Default description - empty initially
local cachedDescription = ""

local DESCRIPTION_URL = BASE_URL .. "Description"

_G.APP_NAME = "Jieshuo Resources for Coding By Tech For V I"
_G.shouldShowMain = true

-- SharedPreferences for settings
local settingsPrefs = service.getSharedPreferences("JieshuoResourcesSettings", Context.MODE_PRIVATE)
local soundEnabled = settingsPrefs.getBoolean("soundEnabled", true)
local vibrationEnabled = settingsPrefs.getBoolean("vibrationEnabled", true)

-- Preload data for all options
local preloadedData = {}
local preloadComplete = {}

-- Initialize tables
for optionTitle, _ in pairs(SERVER_FILES) do
    preloadedData[optionTitle] = nil
    preloadComplete[optionTitle] = false
end
preloadedData["Description"] = nil
preloadComplete["Description"] = false

local function trim(s)
    if s == nil then return "" end
    return tostring(s):gsub("^%s*(.-)%s*$", "%1")
end

local function speakMsg(text)
    if service and service.speak then
        service.speak(tostring(text))
    end
end

local function showMsg(text)
    Toast.makeText(service, text, Toast.LENGTH_SHORT).show()
end

-- Notification function for startup
local function playStartupNotification()
    if soundEnabled then
        local tone = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
        tone.startTone(ToneGenerator.TONE_PROP_ACK, 100)
    end
    
    if vibrationEnabled then
        local vibrator = service.getSystemService(Context.VIBRATOR_SERVICE)
        if vibrator then
            if Build.VERSION.SDK_INT >= 26 then
                vibrator.vibrate(VibrationEffect.createOneShot(150, VibrationEffect.DEFAULT_AMPLITUDE))
            else
                vibrator.vibrate(150)
            end
        end
    end
end

-- Function to show Settings Dialog
local function showSettingsDialog()
    local settingsDialog = LuaDialog(service)
    settingsDialog.setTitle("Settings")
    settingsDialog.setCancelable(false)
    
    local settingsLayout = LinearLayout(service)
    settingsLayout.setOrientation(1)
    settingsLayout.setPadding(40, 40, 40, 40)
    
    -- Sound Switch
    local soundLayout = LinearLayout(service)
    soundLayout.setOrientation(0)
    soundLayout.setPadding(0, 0, 0, 20)
    
    local soundText = TextView(service)
    soundText.setText("Startup Sound")
    soundText.setTextSize(16)
    soundText.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    soundLayout.addView(soundText)
    
    local soundSwitch = Switch(service)
    soundSwitch.setChecked(soundEnabled)
    soundLayout.addView(soundSwitch)
    settingsLayout.addView(soundLayout)
    
    -- Vibration Switch
    local vibrationLayout = LinearLayout(service)
    vibrationLayout.setOrientation(0)
    vibrationLayout.setPadding(0, 0, 0, 30)
    
    local vibrationText = TextView(service)
    vibrationText.setText("Startup Vibration")
    vibrationText.setTextSize(16)
    vibrationText.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    vibrationLayout.addView(vibrationText)
    
    local vibrationSwitch = Switch(service)
    vibrationSwitch.setChecked(vibrationEnabled)
    vibrationLayout.addView(vibrationSwitch)
    settingsLayout.addView(vibrationLayout)
    
    -- Button Layout
    local buttonLayout = LinearLayout(service)
    buttonLayout.setOrientation(0)
    buttonLayout.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
    
    local saveBtn = Button(service)
    saveBtn.setText("Save Settings")
    saveBtn.setTextSize(16)
    saveBtn.setBackgroundColor(0xFF2E7D32)
    saveBtn.setTextColor(0xFFFFFFFF)
    local saveParams = LinearLayout.LayoutParams(0, -2, 1)
    saveParams.setMargins(0, 0, 10, 0)
    saveBtn.setLayoutParams(saveParams)
    saveBtn.onClick = function()
        soundEnabled = soundSwitch.isChecked()
        vibrationEnabled = vibrationSwitch.isChecked()
        settingsPrefs.edit()
            .putBoolean("soundEnabled", soundEnabled)
            .putBoolean("vibrationEnabled", vibrationEnabled)
            .apply()
        speakMsg("Settings saved successfully")
        settingsDialog.dismiss()
    end
    buttonLayout.addView(saveBtn)
    
    local goBackBtn = Button(service)
    goBackBtn.setText("Go Back")
    goBackBtn.setTextSize(16)
    goBackBtn.setBackgroundColor(0xFF9E9E9E)
    goBackBtn.setTextColor(0xFFFFFFFF)
    local backParams = LinearLayout.LayoutParams(0, -2, 1)
    backParams.setMargins(10, 0, 0, 0)
    goBackBtn.setLayoutParams(backParams)
    goBackBtn.onClick = function()
        settingsDialog.dismiss()
    end
    buttonLayout.addView(goBackBtn)
    
    settingsLayout.addView(buttonLayout)
    
    settingsDialog.setView(settingsLayout)
    settingsDialog.show()
end

-- UPDATE SYSTEM FUNCTIONS

function showUpdateErrorDialog(title, message)
    Handler(Looper.getMainLooper()).post(Runnable{
        run=function()
            local errorDialog = LuaDialog(ctx)
            errorDialog.setTitle(title)
            errorDialog.setMessage(message)
            errorDialog.setButton("OK", function()
                errorDialog.dismiss()
            end)
            errorDialog.show()
        end
    })
end

function showNewFeaturesDialog(featuresText)
    Handler(Looper.getMainLooper()).post(Runnable{
        run=function()
            local featuresDialog = LuaDialog(ctx)
            featuresDialog.setTitle("New Update Details")
            local layout = {
                LinearLayout,
                orientation = "vertical",
                layout_width = "match_parent",
                layout_height = "match_parent",
                padding = "16dp",
                {
                    ScrollView,
                    layout_width = "match_parent",
                    layout_height = "0dp",
                    layout_weight = 1,
                    {
                        TextView,
                        text = featuresText or "No new features information available.",
                        textSize = "14sp",
                        padding = "10dp",
                        layout_width = "match_parent",
                        layout_height = "wrap_content",
                    },
                },
                {
                    Button,
                    text = "OK",
                    textSize = "16sp",
                    layout_width = "match_parent",
                    layout_height = "wrap_content",
                    layout_marginTop = "10dp",
                    onClick = function()
                        featuresDialog.dismiss()
                    end,
                },
            }
            featuresDialog.setView(loadlayout(layout))
            featuresDialog.setCancelable(false)
            featuresDialog.show()
        end
    })
end

function checkAndShowNewFeatures()
    local lastShownVersion = prefs.getString("lastShownVersion", "")
    if lastShownVersion ~= CURRENT_VERSION then
        Http.get(NEW_FEATURES_URL, function(code, response)
            if code == 200 and response and trim(response) ~= "" then
                showNewFeaturesDialog(response)
                prefs.edit().putString("lastShownVersion", CURRENT_VERSION).apply()
            end
        end)
    end
end

function performUpdate(mainCode, onlineVersion)
    if not mainCode or trim(mainCode) == "" then
        showUpdateErrorDialog("Update Failed", "Main plugin code is empty.")
        return
    end
    updateInProgress = true
    
    local function updateProcess()
        local success = false
        local tempPath = PLUGIN_PATH .. ".temp_update"
        local f = io.open(tempPath, "w")
        if f then
            f:write(mainCode)
            f:close()
            local fileExists = io.open(PLUGIN_PATH, "r")
            if fileExists then
                fileExists:close()
                local delSuccess = pcall(function()
                    os.remove(PLUGIN_PATH)
                end)
                if delSuccess then
                    local renameSuccess = pcall(function()
                        os.rename(tempPath, PLUGIN_PATH)
                    end)
                    if renameSuccess then
                        success = true
                    end
                end
            else
                local renameSuccess = pcall(function()
                    os.rename(tempPath, PLUGIN_PATH)
                end)
                if renameSuccess then
                    success = true
                end
            end
            if not success then
                pcall(function() os.remove(tempPath) end)
            end
        end
        
        if success then
            updateInProgress = false
            Handler(Looper.getMainLooper()).post(Runnable{
                run=function()
                    local successDialog = LuaDialog(ctx)
                    successDialog.setTitle("Update Successful")
                    successDialog.setMessage("Plugin successfully updated to version " .. onlineVersion .. ". Plugin will restart automatically.")
                    successDialog.setButton("OK", function()
                        successDialog.dismiss()
                        if _G.mainDlg then
                            _G.mainDlg.dismiss()
                        end
                        Handler(Looper.getMainLooper()).postDelayed(Runnable({
                            run = function()
                                prefs.edit().putString("lastShownVersion", "").apply()
                                local pluginFile = io.open(PLUGIN_PATH, "r")
                                if pluginFile then
                                    pluginFile:close()
                                    local func, err = loadfile(PLUGIN_PATH)
                                    if func then
                                        pcall(func)
                                    end
                                end
                            end
                        }), 2000)
                    end)
                    successDialog.show()
                end
            })
            return
        else
            updateInProgress = false
            showUpdateErrorDialog("Update Failed", "Update failed. Please try again.")
        end
    end
    
    local updateThread = Thread(luajava.bindClass("java.lang.Runnable"){
        run = updateProcess
    })
    updateThread.start()
end

function checkUpdate()
    if updateInProgress then
        showUpdateErrorDialog("Update In Progress", "An update is already in progress. Please wait.")
        return
    end
    
    Http.get(VERSION_URL, function(code, response)
        if code == 200 and response then
            local onlineVersion = trim(response)
            if onlineVersion ~= CURRENT_VERSION then
                Http.get(UPDATE_CODE_URL, function(code2, mainCode)
                    if code2 == 200 and mainCode and trim(mainCode) ~= "" then
                        Handler(Looper.getMainLooper()).post(Runnable{
                            run=function()
                                local updateAlertDlg = LuaDialog(ctx)
                                updateAlertDlg.setTitle("Update Available!")
                                updateAlertDlg.setMessage("A new version (" .. onlineVersion .. ") is available. Would you like to update now?")
                                updateAlertDlg.setButton("Update Now", function()
                                    updateAlertDlg.dismiss()
                                    performUpdate(mainCode, onlineVersion)
                                end)
                                updateAlertDlg.setButton2("Later", function()
                                    updateAlertDlg.dismiss()
                                end)
                                updateAlertDlg.show()
                            end
                        })
                    end
                end)
            else
                checkAndShowNewFeatures()
            end
        end
    end)
end

-- Load and execute from server with preload check
local function loadAndExecuteFromServer(fileName, optionTitle)
    if preloadComplete[optionTitle] and preloadedData[optionTitle] then
        local chunk, err = load(preloadedData[optionTitle], "=" .. fileName, "t", _G)
        if chunk then
            local success, execErr = pcall(chunk)
            if not success then
                speakMsg("No internet connection. Please check your internet connection and try again later.")
            end
        else
            speakMsg("No internet connection. Please check your internet connection and try again later.")
        end
        return
    end
    
    -- If not preloaded, show loading dialog
    local loadingDialog = LuaDialog(service)
    loadingDialog.setTitle("Loading...")
    loadingDialog.setMessage("Fetching " .. optionTitle .. " from server...")
    loadingDialog.setCancelable(false)
    loadingDialog.show()

    Http.get(BASE_URL .. fileName, function(code, response)
        Handler(Looper.getMainLooper()).post(Runnable{
            run=function()
                loadingDialog.dismiss()
                if code == 200 and response and trim(response) ~= "" then
                    local finalResponse = response
                    if optionTitle == "About & Support" then
                        local desc = cachedDescription or ""
                        finalResponse = "local descriptionText = [[" .. desc:gsub("%]", "] ]") .. "]]\n\n" .. response
                    end
                    
                    local chunk, err = load(finalResponse, "=" .. fileName, "t", _G)
                    if chunk then
                        local success, execErr = pcall(chunk)
                        if not success then
                            speakMsg("No internet connection. Please check your internet connection and try again later.")
                        end
                    else
                        speakMsg("No internet connection. Please check your internet connection and try again later.")
                    end
                else
                    speakMsg("No internet connection. Please check your internet connection and try again later.")
                end
            end
        })
    end)
end

local function createServerButtonHandler(optionTitle)
    return function()
        local fileName = SERVER_FILES[optionTitle]
        if fileName then
            loadAndExecuteFromServer(fileName, optionTitle)
        else
            speakMsg("No server file configured for: " .. optionTitle)
        end
    end
end

-- FIRST: Load description from server (priority 1)
local function startPreloading()
    -- First, load description
    Thread(luajava.bindClass("java.lang.Runnable"){
        run = function()
            Http.get(DESCRIPTION_URL, function(code, response)
                if code == 200 and response and trim(response) ~= "" then
                    cachedDescription = response
                    preloadedData["Description"] = response
                else
                    cachedDescription = ""
                    preloadedData["Description"] = ""
                end
                preloadComplete["Description"] = true
                
                -- After description is loaded, load all other options
                for optionTitle, fileName in pairs(SERVER_FILES) do
                    Http.get(BASE_URL .. fileName, function(code2, response2)
                        if code2 == 200 and response2 and trim(response2) ~= "" then
                            local finalResponse = response2
                            if optionTitle == "About & Support" then
                                local desc = cachedDescription or ""
                                finalResponse = "local descriptionText = [[" .. desc:gsub("%]", "] ]") .. "]]\n\n" .. response2
                            end
                            preloadedData[optionTitle] = finalResponse
                            preloadComplete[optionTitle] = true
                        else
                            preloadComplete[optionTitle] = false
                        end
                    end)
                    -- Small delay between requests
                    Thread.sleep(100)
                end
            end)
        end
    }).start()
end

-- Start preloading
startPreloading()

-- Play startup notification based on settings
playStartupNotification()

-- Start update check after 3 seconds
Thread(luajava.bindClass("java.lang.Runnable"){
    run = function()
        Thread.sleep(3000)
        checkUpdate()
    end
}).start()

-- Main UI Layout
local scrollView = ScrollView(service)
scrollView.setLayoutParams(LinearLayout.LayoutParams(-1, -1))

local layout = LinearLayout(service)
layout.setOrientation(1)
layout.setPadding(40, 40, 40, 40)
layout.setBackgroundColor(0xFFFFFFFF)

local titleText = TextView(service)
titleText.setText("Jieshuo Resources for Coding By Tech For V I")
titleText.setTextSize(20)
titleText.setGravity(Gravity.CENTER)
titleText.setTextColor(0xFF2E7D32)
layout.addView(titleText)

local devText = TextView(service)
devText.setText("Developer: Sabir Jamil")
devText.setTextSize(14)
devText.setGravity(Gravity.CENTER)
devText.setPadding(0, 0, 0, 20)
layout.addView(devText)

-- Row 1: Services, Activities, API Help
local row1 = LinearLayout(service)
row1.setOrientation(0)
row1.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
row1.setPadding(0, 0, 0, 15)

local servicesBtn = Button(service)
servicesBtn.setText("Jieshuo Services")
servicesBtn.setTextSize(14)
servicesBtn.setBackgroundColor(0xFF2E7D32)
servicesBtn.setTextColor(0xFFFFFFFF)
local btnParams = LinearLayout.LayoutParams(0, -2, 1)
btnParams.setMargins(0, 0, 5, 0)
servicesBtn.setLayoutParams(btnParams)
servicesBtn.onClick = createServerButtonHandler("Jieshuo Services")
row1.addView(servicesBtn)

local activitiesBtn = Button(service)
activitiesBtn.setText("Jieshuo Activities")
activitiesBtn.setTextSize(14)
activitiesBtn.setBackgroundColor(0xFF2E7D32)
activitiesBtn.setTextColor(0xFFFFFFFF)
activitiesBtn.setLayoutParams(btnParams)
activitiesBtn.onClick = createServerButtonHandler("Jieshuo Activities")
row1.addView(activitiesBtn)

local apiHelpBtn = Button(service)
apiHelpBtn.setText("Jieshuo API Help")
apiHelpBtn.setTextSize(14)
apiHelpBtn.setBackgroundColor(0xFF2E7D32)
apiHelpBtn.setTextColor(0xFFFFFFFF)
apiHelpBtn.setLayoutParams(btnParams)
apiHelpBtn.onClick = createServerButtonHandler("Jieshuo API Help")
row1.addView(apiHelpBtn)

layout.addView(row1)

-- Row 2: Sintex, Language Codes, Functions
local row2 = LinearLayout(service)
row2.setOrientation(0)
row2.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
row2.setPadding(0, 0, 0, 15)

local sintexBtn = Button(service)
sintexBtn.setText("Jieshuo Sintex")
sintexBtn.setTextSize(14)
sintexBtn.setBackgroundColor(0xFF2E7D32)
sintexBtn.setTextColor(0xFFFFFFFF)
sintexBtn.setLayoutParams(btnParams)
sintexBtn.onClick = createServerButtonHandler("Jieshuo Sintex")
row2.addView(sintexBtn)

local languageBtn = Button(service)
languageBtn.setText("Language with code name")
languageBtn.setTextSize(14)
languageBtn.setBackgroundColor(0xFF2E7D32)
languageBtn.setTextColor(0xFFFFFFFF)
languageBtn.setLayoutParams(btnParams)
languageBtn.onClick = createServerButtonHandler("Language with code name")
row2.addView(languageBtn)

local functionsBtn = Button(service)
functionsBtn.setText("Jieshuo Functions")
functionsBtn.setTextSize(14)
functionsBtn.setBackgroundColor(0xFF2E7D32)
functionsBtn.setTextColor(0xFFFFFFFF)
functionsBtn.setLayoutParams(btnParams)
functionsBtn.onClick = createServerButtonHandler("Jieshuo Functions")
row2.addView(functionsBtn)

layout.addView(row2)

-- Row 3: Open Source Code, Settings, About & Support
local row3 = LinearLayout(service)
row3.setOrientation(0)
row3.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
row3.setPadding(0, 0, 0, 15)

local openSourceBtn = Button(service)
openSourceBtn.setText("Open Source Code")
openSourceBtn.setTextSize(14)
openSourceBtn.setBackgroundColor(0xFF2E7D32)
openSourceBtn.setTextColor(0xFFFFFFFF)
openSourceBtn.setLayoutParams(btnParams)
openSourceBtn.onClick = createServerButtonHandler("Open Source Code")
row3.addView(openSourceBtn)

local settingsBtn = Button(service)
settingsBtn.setText("Settings")
settingsBtn.setTextSize(14)
settingsBtn.setBackgroundColor(0xFFFF9800)
settingsBtn.setTextColor(0xFFFFFFFF)
settingsBtn.setLayoutParams(btnParams)
settingsBtn.onClick = function()
    showSettingsDialog()
end
row3.addView(settingsBtn)

local aboutBtn = Button(service)
aboutBtn.setText("About & Support")
aboutBtn.setTextSize(14)
aboutBtn.setBackgroundColor(0xFF2196F3)
aboutBtn.setTextColor(0xFFFFFFFF)
aboutBtn.setLayoutParams(btnParams)
aboutBtn.onClick = createServerButtonHandler("About & Support")
row3.addView(aboutBtn)

layout.addView(row3)

-- Row 4: Exit Button (Centered)
local row4 = LinearLayout(service)
row4.setOrientation(0)
row4.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
row4.setGravity(Gravity.CENTER)

local exitBtn = Button(service)
exitBtn.setText("Exit")
exitBtn.setTextSize(14)
exitBtn.setBackgroundColor(0xFF9E9E9E)
exitBtn.setTextColor(0xFFFFFFFF)
exitBtn.setLayoutParams(LinearLayout.LayoutParams(-2, -2))
exitBtn.onClick = function()
    if _G.mainDlg then
        _G.mainDlg.dismiss()
    end
end
row4.addView(exitBtn)

layout.addView(row4)

scrollView.addView(layout)

_G.mainDlg = AlertDialog.Builder(service).setView(scrollView).create()
_G.mainDlg.getWindow().setType(WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY)
_G.mainDialog = _G.mainDlg
_G.mainDlg.show()