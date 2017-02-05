---------------------------------------------------------------------------------------------------
-- Name: QuestieNotes
-- Description: Handles all the quest map notes
---------------------------------------------------------------------------------------------------
--///////////////////////////////////////////////////////////////////////////////////////////////--
---------------------------------------------------------------------------------------------------
-- Global Vars
---------------------------------------------------------------------------------------------------
NOTES_DEBUG = nil; --Set to nil to not get debug shit
--Contains all the frames ever created, this is not to orphan any frames by mistake...
local AllFrames = {};
--Contains frames that are created but currently not used (Frames can't be deleted so we pool them to save space);
local FramePool = {};
local Dewdrop = AceLibrary("Dewdrop-2.0")
QUESTIE_NOTES_MAP_ICON_SCALE = 1.2;-- Zone
QUESTIE_NOTES_WORLD_MAP_ICON_SCALE = 0.75;--Full world shown
QUESTIE_NOTES_CONTINENT_ICON_SCALE = 1;--Continent Shown
QUESTIE_NOTES_MINIMAP_ICON_SCALE = 1.0;
QuestieUsedNoteFrames = {};
QuestieHandledQuests = {};
QuestieCachedMonstersAndObjects = {};
---------------------------------------------------------------------------------------------------
-- WoW Functions --PERFORMANCE CHANGE--
---------------------------------------------------------------------------------------------------
local QGet_QuestLogTitle = GetQuestLogTitle;
local QGet_NumQuestLeaderBoards = GetNumQuestLeaderBoards;
local QSelect_QuestLogEntry = SelectQuestLogEntry;
local QGet_QuestLogLeaderBoard = GetQuestLogLeaderBoard;
local QGet_QuestLogQuestText = GetQuestLogQuestText;
local QGet_TitleText = GetTitleText;
---------------------------------------------------------------------------------------------------
-- Adds quest notes to map
---------------------------------------------------------------------------------------------------
function Questie:AddQuestToMap(questHash, redraw)
    if(Active == false) then
        return;
    end
    Questie:RemoveQuestFromMap(questHash);
    Objectives = Questie:AstroGetQuestObjectives(questHash);
    --Cache code
    local ques = {};
    ques["noteHandles"] = {};
    UsedContinents = {};
    UsedZones = {};
    local Quest = Questie:IsQuestFinished(questHash);
    if not (Quest) then
        for name, locations in pairs(Objectives['objectives']) do
            for k, location in pairs(locations) do
                --This checks if just THIS objective is done (Data is not super efficient but it's nil unless set so...)
                if not location.done then
                    local MapInfo = Questie:GetMapInfoFromID(location.mapid);
                    local notehandle = {};
                    notehandle.c = MapInfo[4];
                    notehandle.z = MapInfo[5];
                    Questie:AddNoteToMap(MapInfo[4], MapInfo[5], location.x, location.y, location.type, questHash, location.objectiveid, location.lootname);
                    if not UsedContinents[MapInfo[4]] and not UsedZones[MapInfo[5]] then
                        UsedContinents[MapInfo[4]] = true;
                        UsedZones[MapInfo[5]] = true;
                        table.insert(ques["noteHandles"], notehandle);
                    end
                end
            end
        end
    else
        local Monfin = nil;
        local Objfin = nil;
        -- Monsters
        if( QuestieHashMap[Quest["questHash"]] and QuestieHashMap[Quest["questHash"]]['finishedBy']) then
            local finishMonster = QuestieHashMap[Quest["questHash"]]['finishedBy'];
            Monfin = QuestieMonsters[finishMonster];
        end
        if(not Monfin) then
            Monfin = QuestieMonsters[QuestieFinishers[Quest["name"]]];
        end
        -- Objects
        if( QuestieHashMap[Quest["questHash"]] and QuestieHashMap[Quest["questHash"]]['finishedBy']) then
            local finishObject = QuestieHashMap[Quest["questHash"]]['finishedBy'];
            Objfin = QuestieObjects[finishObject];
        end
        if(not Objfin) then
            Objfin = QuestieObjects[QuestieFinishers[Quest["name"]]];
        end
        local finisher = nil;
        if Monfin then finisher=Monfin elseif Objfin then finisher=Objfin end
        if(finisher) then
            local MapInfo = Questie:GetMapInfoFromID(finisher['locations'][1][1]);--Map id is at ID 1, i then convert this to a useful continent and zone
            local c, z, x, y = MapInfo[4], MapInfo[5], finisher['locations'][1][2],finisher['locations'][1][3]-- You just have to know about this, 2 is x 3 is y
            --The 1 is just the first locations as finisher only have one location
            --Questie:debug_Print("Quest finished",MapInfo[4], MapInfo[5]);
            Questie:AddNoteToMap(c,z, x, y, "complete", questHash, 0);
            local notehandle = {};
            notehandle.c = MapInfo[4];
            notehandle.z = MapInfo[5];
            table.insert(ques["noteHandles"], notehandle);
        else
            Questie:debug_Print("[AddQuestToMap] ERROR Quest broken! ", Quest["name"], questHash, "report on github!");
        end
    end
    --Cache code
    ques["objectives"] = Objectives;
    QuestieHandledQuests[questHash] = ques;
    if(redraw) then
        Questie:RedrawNotes();
    end
end
---------------------------------------------------------------------------------------------------
-- Updates quest notes on map
---------------------------------------------------------------------------------------------------
function Questie:UpdateQuestNotes(questHash, redraw)
    if not QuestieHandledQuests[questHash] then
        Questie:debug_Print("[UpdateQuestNotes] ERROR: Tried updating a quest not handled. ", questHash);
        return;
    end
    local QuestLogID = Questie:GetQuestIdFromHash(questHash);
    QSelect_QuestLogEntry(QuestLogID);
    local q, level, questTag, isHeader, isCollapsed, isComplete = QGet_QuestLogTitle(QuestLogID);
    local count =  QGet_NumQuestLeaderBoards();
    local questText, objectiveText = QGet_QuestLogQuestText();
    for k, noteInfo in pairs(QuestieHandledQuests[questHash]["noteHandles"]) do
        for id, note in pairs(QuestieMapNotes[noteInfo.c][noteInfo.z]) do
            if(note.questHash == questHash) then
                local desc, typ, done = QGet_QuestLogLeaderBoard(note.objectiveid);
                Questie:debug_Print("[UpdateQuestNotes] ", tostring(desc),tostring(typ),tostring(done));
            end
        end
    end
    if(redraw) then
        Questie:RedrawNotes();
    end
end
---------------------------------------------------------------------------------------------------
-- Remove quest note from map
---------------------------------------------------------------------------------------------------
function Questie:RemoveQuestFromMap(questHash, redraw)
    local removed = false;
    for continent, zoneTable in pairs(QuestieMapNotes) do
        for index, zone in pairs(zoneTable) do
            for i, note in pairs(zone) do
                if(note.questHash == questHash) then
                    QuestieMapNotes[continent][index][i] = nil;
                    removed = true;
                end
            end
        end
    end
    if(redraw) then
        Questie:RedrawNotes();
    end
    if(QuestieHandledQuests[questHash]) then
        QuestieHandledQuests[questHash] = nil;
    end
end

function Questie:GetMapInfoFromID(id)
    return QuestieZoneIDLookup[id];
end
---------------------------------------------------------------------------------------------------
-- Add quest note to map
---------------------------------------------------------------------------------------------------
QuestieMapNotes = {};--Usage Questie[Continent][Zone][index]
MiniQuestieMapNotes = {};
function Questie:AddNoteToMap(continent, zoneid, posx, posy, type, questHash, objectiveid, lootname)
    --This is to set up the variables
    if QuestieConfig.hideobjectives and not (type == "complete") then
        return;
    end
    if(QuestieMapNotes[continent] == nil) then
        QuestieMapNotes[continent] = {};
    end
    if(QuestieMapNotes[continent][zoneid] == nil) then
        QuestieMapNotes[continent][zoneid] = {};
    end
    --Sets values that i want to use for the notes THIS IS WIP MORE INFO MAY BE NEDED BOTH IN PARAMETERS AND NOTES!!!
    Note = {};
    Note.x = posx;
    Note.y = posy;
    Note.zoneid = zoneid;
    Note.continent = continent;
    Note.icontype = type;
    Note.questHash = questHash;
    Note.objectiveid = objectiveid;
    Note.lootname = lootname
    --Inserts it into the right zone and continent for later use.
    table.insert(QuestieMapNotes[continent][zoneid], Note);
end
---------------------------------------------------------------------------------------------------
-- Add available quest note to map
---------------------------------------------------------------------------------------------------
QuestieAvailableMapNotes = {};
function Questie:AddAvailableNoteToMap(continent, zoneid, posx, posy, type, questHash, objectiveid, monsterName)
    --This is to set up the variables
    if(QuestieAvailableMapNotes[continent] == nil) then
        QuestieAvailableMapNotes[continent] = {};
    end
    if(QuestieAvailableMapNotes[continent][zoneid] == nil) then
        QuestieAvailableMapNotes[continent][zoneid] = {};
    end
    --Sets values that i want to use for the notes THIS IS WIP MORE INFO MAY BE NEDED BOTH IN PARAMETERS AND NOTES!!!
    Note = {};
    Note.x = posx;
    Note.y = posy;
    Note.zoneid = zoneid;
    Note.continent = continent;
    Note.icontype = type;
    Note.questHash = questHash;
    Note.objectiveid = objectiveid;
    Note.monsterName = monsterName
    --Inserts it into the right zone and continent for later use.
    table.insert(QuestieAvailableMapNotes[continent][zoneid], Note);
end
---------------------------------------------------------------------------------------------------
-- Gets a blank frame either from Pool or creates a new one!
---------------------------------------------------------------------------------------------------
function Questie:GetBlankNoteFrame(frame)
    if(table.getn(FramePool)==0) then
        Questie:CreateBlankFrameNote(frame);
    end
    f = FramePool[1];
    table.remove(FramePool, 1);
    return f;
end
---------------------------------------------------------------------------------------------------
-- Tooltip code for quest objects
---------------------------------------------------------------------------------------------------
function Questie:hookTooltipLineCheck()
    local oh = GameTooltip:GetScript("OnHide");
    GameTooltip:SetScript("OnHide", function(self, arg)
        if oh then
            oh(self, arg);
    end
        __TT_LineCache = {};
    end);
    GameTooltip.AddLine_orig = GameTooltip.AddLine;
    GameTooltip.AddLine = function(self, line, r, g, b, wrap)
        GameTooltip:AddLine_orig(line, r, g, b, wrap);
        if (line) then
            __TT_LineCache[line] = true;
        end
    end;
end
---------------------------------------------------------------------------------------------------
Questie_LastTooltip = GetTime();
QUESTIE_DEBUG_TOOLTIP = nil;
Questie_TooltipCache = {};
__TT_LineCache = {};
function Questie:Tooltip(this, forceShow, bag, slot)
    if (QuestieConfig.showToolTips == false) then return end
    if (QuestieConfig.showToolTips == true) then
        local monster = UnitName("mouseover")
        local objective = GameTooltipTextLeft1:GetText();
        local cacheKey = ""-- .. monster .. objective;
        local validKey = false;
        if(monster) then
            cacheKey = cacheKey .. monster;
            validKey = true;
        end
        if(objective) then
            cacheKey = cacheKey .. objective;
            validKey = true;
        end
        if not validKey then
            return;
        end
        if(Questie_TooltipCache[cacheKey] == nil) or (QUESTIE_LAST_UPDATE_FINISHED - Questie_TooltipCache[cacheKey]['updateTime']) > 0 then
            Questie_TooltipCache[cacheKey] = {};
            Questie_TooltipCache[cacheKey]['lines'] = {};
            Questie_TooltipCache[cacheKey]['lineCount'] = 1;
            Questie_TooltipCache[cacheKey]['updateTime'] = GetTime();
            if monster and GetTime() - Questie_LastTooltip > .01 then
                for k,v in pairs(QuestieHandledQuests) do
                    local obj = v['objectives']['objectives'];
                    if (obj) then
                        for name,m in pairs(obj) do
                            if m[1] and (m[1]['type'] == "monster" or m[1]['type'] == "slay") then
                                if (monster .. " slain") == name or monster == name or monster == string.find(monster, string.len(monster)-6) then
                                    local logid = Questie:GetQuestIdFromHash(k);
                                    if logid then
                                        QSelect_QuestLogEntry(logid);
                                        local desc, typ, done = QGet_QuestLogLeaderBoard(m[1]['objectiveid']);
                                        local indx = findLast(desc, ":");
                                        local countstr = string.sub(desc, indx+2);
                                        local lineIndex = Questie_TooltipCache[cacheKey]['lineCount'];
                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex] = {
                                            ['color'] = {1, 1, 1},
                                            ['data'] = " "
                                        };
                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex + 1] = {
                                            ['color'] = {0.2, 1, 0.3},
                                            ['data'] = v['objectives']['QuestName']
                                        };
                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex + 2] = {
                                            ['color'] = {1, 1, 0.2},
                                            ['data'] = "   " .. monster .. ": " .. countstr
                                        };
                                        Questie_TooltipCache[cacheKey]['lineCount'] = lineIndex + 3;
                                        mi = true;
                                    end
                                    if (mi) then
                                        break;
                                    end
                                end
                            elseif m[1] and (m[1]['type'] == "monster" or m[1]['type'] == "loot") then
                                local monroot = QuestieMonsters[monster];
                                if monroot then
                                    local mondat = monroot['drops'];
                                    if mondat and mondat[name] then
                                        if mondat[name] then
                                            local logid = Questie:GetQuestIdFromHash(k);
                                            if logid then
                                                QSelect_QuestLogEntry(logid);
                                                local desc, typ, done = QGet_QuestLogLeaderBoard(m[1]['objectiveid']);
                                                local indx = findLast(desc, ":");
                                                local countstr = string.sub(desc, indx+2);
                                                local lineIndex = Questie_TooltipCache[cacheKey]['lineCount'];
                                                Questie_TooltipCache[cacheKey]['lines'][lineIndex] = {
                                                    ['color'] = {1, 1, 1},
                                                    ['data'] = " "
                                                };
                                                Questie_TooltipCache[cacheKey]['lines'][lineIndex + 1] = {
                                                    ['color'] = {0.2, 1, 0.3},
                                                    ['data'] = v['objectives']['QuestName']
                                                };
                                                Questie_TooltipCache[cacheKey]['lines'][lineIndex + 2] = {
                                                    ['color'] = {1, 1, 0.2},
                                                    ['data'] = "   " .. name .. ": " .. countstr
                                                };
                                                Questie_TooltipCache[cacheKey]['lineCount'] = lineIndex + 3;
                                                mi = true;
                                            end
                                            if (mi) then
                                                break;
                                            end
                                        end
                                    else
                                        --Use the cache not to run unessecary objectives
                                        local mi = nil;
                                        for dropper, value in pairs(QuestieCachedMonstersAndObjects[k]) do
                                            if(string.find(dropper, monster)) then
                                                local logid = Questie:GetQuestIdFromHash(k);
                                                if logid then
                                                    QSelect_QuestLogEntry(logid);
                                                    local count =  QGet_NumQuestLeaderBoards();
                                                    for obj = 1, count do
                                                        local desc, typ, done = QGet_QuestLogLeaderBoard(obj);
                                                        local indx = findLast(desc, ":");
                                                        if indx~=nil then
                                                            local countstr = string.sub(desc, indx+2);
                                                            local namestr = string.sub(desc, 1, indx-1);
                                                            if(string.find(name, monster) and QuestieItems[namestr] and QuestieItems[namestr]['drop']) then -- Added Find to fix zapped giants (THIS IS NOT TESTED IF YOU FIND ERRORS REPORT!)
                                                                for dropperr, id in pairs(QuestieItems[namestr]['drop']) do
                                                                    if(name == dropperr or (string.find(name, dropperr) and name == dropperr) and not p) then-- Added Find to fix zapped giants (THIS IS NOT TESTED IF YOU FIND ERRORS REPORT!)
                                                                        local lineIndex = Questie_TooltipCache[cacheKey]['lineCount'];
                                                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex] = {
                                                                            ['color'] = {1, 1, 1},
                                                                            ['data'] = " "
                                                                        };
                                                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex + 1] = {
                                                                            ['color'] = {0.2, 1, 0.3},
                                                                            ['data'] = v['objectives']['QuestName']
                                                                        };
                                                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex + 2] = {
                                                                            ['color'] = {1, 1, 0.2},
                                                                            ['data'] = "   " .. namestr .. ": " .. countstr
                                                                        };
                                                                        Questie_TooltipCache[cacheKey]['lineCount'] = lineIndex + 3;
                                                                        mi = true;
                                                                    end
                                                                    if (mi) then
                                                                        break;
                                                                    end
                                                                end
                                                            end
                                                        else
                                                            local lineIndex = Questie_TooltipCache[cacheKey]['lineCount'];
                                                            Questie_TooltipCache[cacheKey]['lines'][lineIndex] = {
                                                                ['color'] = {1, 1, 1},
                                                                ['data'] = " "
                                                            };
                                                            Questie_TooltipCache[cacheKey]['lines'][lineIndex + 1] = {
                                                                ['color'] = {0.2, 1, 0.3},
                                                                ['data'] = v['objectives']['QuestName']
                                                            };
                                                            Questie_TooltipCache[cacheKey]['lineCount'] = lineIndex + 2;
                                                            mi = true;
                                                        end
                                                        if (mi) then
                                                            break;
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                if mi then
                    GameTooltip.lastmonster = monster;
                    GameTooltip.lastobjective = nil;
                end
            elseif objective and GetTime() - Questie_LastTooltip < 0.05 then
                for k,v in pairs(QuestieHandledQuests) do
                    local obj = v['objectives']['objectives'];
                    if ( obj ) then
                        for name,m in pairs(obj) do
                            if (m[1] and m[1]['type'] == "object") then
                                local i, j = string.gfind(name, objective);
                                if(i and j and QuestieObjects[name]) then
                                    local lineIndex = Questie_TooltipCache[cacheKey]['lineCount'];
                                    Questie_TooltipCache[cacheKey]['lines'][lineIndex] = {
                                        ['color'] = {1, 1, 1},
                                        ['data'] = " "
                                    };
                                    Questie_TooltipCache[cacheKey]['lines'][lineIndex + 1] = {
                                        ['color'] = {0.2, 1, 0.3},
                                        ['data'] = v['objectives']['QuestName']
                                    };
                                    Questie_TooltipCache[cacheKey]['lines'][lineIndex + 2] = {
                                        ['color'] = {1, 1, 0.2},
                                        ['data'] = "   " .. name
                                    };
                                    Questie_TooltipCache[cacheKey]['lineCount'] = lineIndex + 3;
                                    mi = true;
                                end
                                if (mi) then
                                    break;
                                end
                            elseif (m[1] and (m[1]['type'] == "item" or m[1]['type'] == "loot") and name == objective) then
                                if(QuestieItems[objective]) then
                                    local logid = Questie:GetQuestIdFromHash(k);
                                    if logid then
                                        QSelect_QuestLogEntry(logid);
                                        local desc, typ, done = QGet_QuestLogLeaderBoard(m[1]['objectiveid']);
                                        local indx = findLast(desc, ":");
                                        local countstr = string.sub(desc, indx+2);
                                        local lineIndex = Questie_TooltipCache[cacheKey]['lineCount'];
                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex] = {
                                            ['color'] = {1, 1, 1},
                                            ['data'] = " "
                                        };
                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex + 1] = {
                                            ['color'] = {0.2, 1, 0.3},
                                            ['data'] = v['objectives']['QuestName']
                                        };
                                        Questie_TooltipCache[cacheKey]['lines'][lineIndex + 2] = {
                                            ['color'] = {1, 1, 0.2},
                                            ['data'] = "   " .. name .. ": " .. countstr
                                        };
                                        Questie_TooltipCache[cacheKey]['lineCount'] = lineIndex + 3;
                                        mi = true;
                                    end
                                    if (mi) then
                                        break;
                                    end
                                end
                            end
                        end
                    end
                end
                if (mi) then
                    GameTooltip.lastmonster = nil;
                    GameTooltip.lastobjective = objective;
                end
            end
        end
        for k, v in pairs(Questie_TooltipCache[cacheKey]['lines']) do
            if not __TT_LineCache[v['data']] then
                GameTooltip:AddLine(v['data'], v['color'][1], v['color'][2], v['color'][3]);
            end
        end
        if(QUESTIE_DEBUG_TOOLTIP) then
            GameTooltip:AddLine("--Questie hook--")
        end
        if(forceShow) then
            GameTooltip:Show();
        end
        GameTooltip.QuestieDone = true;
        Questie_LastTooltip = GetTime();
        Questie_TooltipCache = {};
        mi = nil;
    end
end
---------------------------------------------------------------------------------------------------
-- Tooltip code for quest starters and finishers
---------------------------------------------------------------------------------------------------
function Questie_Tooltip_OnEnter()
    if(this.data.questHash) then
        local Tooltip = GameTooltip;
        if(this.type == "WorldMapNote") then
            Tooltip = WorldMapTooltip;
        else
            Tooltip = GameTooltip;
        end
        Tooltip:SetOwner(this, this); --"ANCHOR_CURSOR"
        local count = 0
        local canManualComplete = 0
        local orderedQuests = {}
        for questHash, questMeta in pairs(this.quests) do
            orderedQuests[questMeta['sortOrder']] = questMeta
        end
        for i, questMeta in pairs(orderedQuests) do
            local data = questMeta['quest']
            count = count + 1
            if (count > 1) then
                Tooltip:AddLine(" ");
            end
            if(data.icontype ~= "available") then
                local Quest = Questie:IsQuestFinished(data.questHash);
                if not Quest then
                    local QuestLogID = Questie:GetQuestIdFromHash(data.questHash);
                    if QuestLogID then
                        QSelect_QuestLogEntry(QuestLogID);
                        local q, level, questTag, isHeader, isCollapsed, isComplete = QGet_QuestLogTitle(QuestLogID);
                        Tooltip:AddLine(q);

                        for objectiveid, lootnames in questMeta['objectives'] do
                            local desc, typ, done = QGet_QuestLogLeaderBoard(objectiveid);
                            Tooltip:AddLine(desc,1,1,1);
                            local prefix
                            if data.icontype == "object" then
                                prefix = "Contained in"
                            elseif data.icontype == "loot" then
                                prefix = "Dropped by"
                            end
                            local lootnamesCombined
                            for lootname, b in pairs(lootnames) do
                                if lootnamesCombined == nil then
                                    lootnamesCombined = lootname
                                else
                                    lootnamesCombined = lootnamesCombined..", "..lootname
                                end
                            end
                            if prefix then
                                Tooltip:AddLine(prefix..": |cFFa6a6a6"..lootnamesCombined.."|r",1,1,1,true);
                            end
                        end
                    end
                else
                    Tooltip:AddLine("["..QuestieHashMap[data.questHash].questLevel.."] "..Quest["name"].." |cFF33FF00(complete)|r");
                    Tooltip:AddLine("Finished by: |cFFa6a6a6"..QuestieHashMap[data.questHash].finishedBy.."|r",1,1,1);
                end
            else
                questOb = nil
                local QuestName = tostring(QuestieHashMap[data.questHash].name)
                if QuestName then
                    local index = 0
                    for k,v in pairs(QuestieLevLookup[QuestName]) do
                        index = index + 1
                        if (index == 1) and (v[2] == data.questHash) and (k ~= "") then
                            questOb = k
                        elseif (index > 0) and(v[2] == data.questHash) and (k ~= "") then
                            questOb = k
                        elseif (index == 1) and (v[2] ~= data.questHash) and (k ~= "") then
                            questOb = k
                        end
                    end
                end
                Tooltip:AddLine("["..QuestieHashMap[data.questHash].questLevel.."] "..QuestieHashMap[data.questHash].name.." |cFF33FF00(available)|r");
                Tooltip:AddLine("Min Level: |cFFa6a6a6"..QuestieHashMap[data.questHash].level.."|r",1,1,1);
                Tooltip:AddLine("Started by: |cFFa6a6a6"..QuestieHashMap[data.questHash].startedBy.."|r",1,1,1);

                local prefix
                if QuestieHashMap[data.questHash].startedType == "object" then
                    prefix = "Contained in"
                elseif QuestieHashMap[data.questHash].startedType == "item" then
                    prefix = "Dropped by"
                end
                local monstedNamesCombined
                for monsterName, b in pairs(questMeta['monsterName']) do
                    if monstedNamesCombined == nil then
                        monstedNamesCombined = monsterName
                    else
                        monstedNamesCombined = monstedNamesCombined..", "..monsterName
                    end
                end
                if prefix and monsterNamesCombined then
                    Tooltip:AddLine(prefix..": |cFFa6a6a6"..monstedNamesCombined.."|r",1,1,1,true);
                end
                if questOb ~= nil then
                    Tooltip:AddLine("Description: |cFFa6a6a6"..questOb.."|r",1,1,1,true);
                end
                canManualComplete = 1
            end
        end
        if canManualComplete > 0 then
            if count > 1 then
                Tooltip:AddLine(" ");
            end
            Tooltip:AddLine("Shift+Click: |cFFa6a6a6Manually complete quest!|r",1,1,1);
        end
        if(NOTES_DEBUG and IsAltKeyDown()) then
            Tooltip:AddLine("!DEBUG!", 1, 0, 0);
            Tooltip:AddLine("QuestID: "..this.data.questHash, 1, 0, 0);
        end
        Tooltip:SetFrameStrata("TOOLTIP");
        Tooltip:Show();
    end
end
---------------------------------------------------------------------------------------------------
-- Force a quest to be finished via the Minimap or Worldmap (Shift-Click icon - NO confirmation)
---------------------------------------------------------------------------------------------------
function Questie_AvailableQuestClick()
    local Tooltip = GameTooltip
    if(this.type == "WorldMapNote") then
        Tooltip = WorldMapTooltip
    else
        Tooltip = GameTooltip
    end
    if (QuestieConfig.arrowEnabled == true) and (arg1 == "LeftButton") and (QuestieSeenQuests[this.data.questHash] == 0) and (QuestieTrackedQuests[this.data.questHash] ~= false) and (not IsControlKeyDown()) and (not IsShiftKeyDown()) then
        SetArrowObjective(this.data.questHash)
    end
    if ( IsShiftKeyDown() and Tooltip ) then
        local finishQuest = function(quest)
            if (quest.icontype == "available") then
                Questie:Toggle()
                local hash = quest.questHash
                local questName = "["..QuestieHashMap[hash].questLevel.."] "..QuestieHashMap[hash]['name']
                Questie:finishAndRecurse(hash)
                DEFAULT_CHAT_FRAME:AddMessage("Completing quest |cFF00FF00\"" .. questName .. "\"|r and parent quest: "..hash)
                Questie:Toggle()
            end
        end
        local count = 0
        local firstQuest
        for questHash, questMeta in pairs(this.quests) do
            count = count + 1
            if not firstQuest then
                firstQuest = questMeta['quest']
            end
        end
        if (count < 2) then
            -- Finish first quest in list
            finishQuest(firstQuest)
        else
            -- Open Dewdrop to select which quest to finish
            local closeFunc = function()
                Dewdrop:Close()
            end
            if (IsAddOnLoaded("Cartographer")) or (IsAddOnLoaded("MetaMap")) or (QuestieConfig.resizeWorldmap == true) then
                Dewdrop:Register(WorldMapFrame,
                    'children', function()
                        for questHash, questMeta in pairs(this.quests) do
                            local quest = questMeta['quest']
                            local hash = questHash
                            local questName = "["..QuestieHashMap[hash].questLevel.."] "..QuestieHashMap[hash]['name']
                            local finishFunc = function(quest)
                                finishQuest(quest)
                                Dewdrop:Close()
                            end
                            Dewdrop:AddLine(
                                'text', questName,
                                'notClickable', quest.icontype ~= "available",
                                'icon', QuestieIcons[quest.icontype].path,
                                'iconCoordLeft', 0,
                                'iconCoordRight', 1,
                                'iconCoordTop', 0,
                                'iconCoordBottom', 1,
                                'func', finishFunc,
                                'arg1', quest
                            )
                        end
                        Dewdrop:AddLine(
                            'text', "",
                            'notClickable', true
                        )
                        Dewdrop:AddLine(
                            'text', "Cancel",
                            'func', closeFunc
                        )
                    end,
                    'dontHook', true,
                    'cursorX', true,
                    'cursorY', true
                )
                Dewdrop:Open(WorldMapFrame)
                Dewdrop:Unregister(WorldMapFrame)
            elseif (not IsAddOnLoaded("Cartographer")) or (not IsAddOnLoaded("MetaMap")) and (QuestieConfig.resizeWorldmap == false) then
                Dewdrop:Register(this,
                    'children', function()
                        for i, quest in pairs(this.quests) do
                            local hash = quest.questHash
                            local questName = "["..QuestieHashMap[hash].questLevel.."] "..QuestieHashMap[hash]['name']
                            local finishFunc = function(quest)
                                finishQuest(quest)
                                Dewdrop:Close()
                            end
                            Dewdrop:AddLine(
                                'text', questName,
                                'notClickable', quest.icontype ~= "available",
                                'icon', QuestieIcons[quest.icontype].path,
                                'iconCoordLeft', 0,
                                'iconCoordRight', 1,
                                'iconCoordTop', 0,
                                'iconCoordBottom', 1,
                                'func', finishFunc,
                                'arg1', quest
                            )
                        end
                        Dewdrop:AddLine(
                            'text', "",
                            'notClickable', true
                        )
                        Dewdrop:AddLine(
                            'text', "Cancel",
                            'func', closeFunc
                        )
                    end,
                    'dontHook', true,
                    'point', "TOPLEFT",
                    'relativePoint', "BOTTOMRIGHT"
                )
                Dewdrop:Open(this)
                Dewdrop:Unregister(this)
            end
            if (IsAddOnLoaded("Cartographer")) and (CartographerDB["disabledModules"]["Default"]["Look 'n' Feel"] == true) then
                Dewdrop:Register(this,
                    'children', function()
                        for i, quest in pairs(this.quests) do
                            local hash = quest.questHash
                            local questName = "["..QuestieHashMap[hash].questLevel.."] "..QuestieHashMap[hash]['name']
                            local finishFunc = function(quest)
                                finishQuest(quest)
                                Dewdrop:Close()
                            end
                            Dewdrop:AddLine(
                                'text', questName,
                                'notClickable', quest.icontype ~= "available",
                                'icon', QuestieIcons[quest.icontype].path,
                                'iconCoordLeft', 0,
                                'iconCoordRight', 1,
                                'iconCoordTop', 0,
                                'iconCoordBottom', 1,
                                'func', finishFunc,
                                'arg1', quest
                            )
                        end
                        Dewdrop:AddLine(
                            'text', "",
                            'notClickable', true
                        )
                        Dewdrop:AddLine(
                            'text', "Cancel",
                            'func', closeFunc
                        )
                    end,
                    'dontHook', true,
                    'point', "TOPLEFT",
                    'relativePoint', "BOTTOMRIGHT"
                )
                Dewdrop:Open(this)
                Dewdrop:Unregister(this)
            end
        end
    end
end
---------------------------------------------------------------------------------------------------
-- Creates a blank frame for use within the map system
---------------------------------------------------------------------------------------------------
CREATED_NOTE_FRAMES = 1;
function Questie:CreateBlankFrameNote(frame)
    local f = CreateFrame("Button","QuestieNoteFrame"..CREATED_NOTE_FRAMES,frame)
    local t = f:CreateTexture(nil,"BACKGROUND")
    f.texture = t
    f:SetScript("OnEnter", Questie_Tooltip_OnEnter); --Script Toolip
    f:SetScript("OnLeave", function() if(WorldMapTooltip) then WorldMapTooltip:Hide() end if(GameTooltip) then GameTooltip:Hide() end end) --Script Exit Tooltip
    f:SetScript("OnClick", Questie_AvailableQuestClick);
    f:RegisterForClicks("LeftButtonDown", "RightButtonDown");
    CREATED_NOTE_FRAMES = CREATED_NOTE_FRAMES+1;
    table.insert(FramePool, f);
    table.insert(AllFrames, f);
end

function Questie:GetFrameNote(data, parentFrame, frameLevel, type, scale)
    if(table.getn(FramePool)==0) then
        Questie:CreateFrameNote(data, parentFrame, frameLevel, type, scale);
    end
    f = FramePool[1];
    table.remove(FramePool, 1);
    return f;
end

function Questie:SetFrameNoteData(f, data, parentFrame, frameLevel, type, scale)
    f.data = data;
    f.quests = {}
    f.questOrders = {}
    Questie:AddFrameNoteData(f, data)
    f:SetParent(parentFrame);
    f:SetFrameLevel(frameLevel);
    f:SetPoint("CENTER",0,0);
    f.type = type;
    f:SetWidth(16*scale)  -- Set These to whatever height/width is needed
    f:SetHeight(16*scale) -- for your Texture
    f.texture:SetTexture(QuestieIcons[data.icontype].path)
    f.texture:SetAllPoints(f)
end

function Questie:AddFrameNoteData(icon, data)
    if icon then
        if (icon.averageX == nil or icon.averageY == nil) then
            icon.averageX = 0
            icon.averageY = 0
        end
        local numQuests = 0
        for k, v in pairs(icon.quests) do
            numQuests = numQuests + 1
        end
        local newAverageX = (icon.averageX * numQuests + data.x) / (numQuests + 1)
        local newAverageY = (icon.averageY * numQuests + data.y) / (numQuests + 1)
        icon.averageX = newAverageX
        icon.averageY = newAverageY

        if icon.quests[data.questHash] then
            -- Add cumulative quest data
            if data.monsterName then
                icon.quests[data.questHash]['monsterName'][data.monsterName] = 1
            end

            if icon.quests[data.questHash]['objectives'][data.objectiveid] == nil then
                icon.quests[data.questHash]['objectives'][data.objectiveid] = {}
            end
            if data.lootname then
                icon.quests[data.questHash]['objectives'][data.objectiveid][data.lootname] = 1
            end
        else
            icon.quests[data.questHash] = {}
            icon.quests[data.questHash]['quest'] = data
            icon.quests[data.questHash]['sortOrder'] = numQuests + 1
            icon.quests[data.questHash]['monsterName'] = {}
            if data.monsterName then
                icon.quests[data.questHash]['monsterName'][data.monsterName] = 1
            end
            icon.quests[data.questHash]['objectives'] = {}
            icon.quests[data.questHash]['objectives'][data.objectiveid] = {}
            if data.lootname then
                icon.quests[data.questHash]['objectives'][data.objectiveid][data.lootname] = 1
            end
        end
    end
end

TICK_DELAY = 0.01;--0.1 Atm not to get spam while debugging should probably be a lot faster...
LAST_TICK = GetTime();
local LastContinent = nil;
local LastZone = nil;
UIOpen = false;
NATURAL_REFRESH = 60;
NATRUAL_REFRESH_SPACING = 2;
---------------------------------------------------------------------------------------------------
-- Updates notes for current zone only
---------------------------------------------------------------------------------------------------
function Questie:NOTES_ON_UPDATE(elapsed)
    --Test to remove the delay
    --Gets current map to see if we need to redraw or not.
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone();
    if(c ~= LastContinent or LastZone ~= z) then
        --Clears before redrawing
        Questie:SetAvailableQuests();
        Questie:RedrawNotes();
        --Sets the last continent and zone to hinder spam.
        LastContinent = c;
        LastZone = z;
    end
    --NOT NEEDED BUT KEEPING FOR AWHILE
    if(WorldMapFrame:IsVisible() and UIOpen == false) then
        Questie:debug_Print("Created Frames: "..CREATED_NOTE_FRAMES, "Used Frames: "..table.getn(QuestieUsedNoteFrames), "Free Frames: "..table.getn(FramePool));
        UIOpen = true;
    elseif(WorldMapFrame:IsVisible() == nil and UIOpen == true) then
        UIOpen = false;
    end
end
---------------------------------------------------------------------------------------------------
-- Inital pool size (Not tested how much you can do before it lags like shit, from experiance 11
-- is good)
---------------------------------------------------------------------------------------------------
INIT_POOL_SIZE = 11;
function Questie:NOTES_LOADED()
    Questie:debug_Print("Loading QuestieNotes");
    if(table.getn(FramePool) < 10) then--For some reason loading gets done several times... added this in as safety
        for i = 1, INIT_POOL_SIZE do
            Questie:CreateBlankFrameNote();
        end
    end
    Questie:debug_Print("Done Loading QuestieNotes");
end
---------------------------------------------------------------------------------------------------
-- Sets up all available quests
---------------------------------------------------------------------------------------------------
function Questie:SetAvailableQuests()
    QuestieAvailableMapNotes = {};
    local t = GetTime();
    local level = UnitLevel("player");
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone();
    local mapFileName = GetMapInfo();
    local quests = nil;
    local minlevel = QuestieConfig.minShowLevel
    local maxlevel = QuestieConfig.maxShowLevel
    -- minLevelFilter: ON / maxLevelFilter: OFF
    if QuestieConfig.minLevelFilter and not QuestieConfig.maxLevelFilter then
        quests = Questie:GetAvailableQuestHashes(mapFileName,(level - minlevel),level);
    -- minLevelFilter: OFF / maxLevelFilter: ON
    elseif not QuestieConfig.minLevelFilter and QuestieConfig.maxLevelFilter then
        quests = Questie:GetAvailableQuestHashes(mapFileName,0,(level + maxlevel));
    -- minLevelFilter: ON / maxLevelFilter: ON
    elseif QuestieConfig.minLevelFilter and QuestieConfig.maxLevelFilter then
        quests = Questie:GetAvailableQuestHashes(mapFileName,(level - minlevel),(level + maxlevel));
    -- minLevelFilter: OFF / maxLevelFilter: OFF
    elseif not QuestieConfig.minLevelFilter and not QuestieConfig.maxLevelFilter then
        quests = Questie:GetAvailableQuestHashes(mapFileName,0,level);
    end
    if quests then
        -- Monsters
        for k, v in pairs(quests) do
            if(QuestieHashMap[v] and QuestieHashMap[v]['startedBy'] and QuestieMonsters[QuestieHashMap[v]['startedBy']]) then
                Monster = QuestieMonsters[QuestieHashMap[v]['startedBy']]['locations'][1]
                local MapInfo = Questie:GetMapInfoFromID(Monster[1]);
                Questie:AddAvailableNoteToMap(c,z,Monster[2],Monster[3],"available",v,-1);
            end
        end
        -- Objects
        for k, v in pairs(quests) do
            if(QuestieHashMap[v] and QuestieHashMap[v]['startedBy'] and QuestieObjects[QuestieHashMap[v]['startedBy']]) then
                Objects = QuestieObjects[QuestieHashMap[v]['startedBy']]['locations'][1]
                local MapInfo = Questie:GetMapInfoFromID(Objects[1]);
                Questie:AddAvailableNoteToMap(c,z,Objects[2],Objects[3],"available",v,-1);
            end
        end
        -- Items
        for k, v in pairs(quests) do
            if(QuestieHashMap[v] and QuestieHashMap[v]['startedBy'] and QuestieItems[QuestieHashMap[v]['startedBy']]) then
                local item = QuestieItems[QuestieHashMap[v]['startedBy']]
                if item['drop'] then
                    local monsters = item['drop']
                    for monsterName, someId in pairs(monsters) do
                        local monster = QuestieMonsters[monsterName]
                        local locations = monster['locations']
                        for i, location in pairs(locations) do
                            local MapInfo = Questie:GetMapInfoFromID(location[1])
                            Questie:AddAvailableNoteToMap(c,z,location[2],location[3],"available",v,-1, monsterName)
                        end
                    end
                end
                -- todo items shouldn't really have locations i dont think. - ZoeyZolotova
                if item['locations'] then
                    local locations = item['locations']
                    for i, location in pairs(locations) do
                        local MapInfo = Questie:GetMapInfoFromID(location[1])
                        Questie:AddAvailableNoteToMap(c,z,location[2],location[3],"available",v,-1)
                    end
                end
            end
        end
        Questie:debug_Print("Added Available quests: Time:",tostring((GetTime()- t)*1000).."ms", "Count:"..table.getn(quests))
    end
end
---------------------------------------------------------------------------------------------------
-- Reason this exists is to be able to call both clearnotes and drawnotes without doing 2 function
-- calls, and to be able to force a redraw
---------------------------------------------------------------------------------------------------
function Questie:RedrawNotes()
    local time = GetTime();
    Questie:CLEAR_ALL_NOTES();
    Questie:DRAW_NOTES();
    Questie:debug_Print("Notes redrawn time:", tostring((GetTime()- time)*1000).."ms");
    time = nil;
end

function Questie:Clear_Note(v)
    v:SetParent(nil);
    v:Hide();
    v:SetAlpha(1);
    v:SetFrameLevel(9);
    v:SetHighlightTexture(nil, "ADD");
    v.questHash = nil;
    v.objId = nil;
    table.insert(FramePool, v);
end
---------------------------------------------------------------------------------------------------
-- Clears the notes, goes through the usednoteframes and clears them. Then sets the
-- QuestieUsedNotesFrame to new table;
---------------------------------------------------------------------------------------------------
function Questie:CLEAR_ALL_NOTES()
    --DEFAULT_CHAT_FRAME:AddMessage("Clearing map notes!")
    Questie:debug_Print("CLEAR_NOTES");
    Astrolabe:RemoveAllMinimapIcons();
    clustersByFrame = nil
    for k, v in pairs(QuestieUsedNoteFrames) do
        --Questie:debug_Print("Hash:"..v.questHash,"Type:"..v.type);
        Questie:Clear_Note(v);
    end
    QuestieUsedNoteFrames = {};
end
---------------------------------------------------------------------------------------------------
-- Logic for clusters
---------------------------------------------------------------------------------------------------
local Cluster = {}
Cluster.__index = Cluster

function Cluster.new(points)
    local self = setmetatable({}, Cluster)
    self.points = points
    return self
end

function Cluster.CalculateDistance(x1, y1, x2, y2)
    local deltaX = x1 - x2
    local deltaY = y1 - y2
    return sqrt(deltaX*deltaX + deltaY*deltaY)
end

function Cluster.CalculateLinkageDistance(cluster1, cluster2)
    local total = 0
    for i, pi in cluster1 do
        for j, pj in cluster2 do
            local distance = Cluster.CalculateDistance(pi.x, pi.y, pj.x, pj.y)
            total = total + distance;
        end
    end
    return total / (table.getn(cluster1) * table.getn(cluster2))
end

function Cluster:CalculateClusters(clusters, distanceThreshold, maxClusterSize)
    while table.getn(clusters) > 1 do
        local nearest1
        local nearest2
        local nearestDistance
        for i, cluster in pairs(clusters) do
            for j, otherCluster in pairs(clusters) do
                if cluster ~= otherCluster then
                    local distance = Cluster.CalculateLinkageDistance(cluster.points, otherCluster.points)
                    if distance == 0 or ((nearestDistance == nil or distance < nearestDistance) and (table.getn(cluster.points) + table.getn(otherCluster.points) <= maxClusterSize)) then
                        nearestDistance = distance
                        nearest1 = cluster
                        nearest2 = otherCluster
                    end
                end
                if nearestDistance == 0 then break end
            end
            if nearestDistance == 0 then break end
        end

        if nearestDistance == nil or nearestDistance > distanceThreshold then break end
        local index1 = indexOf(clusters, nearest1)
        table.remove(clusters, index1)
        local index2 = indexOf(clusters, nearest2)
        table.remove(clusters, index2)

        local points = nearest1.points
        for i, point in pairs(nearest2.points) do
            table.insert(points, point)
        end
        local newCluster = Cluster.new(points)
        table.insert(clusters, newCluster)
    end
end

function Questie:AddClusterFromNote(frame, identifier, v)
    if clustersByFrame == nil then
        clustersByFrame = {}
    end
    if clustersByFrame[frame] == nil then
        clustersByFrame[frame] = {}
    end
    if clustersByFrame[frame][identifier] == nil then
        clustersByFrame[frame][identifier] = {}
    end
    if clustersByFrame[frame][identifier][v.x] == nil then
        clustersByFrame[frame][identifier][v.x] = {}
    end
    if clustersByFrame[frame][identifier][v.x][v.y] == nil then
        local points = { v }
        local cluster = Cluster.new(points)
        clustersByFrame[frame][identifier][v.x][v.y] = cluster
    else
        table.insert(clustersByFrame[frame][identifier][v.x][v.y].points, v)
    end
end

function Questie:GetClustersByFrame(frame, identifier)
    if clustersByFrame == nil then
        clustersByFrame = {}
    end
    if clustersByFrame[frame] == nil then
        clustersByFrame[frame] = {}
    end
    if clustersByFrame[frame][identifier] == nil then
        clustersByFrame[frame][identifier] = {}
    end
    local clusters = {}
    for x, v in pairs(clustersByFrame[frame][identifier]) do
        for y, v in pairs(clustersByFrame[frame][identifier][x]) do
            table.insert(clusters, clustersByFrame[frame][identifier][x][y])
        end
    end
    return clusters
end
---------------------------------------------------------------------------------------------------
-- Finds the index of an item in a table. Not sure if a function already exists somewhere.
---------------------------------------------------------------------------------------------------
function indexOf(table, item)
    for k, v in pairs(table) do
        if v == item then return k end
    end
    return nil
end
---------------------------------------------------------------------------------------------------
-- Checks first if there are any notes for the current zone, then draws the desired icon
---------------------------------------------------------------------------------------------------
function Questie:DRAW_NOTES()
    --DEFAULT_CHAT_FRAME:AddMessage("Drawing map notes!")
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone();
    Questie:debug_Print("DRAW_NOTES");
    if not QuestieConfig.hideMinimapIcons then
        -- Draw minimap objective markers
        if(QuestieMapNotes[c] and QuestieMapNotes[c][z]) then
            for k, v in pairs(QuestieMapNotes[c][z]) do
                --If an available quest isn't in the zone or we aren't tracking a quest on the QuestTracker then hide the objectives from the minimap
                local show = QuestieConfig.alwaysShowQuests or ((MMLastX ~= 0) and (MMLastY ~= 0)) and (QuestieTrackedQuests[v.questHash] ~= nil) and (QuestieTrackedQuests[v.questHash]["tracked"] ~= false)
                if show then
                    if v.icontype == "complete" then
                        Questie:AddClusterFromNote("MiniMapNote", "Quests", v)
                    else
                        Questie:AddClusterFromNote("MiniMapNote", "Objectives", v)
                    end
                end
            end
        end
    end
    -- Draw world map objective markers
    for k, Continent in pairs(QuestieMapNotes) do
        for zone, noteHeap in pairs(Continent) do
            for k, v in pairs(noteHeap) do
                if true then
                    --If we aren't tracking a quest on the QuestTracker then hide the objectives from the worldmap
                    if ( ( (QuestieTrackedQuests[v.questHash] ~= nil) and (QuestieTrackedQuests[v.questHash]["tracked"] ~= false) ) or (v.icontype == "complete") ) and (QuestieConfig.alwaysShowQuests == false) then
                        if v.icontype == "complete" then
                            Questie:AddClusterFromNote("WorldMapNote", "Quests", v)
                        else
                            Questie:AddClusterFromNote("WorldMapNote", "Objectives", v)
                        end
                    elseif (QuestieConfig.alwaysShowQuests == true) then
                        if v.icontype == "complete" then
                            Questie:AddClusterFromNote("WorldMapNote", "Quests", v)
                        else
                            Questie:AddClusterFromNote("WorldMapNote", "Objectives", v)
                        end
                    end
                end
            end
        end
    end

    -- Draw available quest markers.
    if(QuestieAvailableMapNotes[c] and QuestieAvailableMapNotes[c][z]) then
        if Active == true then
            local con,zon,x,y = Astrolabe:GetCurrentPlayerPosition();
            for k, v in pairs(QuestieAvailableMapNotes[c][z]) do
                Questie:AddClusterFromNote("WorldMapNote", "Quests", v)
                if not QuestieConfig.hideMinimapIcons then
                    Questie:AddClusterFromNote("MiniMapNote", "Quests", v)
                end
            end
        end
    end

    local minimapObjectiveClusters = Questie:GetClustersByFrame("MiniMapNote", "Objectives")
    local worldMapObjectiveClusters = Questie:GetClustersByFrame("WorldMapNote", "Objectives")

    local minimapClusters = Questie:GetClustersByFrame("MiniMapNote", "Quests")
    local worldMapClusters = Questie:GetClustersByFrame("WorldMapNote", "Quests")
    if QuestieConfig.clusterQuests then
        Cluster:CalculateClusters(worldMapClusters, 0.025, 5)
    end


    local scale = QUESTIE_NOTES_MAP_ICON_SCALE;
    if(z == 0 and c == 0) then--Both continents
        scale = QUESTIE_NOTES_WORLD_MAP_ICON_SCALE;
    elseif(z == 0) then--Single continent
        scale = QUESTIE_NOTES_CONTINENT_ICON_SCALE;
    end
    Questie:DrawClusters(worldMapObjectiveClusters, "WorldMapNote", scale, WorldMapFrame, WorldMapButton)
    Questie:DrawClusters(worldMapClusters, "WorldMapNote", scale, WorldMapFrame, WorldMapButton)
    Questie:DrawClusters(minimapObjectiveClusters, "MiniMapNote", QUESTIE_NOTES_MINIMAP_ICON_SCALE, Minimap)
    Questie:DrawClusters(minimapClusters, "MiniMapNote", QUESTIE_NOTES_MINIMAP_ICON_SCALE, Minimap)
end

function Questie:DrawClusters(clusters, frameName, scale, frame, button)
    local frameLevel = 9
    if frameName == "MiniMapNote" then
        frameLevel = 7
    end
    for i, cluster in pairs(clusters) do
        table.sort(cluster.points, function(a, b)
            local questA = QuestieHashMap[a.questHash]
            local questB = QuestieHashMap[b.questHash]
            return
                (a.icontype == "complete" and b.icontype ~= "complete") or
                (a.icontype == b.icontype and questA.level < questB.level) or
                (a.icontype == b.icontype and questA.level == questB.level and questA.questLevel < questB.questLevel)
        end)
        Icon = Questie:GetBlankNoteFrame(frame)
        local mainV = cluster.points[1]
        for j, v in pairs(cluster.points) do
            if j == 1 then
                local finalFrameLevel = frameLevel
                if v.icontype == "complete" then finalFrameLevel = finalFrameLevel + 1 end
                Questie:SetFrameNoteData(Icon, v, frame, finalFrameLevel, frameName, scale)
            else
                Questie:AddFrameNoteData(Icon, v)
            end
        end

        if frameName == "MiniMapNote" then
            Icon:SetHighlightTexture(QuestieIcons[mainV.icontype].path, "ADD");
            Astrolabe:PlaceIconOnMinimap(Icon, mainV.continent, mainV.zoneid, Icon.averageX, Icon.averageY);
        else
            Icon:Show()
            xx, yy = Astrolabe:PlaceIconOnWorldMap(button, Icon, mainV.continent, mainV.zoneid, Icon.averageX, Icon.averageY)
            if(xx and yy and xx > 0 and xx < 1 and yy > 0 and yy < 1) then
                table.insert(QuestieUsedNoteFrames, Icon);
            else
                Questie:Clear_Note(Icon);
            end
        end
    end
end
---------------------------------------------------------------------------------------------------
-- Debug print function
---------------------------------------------------------------------------------------------------
function Questie:debug_Print(...)
    local debugWin = 0;
    local name, shown;
    for i=1, NUM_CHAT_WINDOWS do
        name,_,_,_,_,_,shown = GetChatWindowInfo(i);
        if (string.lower(name) == "questiedebug") then debugWin = i; break; end
    end
    if (debugWin == 0) then return end
    local out = "";
    for i = 1, arg.n, 1 do
        if (i > 1) then out = out .. ", "; end
        local t = type(arg[i]);
        if (t == "string") then
            out = out .. '"'..arg[i]..'"';
        elseif (t == "number") then
            out = out .. arg[i];
        else
            out = out .. dump(arg[i]);
        end
    end
    getglobal("ChatFrame"..debugWin):AddMessage(out, 1.0, 1.0, 0.3);
end
---------------------------------------------------------------------------------------------------
-- Sets the icon type
---------------------------------------------------------------------------------------------------
QuestieIcons = {
    ["complete"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\complete"
    },
    ["available"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\available"
    },
    ["loot"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\loot"
    },
    ["item"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\loot"
    },
    ["event"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\event"
    },
    ["object"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\object"
    },
    ["slay"] = {
        text = "Complete",
        path = "Interface\\AddOns\\!Questie\\Icons\\slay"
    }
}
