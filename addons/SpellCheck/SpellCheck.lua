--Copyright © 2015, Damien Dennehy
--All rights reserved.

--Redistribution and use in source and binary forms, with or without
--modification, are permitted provided that the following conditions are met:

--    * Redistributions of source code must retain the above copyright
--      notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above copyright
--      notice, this list of conditions and the following disclaimer in the
--      documentation and/or other materials provided with the distribution.
--    * Neither the name of SpellCheck nor the
--      names of its contributors may be used to endorse or promote products
--      derived from this software without specific prior written permission.

--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
--ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
--WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
--DISCLAIMED. IN NO EVENT SHALL DAMIEN DENNEHY BE LIABLE FOR ANY
--DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
--(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
--LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
--ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
--SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

_addon.name    = 'SpellCheck'
_addon.author  = 'Zubis'
_addon.version = '1.1.0'
_addon.command = 'SpellCheck'

require('sets')
require('tables')
res = require('resources')
res_all_spells = res.spells:filter(function(s)
    return not s.unlearnable and not table.empty(s.levels) and not s.en:endswith('(UC)')
end):map(function(s)
    return {id=s.id, type=s.type, name=s.name}
end)

--Declare valid spell types
spell_type = {whm='WhiteMagic',blm='BlackMagic',smn='SummonerPact',nin='Ninjutsu',brd='BardSong',blu='BlueMagic',geo='Geomancy',tru='Trust'}

--Declare friendly name of spell types for chat output
display_spell_type = {whm='White Magic',blm='Black Magic',smn='Summoner',nin='Ninjutsu',brd='Bard',blu='Blue Magic',geo='Geomancy',tru='Trust'}
    
--Register the base //SpellCheck command
windower.register_event('addon command',function (command, ...)
    command = command and command:lower() or 'help'
    if command == 'help' or command == 'h' or command == '?' then
        display_help()
    elseif spell_type[command] == nil then
        display_help(command)
    else
        display_spell_count(command)
    end
end)

--Display a basic help section with optional command error
function display_help(command)
    windower.add_to_chat(7, _addon.name .. ' v.' .. _addon.version)
    if command then 
        windower.add_to_chat(7, 'Error: ' .. command .. ' is not a valid option.')
    end
    windower.add_to_chat(7, 'Usage: //spellcheck whm | blm | smn | nin | brd | blu | geo | tru')
    windower.add_to_chat(7, 'Sample: //spellcheck whm')
end

--Get spells
function display_spell_count(command)

    missing_spells
    
    --Get all, current and missing spells 
    all_spells = res_all_spells:type(spell_type[command]):keyset()
    current_spells = T(windower.ffxi.get_spells()):filter(true):keyset()   
    
    missing_spells = all_spells - current_spells
    missing_spells = res_all_spells:id(set.contains+{missing_spells})

    
    --Sort missing spells by name
    table.sort(missing_spell_names)
    
    --If there are missing spells, display that they are about to be listed
    if missing_spells_len > 0 then
        windower.add_to_chat(7, 'SpellCheck: Listing missing ' .. display_spell_type[command] .. ' spells...')
    end
    
    --List all missing spell names
    for i, spell in ipairs(missing_spell_names) do
      windower.add_to_chat(7, ' - Missing \'' .. spell .. '\'')
    end
    
    --Display summary
    windower.add_to_chat(7, 'SpellCheck: You are missing ' .. missing_spells_len .. ' ' .. display_spell_type[command] .. ' spells.')
end
