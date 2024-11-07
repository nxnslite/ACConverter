addon.name      = 'ACConverter';
addon.author    = 'NxN_Slite';
addon.version   = '0.75';
addon.desc      = 'Convert XML Ashitacast to LUA for LuAShitacast';
require "common"
local name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
local job = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", AshitaCore:GetMemoryManager():GetPlayer():GetMainJob());

-- Define the relative file paths
local LegacyACProfileFolder = string.format('%sconfig\\LegacyAC',AshitaCore:GetInstallPath())
local LegacyACProfileName = string.format(name .. "_" .. job .. '.xml')

-- Construct the full paths
local sourceFilePath = LegacyACProfileFolder .. "/" .. LegacyACProfileName
local tempFilePath = LegacyACProfileFolder .. "/temp.xml"

-- Read the raw XML content from the source file
local function readFile(path)
    local file = io.open(path, "r")
    if not file then
        print("Error: Unable to open source file.")
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content
end

-- Function to parse XML and extract all set names
local function findAllSetNames(xmlContent)
    local setNames = {}
    local pattern = '<set name="(.-)"'
    for setName in xmlContent:gmatch(pattern) do
        table.insert(setNames, setName)
    end
    return setNames
end

-- Function to parse XML and extract all sets with their equipment
local function findAllSetsWithEquipment(xmlContent)
    -- Capture everything between <sets> and </sets>
    local setsContent = xmlContent:match("<sets>(.-)</sets>")
    if not setsContent then
        print("Error: Unable to capture sets content.")
        return nil
    end
    -- Remove comments using regex
    setsContent = setsContent:gsub("<!--.- -->", "")
    -- Remove 'baseset="YYY"'
    setsContent = setsContent:gsub(' baseset=".-"', "")
    -- Split sets into individual sets
    local sets = {}
    for setContent in setsContent:gmatch("<set.->.-</set>") do
        table.insert(sets, setContent)
    end
    return sets
end

-- Write the content to temp.xml
local function writeFile(path, content)
    local file = io.open(path, "w")
    if not file then
        print("Error: Unable to write to temp file.")
        return false
    end
    file:write(content)
    file:close()
    return true
end

-- Function to execute commands for each set name with a 5-second interval
local function executeCommandsForSets(setNames)
    AshitaCore:GetChatManager():QueueCommand(1, '/la load temp.xml')
    for _, setName in ipairs(setNames) do
        AshitaCore:GetChatManager():QueueCommand(1, '/la naked')
        coroutine.sleep(1)
        AshitaCore:GetChatManager():QueueCommand(1, '/la enable')
        coroutine.sleep(1)
        AshitaCore:GetChatManager():QueueCommand(1, string.format('/la set %s', setName))
        coroutine.sleep(1)
        AshitaCore:GetChatManager():QueueCommand(1, string.format('/lac addset %s', setName))
        coroutine.sleep(1)
    end
    print("Importation of sets completed successfully.")
end

ashita.events.register('load', 'load_cb', function ()
    print("Welcome to the ACConverter Script!")
    print("This script helps convert and load sets from your XML profile.")
    print("Steps to use this script:")
    print("1. Ensure that LegacyAC and LuaShitacast is loaded.")
	print("2. Create a default lua using: /lac newlua")
    print("3. If any errors occur, they will be reported to help you troubleshoot.")
    print("Script is now ready and waiting for the /ACConverter command to start.")
	
end)

ashita.events.register('text_in', 'text_in_cb', function (e)
    return false
end)

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args()
    if (#args == 0 or not args[1]:any('/ACConverter')) then
        return
    end
    if (#args <= 2 and args[1]:any('/ACConverter')) then
        -- Import the XML
        local rawXmlContent = readFile(sourceFilePath)
        if not rawXmlContent then return end

        -- Finding all sets with their equipment
        local foundSets = findAllSetsWithEquipment(rawXmlContent)
        if not foundSets then return end

        local setNames = findAllSetNames(rawXmlContent)

        -- Create the content for temp.xml
        local header = [[
<ashitacast>
<sets>
]]
        local footer = [[
</sets>
</ashitacast>
]]
        -- Combine header, found sets, and footer
        local content = header .. table.concat(foundSets, "\n") .. "\n" .. footer
        
        if not writeFile(tempFilePath, content) then return end

        print("File created successfully at:", tempFilePath)
        coroutine.sleep(1)

        -- Load the temp.xml file before executing commands for each set name
        AshitaCore:GetChatManager():QueueCommand(1, '/la load temp.xml')
        coroutine.sleep(1)
        AshitaCore:GetChatManager():QueueCommand(1, '/la naked')
        coroutine.sleep(1)
        AshitaCore:GetChatManager():QueueCommand(1, '/la enable')
        coroutine.sleep(1)

        -- Execute commands for the found set names
        executeCommandsForSets(setNames)
    end
end)
