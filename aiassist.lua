VERSION = "0.1.0"

local micro = import("micro")
local config = import("micro/config")
local buffer = import("micro/buffer")
local shell = import("micro/shell")
local util = import("micro/util")
local ioutil = import("io/ioutil")
local http = import("net/http")
local json = import("encoding/json")
local fmt = import("fmt")
local os = import("os")
local filepath = import("path/filepath")

-- Global variables for tracking state
local currentSuggestion = nil
local suggestionActive = false
local acceptKeypressActive = false

-- Register configuration options
config.RegisterCommonOption("aiassist", "display_mode", "auto") -- 'auto', 'ghost', 'popup', 'pane'
config.RegisterCommonOption("aiassist", "api_key", "")
config.RegisterCommonOption("aiassist", "api_provider", "openai") -- openai, anthropic, etc.
config.RegisterCommonOption("aiassist", "model", "gpt-4-turbo")
config.RegisterCommonOption("aiassist", "suggestion_delay", "500") -- ms to wait before suggesting
config.RegisterCommonOption("aiassist", "auto_suggest", "true") -- whether to auto-suggest as typing
config.RegisterCommonOption("aiassist", "max_context_lines", "15") -- lines of context to send
config.RegisterCommonOption("aiassist", "keybinding_suggest", "Alt-]")
config.RegisterCommonOption("aiassist", "keybinding_accept", "Tab")
config.RegisterCommonOption("aiassist", "keybinding_next", "Alt-.")
config.RegisterCommonOption("aiassist", "temperature", "0.7")
config.RegisterCommonOption("aiassist", "max_tokens", "1024")

function init()
    -- Register commands
    config.MakeCommand("aiComplete", completeCode, config.NoComplete)
    config.MakeCommand("aiExplain", explainCode, config.NoComplete)
    config.MakeCommand("aiConfig", configureAI, config.NoComplete)
    config.MakeCommand("aiDisplayMode", setDisplayMode, config.NoComplete)
    
    -- Set up keybindings
    config.TryBindKey("Alt-]", "lua:aiassist.completeCode", false)
    config.TryBindKey("Alt-e", "lua:aiassist.explainCode", false)
    config.TryBindKey("Tab", "lua:aiassist.acceptSuggestion", false)
    
    -- Add help documentation
    config.AddRuntimeFile("aiassist", config.RTHelp, "help/aiassist.md")
    
    -- Load saved config
    loadConfig()
    
    -- Set up keybindings for suggestion acceptance
    setupSuggestionKeys()
    
    micro.Log("AI Assist plugin initialized")
end

function setupSuggestionKeys()
    -- The keypress binding for accepting suggestions
    -- This would need to be expanded to properly handle key bindings
    -- We're using Tab as the default accept key
end

-- Function to load configuration from aiassist.json
function loadConfig()
    local configDir = config.ConfigDir
    local configPath = filepath.Join(configDir, "aiassist.json")
    
    -- Check if config file exists
    local _, err = os.Stat(configPath)
    if err ~= nil then
        -- Create default config (silent if it doesn't exist)
        createDefaultConfig(configPath)
    end
    
    -- Load the config
    local configData, err = ioutil.ReadFile(configPath)
    
    if err ~= nil then
        micro.Log("Failed to load aiassist config: " .. err)
        return
    end
    
    -- Parse and apply config
    local configTable = {}
    err = json.Unmarshal(configData, configTable)
    
    if err ~= nil then
        micro.Log("Failed to parse aiassist config: " .. err)
        return
    }
    
    -- Apply loaded settings
    if configTable.api_key then
        config.SetGlobalOption("aiassist.api_key", configTable.api_key)
    end
    
    if configTable.provider then
        config.SetGlobalOption("aiassist.api_provider", configTable.provider)
    end
    
    if configTable.model then
        config.SetGlobalOption("aiassist.model", configTable.model)
    end
    
    if configTable.display_mode then
        config.SetGlobalOption("aiassist.display_mode", configTable.display_mode)
    end
end

-- Function to create a default configuration file
function createDefaultConfig(configPath)
    local defaultConfig = {
        api_key = "",
        provider = "openai",
        model = "gpt-4-turbo",
        display_mode = "auto"
    }
    
    local configJson, err = json.Marshal(defaultConfig)
    if err ~= nil then
        micro.Log("Failed to create default config: " .. err)
        return
    end
    
    err = ioutil.WriteFile(configPath, configJson, 0600)
    if err ~= nil then
        micro.Log("Failed to write default config: " .. err)
    end
}

-- Function to save configuration
function saveConfig()
    local configDir = config.ConfigDir
    local configPath = filepath.Join(configDir, "aiassist.json")
    
    local configData = {
        api_key = config.GetGlobalOption("aiassist.api_key"),
        provider = config.GetGlobalOption("aiassist.api_provider"),
        model = config.GetGlobalOption("aiassist.model"),
        display_mode = config.GetGlobalOption("aiassist.display_mode")
    }
    
    local configJson, err = json.Marshal(configData)
    if err ~= nil then
        micro.InfoBar():Error("Failed to save config: " .. err)
        return
    end
    
    err = ioutil.WriteFile(configPath, configJson, 0600)
    if err ~= nil then
        micro.InfoBar():Error("Failed to write config: " .. err)
    else {
        micro.InfoBar():Message("Configuration saved")
    }
}

-- Function to make API requests
function makeAPIRequest(prompt, bp)
    local provider = bp.Buf.Settings["aiassist.api_provider"]
    local api_key = bp.Buf.Settings["aiassist.api_key"]
    
    if api_key == "" then
        micro.InfoBar():Error("API key not set. Use 'aiConfig api_key YOUR_KEY'")
        return nil
    end
    
    -- Different handling based on provider
    if provider == "openai" then
        return requestOpenAI(prompt, bp)
    elseif provider == "anthropic" then
        return requestAnthropic(prompt, bp)
    else
        micro.InfoBar():Error("Unknown API provider: " .. provider)
        return nil
    end
}

-- Function to request completion from OpenAI
function requestOpenAI(prompt, bp)
    local model = bp.Buf.Settings["aiassist.model"]
    local max_tokens = tonumber(bp.Buf.Settings["aiassist.max_tokens"])
    local temperature = tonumber(bp.Buf.Settings["aiassist.temperature"])
    local api_key = bp.Buf.Settings["aiassist.api_key"]
    
    -- Build request payload
    local jsonStr = fmt.Sprintf('{"model": "%s", "messages": [{"role": "user", "content": "%s"}], "max_tokens": %d, "temperature": %f}', 
        model, 
        prompt:gsub('"', '\\"'), -- Escape quotes in the prompt
        max_tokens,
        temperature
    )
    
    -- Set up request headers
    local headers = {
        "Content-Type: application/json",
        "Authorization: Bearer " .. api_key
    }
    
    -- Make the API request
    local response, err = util.HttpRequest("POST", "https://api.openai.com/v1/chat/completions", headers, jsonStr)
    if err ~= nil then
        micro.InfoBar():Error("OpenAI API request failed: " .. err)
        return nil
    end
    
    -- Parse the response
    local respTable = {}
    err = json.Unmarshal(response, respTable)
    if err ~= nil then
        micro.InfoBar():Error("Failed to parse OpenAI response: " .. err)
        return nil
    }
    
    -- Extract the completion text
    if respTable.choices and respTable.choices[1] and respTable.choices[1].message then
        return respTable.choices[1].message.content
    end
    
    micro.InfoBar():Error("Unexpected API response format")
    return nil
}

-- Function to request completion from Anthropic
function requestAnthropic(prompt, bp)
    local model = bp.Buf.Settings["aiassist.model"]
    local max_tokens = tonumber(bp.Buf.Settings["aiassist.max_tokens"])
    local temperature = tonumber(bp.Buf.Settings["aiassist.temperature"])
    local api_key = bp.Buf.Settings["aiassist.api_key"]
    
    -- Build request payload
    local jsonStr = fmt.Sprintf('{"model": "%s", "prompt": "%s", "max_tokens_to_sample": %d, "temperature": %f}', 
        model, 
        prompt:gsub('"', '\\"'), -- Escape quotes in the prompt
        max_tokens,
        temperature
    )
    
    -- Set up request headers
    local headers = {
        "Content-Type: application/json",
        "X-API-Key: " .. api_key,
        "anthropic-version: 2023-06-01"
    }
    
    -- Make the API request
    local response, err = util.HttpRequest("POST", "https://api.anthropic.com/v1/complete", headers, jsonStr)
    if err ~= nil then
        micro.InfoBar():Error("Anthropic API request failed: " .. err)
        return nil
    end
    
    -- Parse the response
    local respTable = {}
    err = json.Unmarshal(response, respTable)
    if err ~= nil then
        micro.InfoBar():Error("Failed to parse Anthropic response: " .. err)
        return nil
    }
    
    -- Extract the completion text
    if respTable.completion then
        return respTable.completion
    end
    
    micro.InfoBar():Error("Unexpected API response format")
    return nil
}

-- Function to get context from current buffer
function getContext(buf, cursorLoc, contextLines)
    local context = ""
    local currentLine = cursorLoc.Y
    local startLine = math.max(0, currentLine - contextLines)
    local endLine = math.min(buf:LinesNum() - 1, currentLine + 5)
    
    -- Add file type for context
    context = "File type: " .. buf:FileType() .. "\n\n"
    
    -- Add relevant code context
    for i = startLine, endLine do
        local lineText = buf:Line(i)
        if i == currentLine then
            -- Mark the current line and get text up to cursor
            local lineUpToCursor = util.String(buf:Substr(buffer.Loc(0, i), cursorLoc))
            context = context .. "> " .. lineUpToCursor .. "█\n" -- Use █ as cursor marker
        else
            context = context .. "  " .. lineText .. "\n"
        }
    }
    
    -- Add prompt instruction
    context = context .. "\nComplete the code at the cursor position (marked with █). Only return the code completion, no explanations or markdown formatting:"
    
    return context
}

-- Main function to generate code completion
function completeCode(bp)
    local cursor = bp.Buf:GetActiveCursor()
    local context = getContext(bp.Buf, cursor.Loc, tonumber(bp.Buf.Settings["aiassist.max_context_lines"]))
    
    micro.InfoBar():Message("Generating completion...")
    
    -- Request completion
    local completion = makeAPIRequest(context, bp)
    
    if completion then
        -- Display the completion based on settings
        displayCompletion(bp, completion)
        return true
    }
    
    return false
}

-- Function to explain selected code
function explainCode(bp)
    local cursor = bp.Buf:GetActiveCursor()
    
    -- Get selected text or current function
    local text = ""
    if cursor:HasSelection() then
        text = cursor:GetSelection()
    else
        -- Try to get the current function or block
        text = getCurrentBlock(bp.Buf, cursor.Loc)
    }
    
    if text == "" then
        micro.InfoBar():Error("No code selected to explain")
        return false
    }
    
    local prompt = "Explain this code concisely:\n\n" .. text
    
    -- Create a new split with explanation
    bp:HSplit()
    local newBp = micro.CurPane()
    newBp.Buf.Type.Scratch = true
    newBp.Buf:SetName("AI Explanation")
    
    -- Show "Loading..." while waiting
    newBp.Buf:Insert(buffer.Loc(0, 0), "Loading explanation...")
    
    -- Get explanation from API asynchronously
    micro.After(1, function()
        local explanation = makeAPIRequest(prompt, bp)
        if explanation then
            newBp.Buf:Remove(buffer.Loc(0, 0), buffer.Loc(newBp.Buf:LineLength(0), 0))
            newBp.Buf:Insert(buffer.Loc(0, 0), explanation)
        else
            newBp.Buf:Remove(buffer.Loc(0, 0), buffer.Loc(newBp.Buf:LineLength(0), 0))
            newBp.Buf:Insert(buffer.Loc(0, 0), "Failed to get explanation")
        end
    end)
    
    return true
}

-- Helper function to get the current code block/function
function getCurrentBlock(buf, loc)
    -- Simple implementation to get surrounding block
    -- More sophisticated version would need language-specific parsing
    
    local startLine = loc.Y
    local endLine = loc.Y
    
    -- Look backwards for start of block
    while startLine > 0 do
        local line = buf:Line(startLine)
        if line:match("^%s*function%s") or line:match("^%s*{") or line:match("^%s*class%s") then
            break
        end
        startLine = startLine - 1
    }
    
    -- Look forwards for end of block
    while endLine < buf:LinesNum() - 1 do
        local line = buf:Line(endLine)
        if line:match("}%s*$") or line:match("^%s*}") or line:match("end%s*$") then
            endLine = endLine + 1
            break
        end
        endLine = endLine + 1
    }
    
    -- Extract the block
    local block = ""
    for i = startLine, endLine do
        block = block .. buf:Line(i) .. "\n"
    }
    
    return block
}

-- Function to display completion based on mode
function displayCompletion(bp, completion)
    -- Clear any previous suggestions
    clearSuggestions(bp)
    
    -- Determine if completion spans multiple lines
    local isMultiLine = string.find(completion, "\n") ~= nil
    
    -- Determine display mode
    local displayMode = bp.Buf.Settings["aiassist.display_mode"]
    if displayMode == "auto" then
        if isMultiLine then
            displayMode = "popup"
        else
            displayMode = "ghost"
        end
    }
    
    -- Display suggestion based on configured mode
    if displayMode == "ghost" then
        displayGhostSuggestion(bp, completion)
    elseif displayMode == "popup" then
        displayPopupSuggestion(bp, completion)
    elseif displayMode == "pane" then
        displayPaneSuggestion(bp, completion)
    }
    
    -- Mark that a suggestion is active
    suggestionActive = true
    currentSuggestion = completion
}

-- Function to clear all active suggestions
function clearSuggestions(bp)
    -- Clear ghost suggestions
    bp.Buf:ClearMessages("aiassist")
    
    -- Clear popup if it exists
    local tabs = micro.Tabs()
    for i = 1, tabs:Len() do
        local tab = tabs:Get(i-1)
        for j = 1, tab:NumPanes() do
            local pane = tab:GetPane(j-1)
            if pane.Buf.Name == "AI Suggestion" then
                tab:RemPane(j-1)
                break
            end
        end
    }
    
    -- Reset state
    suggestionActive = false
    currentSuggestion = nil
}

-- Function to display ghost text suggestion
function displayGhostSuggestion(bp, completion)
    -- Create ghost text overlay
    local cursor = bp.Buf:GetActiveCursor()
    local loc = cursor.Loc
    
    -- Store suggestion for later acceptance
    currentSuggestion = completion
    
    -- Create a message that will appear right at the cursor
    local msg = buffer.NewMessage("aiassist", completion, loc, loc, buffer.MTInfo)
    bp.Buf:AddMessage(msg)
    
    -- Set up a hint about how to accept
    micro.InfoBar():Message("Press " .. bp.Buf.Settings["aiassist.keybinding_accept"] .. " to accept suggestion")
}

-- Function to display popup suggestion
function displayPopupSuggestion(bp, completion)
    -- Create a temporary buffer in a new pane that appears like a popup
    
    -- Store the current pane to return to it later
    local currentPane = bp
    
    -- Create a temporary buffer for the suggestion
    bp:HSplit()
    local suggestPane = micro.CurPane()
    suggestPane.Buf.Type.Scratch = true
    suggestPane.Buf:SetName("AI Suggestion")
    
    -- Insert the completion
    suggestPane.Buf:Insert(buffer.Loc(0, 0), completion)
    
    -- Format the popup - add help text
    local helpText = "\n\n-- Press " .. bp.Buf.Settings["aiassist.keybinding_accept"] .. " to accept, Esc to cancel --"
    suggestPane.Buf:Insert(buffer.Loc(0, suggestPane.Buf:LinesNum()), helpText)
    
    -- Return focus to the original pane
    micro.CurPane().Buf = currentPane.Buf
}

-- Function to display suggestion in a dedicated pane
function displayPaneSuggestion(bp, completion)
    -- Create or reuse a dedicated pane for suggestions
    local suggestPane = getSuggestionPane(bp)
    
    -- Clear previous suggestions
    suggestPane.Buf:Remove(buffer.Loc(0, 0), buffer.Loc(suggestPane.Buf:LinesNum(), 0))
    
    -- Insert header and completion
    local header = "-- AI Suggestion --\n\n"
    suggestPane.Buf:Insert(buffer.Loc(0, 0), header .. completion)
    
    -- Store suggestion
    currentSuggestion = completion
    
    -- Set up hint
    micro.InfoBar():Message("Press " .. bp.Buf.Settings["aiassist.keybinding_accept"] .. " to accept suggestion")
}

-- Helper function to get or create a suggestion pane
function getSuggestionPane(bp)
    -- Check if the suggestion pane already exists
    local tabs = micro.Tabs()
    for i = 1, tabs:Len() do
        local tab = tabs:Get(i-1)
        for j = 1, tab:NumPanes() do
            local pane = tab:GetPane(j-1)
            if pane.Buf.Name == "AI Suggestions" then
                return pane
            end
        end
    }
    
    -- If it doesn't exist, create it (at bottom)
    bp:HSplit()
    local newPane = micro.CurPane()
    newPane.Buf.Type.Scratch = true 
    newPane.Buf:SetName("AI Suggestions")
    
    -- Return to original pane
    micro.CurPane().Buf = bp.Buf
    
    return newPane
}

-- Function to accept the current suggestion
function acceptSuggestion(bp)
    if not suggestionActive or not currentSuggestion then
        -- No active suggestion, just insert a tab
        return false
    }
    
    -- Insert the suggestion at cursor position
    local cursor = bp.Buf:GetActiveCursor()
    bp.Buf:Insert(cursor.Loc, currentSuggestion)
    
    -- Clear the suggestion
    clearSuggestions(bp)
    
    return true
}

-- Function to configure AI settings
function configureAI(bp, args)
    if #args < 2 then
        micro.InfoBar():Error("Usage: aiConfig [option] [value]")
        return
    }
    
    local option = "aiassist." .. args[1]
    local value = args[2]
    
    config.SetGlobalOption(option, value)
    micro.InfoBar():Message(string.format("Set %s to %s", option, value))
    
    -- Save to config file
    saveConfig()
    
    return true
}

-- Function to set display mode
function setDisplayMode(bp, args)
    if #args < 1 then
        micro.InfoBar():Error("Usage: aiDisplayMode [auto|ghost|popup|pane]")
        return
    }
    
    local mode = args[1]:lower()
    if mode ~= "auto" and mode ~= "ghost" and mode ~= "popup" and mode ~= "pane" then
        micro.InfoBar():Error("Invalid display mode. Use: auto, ghost, popup, or pane")
        return
    }
    
    config.SetGlobalOption("aiassist.display_mode", mode)
    micro.InfoBar():Message("AI suggestions will now display in " .. mode .. " mode")
    
    -- Update config file
    saveConfig()
    
    return true
}

-- Auto-suggest as user types
function onRune(bp)
    -- Only auto-suggest if enabled in settings
    if bp.Buf.Settings["aiassist.auto_suggest"] ~= "true" then
        return false
    }
    
    -- Don't trigger suggestion too frequently
    micro.After(tonumber(bp.Buf.Settings["aiassist.suggestion_delay"]), function()
        if shouldSuggest(bp.Buf, bp.Buf:GetActiveCursor().Loc) then
            completeCode(bp)
        end
    end)
    
    return false
}

-- Determine if we should suggest code completion
function shouldSuggest(buf, loc)
    -- Simple trigger conditions:
    -- 1. Not already suggesting
    -- 2. Not in a comment or string (would need language-specific implementation)
    -- 3. After a certain punctuation or at start of block
    
    if suggestionActive then
        return false
    }
    
    -- Get current line up to cursor
    local lineUpToCursor = util.String(buf:Substr(buffer.Loc(0, loc.Y), loc))
    
    -- Check for trigger characters
    local triggers = {
        "%(", -- After opening parenthesis
        "{", -- After opening brace
        "%.", -- After dot (for method completion)
        "if%s+", -- After if statement
        "for%s+", -- After for loop
        "function%s+", -- After function declaration
        "return%s+" -- After return statement
    }
    
    for _, trigger in ipairs(triggers) do
        if lineUpToCursor:match(trigger .. "$") then
            return true
        end
    }
    
    return false
}

-- Callback when buffer is opened
function onBufferOpen(buf)
    -- Initialize plugin for this buffer
    local apiKey = buf.Settings["aiassist.api_key"]
    if apiKey == "" then
        -- Don't show warning, just log it
        micro.Log("AI Assist: No API key configured")
    end
}