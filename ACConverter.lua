addon.name      = 'ACConverter'
addon.author    = 'NxN_Slite'
addon.version   = '1.00'
addon.desc      = 'Convert XML Ashitacast to LUA for LuAShitacast'
require "common"

-- LegagyAC config folder and temp file needed to extract sets
local LegacyAC_FOLDER = string.format('%sconfig\\LegacyAC', AshitaCore:GetInstallPath())
local LegacyAC_Path = ""
local TEMP_FILE = LegacyAC_FOLDER .. "/temp.xml"
local LuAshitaProfileFile = ""


-- Function to get player info
local function getPlayerInfo()
    local name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0)
    local job = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", AshitaCore:GetMemoryManager():GetPlayer():GetMainJob())
    local playerID = string.format(AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0))
    return name, job, playerID
end

-- Function to generate LuaShitacastProfile path
local function getLuaShitacastProfilePath(name, playerID, job)
    LuAshitaProfileFile = string.format('%sconfig\\addons\\luashitacast\\%s_%s\\%s.lua', AshitaCore:GetInstallPath(), name, playerID, job)
end

-- Function to read the raw XML content from the source file
local function readFile(path)
    local file, err = io.open(path, "r")
    if not file then
        print("Error: Unable to open source file: " .. path .. ". Error: " .. err)
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

-- Function to check plugin and return status 
function checkRequiredPlugin()
	local pluginManager = AshitaCore:GetPluginManager() 
	local isLoaded = pluginManager:IsLoaded("LegacyAC")
	if not isLoaded then 
		return false
	end
	return true
end

-- Function to parse XML and extract all sets with their equipment
local function findAllSetsWithEquipment(xmlContent)
    local setsContent = xmlContent:match("<sets>(.-)</sets>")
    if not setsContent then
        print("Error: Unable to capture sets content.")
        return nil
    end
    setsContent = setsContent:gsub("<!--.- -->", "")
    setsContent = setsContent:gsub(' baseset=".-"', "")
    local sets = {}
    for setContent in setsContent:gmatch("<set.->.-</set>") do
        table.insert(sets, setContent)
    end
    return sets
end

-- Function to write the content to temp.xml
local function writeFile(path, content)
    local file, err = io.open(path, "w")
    if not file then
        print("Error: Unable to write to temp file: " .. path .. ". Error: " .. err)
        return false
    end
    file:write(content)
    file:close()
    return true
end

-- Function to check if a set is added to the LuAshitacast profile
local function isSetAdded(setName)
    local profileContent = readFile(LuAshitaProfileFile)
    return profileContent and profileContent:find(setName, 1, true) ~= nil
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
				-- Check if the new set is added 
		if not isSetAdded(setName) then 
			print("Error: Failed to add set: " .. setName)
			print("Make sure LuAshitacast is loaded")
			return
		end
    end
    print("Importation of sets completed successfully.")
end

function setAllPath()
	local name, job, playerID = getPlayerInfo()
    getLuaShitacastProfilePath(name, playerID, job)	
	local legacyACProfileName = string.format('%s_%s.xml', name, job)	
    LegacyAC_Path = LegacyAC_FOLDER .. "/" .. legacyACProfileName	
end

-- Function to create and load profile if not present
local function ensureLuaShitacastProfile()	
    local file, err = io.open(LuAshitaProfileFile, "r")
    if not file then
        print('LuAshita file not found. Creating profile')
        AshitaCore:GetChatManager():QueueCommand(1, '/lac newlua')
        coroutine.sleep(1)
		if not readFile(LuAshitaProfileFile) then
			print('Unable to find Profile. Make sure LuAshitacast is loaded')
			return false
		else
			return true
		end
    else
        file:close()
		return true
    end
end

-- Function to convert and process the XML profile
local function convertAndProcessProfile()
    if not ensureLuaShitacastProfile() then
		return false
	end
	local rawXmlContent = readFile(LegacyAC_Path)
	if not rawXmlContent then return end

	local foundSets = findAllSetsWithEquipment(rawXmlContent)
	if not foundSets then return end

	local setNames = findAllSetNames(rawXmlContent)

	local header = [[
<ashitacast>
<sets>
]]
	local footer = [[
</sets>
</ashitacast>
]]
	local content = header .. table.concat(foundSets, "\n") .. "\n" .. footer

	if not writeFile(TEMP_FILE, content) then return end

	print("File created successfully at:", TEMP_FILE)
	coroutine.sleep(1)

	executeCommandsForSets(setNames)
	
end

-- Ashita events
ashita.events.register('load', 'load_cb', function ()
    print("Welcome to the ACConverter Script!")
    print("This script helps convert and load sets from your XML profile.")
    print("Steps to use this script:")
    print("1. Ensure that LegacyAC and LuaShitacast are loaded.")
    print("2. Ensure that you have a newlua or the program will create one.")
    print("3. If any errors occur, they will be reported to help you troubleshoot.")
    print("Script is now ready and waiting for the /ACConverter command to start.")
end)

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args()
    if (#args == 0 or not args[1]:any('/ACConverter')) then
        return
    end
    if (#args <= 2 and args[1]:any('/ACConverter')) then
        if checkRequiredPlugin() then 
			print("Plugins LegacyAC is loaded. Continuing with the script...") 
			setAllPath()
			convertAndProcessProfile()
		else
			print("Script halted due to missing plugin : LegacyAC")
		end
    end
end)
