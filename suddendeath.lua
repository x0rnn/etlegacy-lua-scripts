-- x0rnn: added dynamite "sudden death" mode
-- modified Quake 3 sudden death sound: https://github.com/x0rnn/etpro/blob/master/lua/sudden_death.wav

---------------------------------
------- Dynamite counter --------
-------  By Necromancer  --------
-------    5/04/2009     --------
------- www.usef-et.org  --------
---------------------------------

SHOW = 0
-- 0 means disable timer
-- 1 means only the team that planted the dyno
-- 2 means everyone

-- This script can be freely used and modified as long as the original author/s are mentioned (and their homepage: www.usef-et.org)

mapname = ""
gametype = 0
gamestate = -1
maptime = 0
mapstarted = false
paused = false
mapstart_time = 0
paused_time = 0
unpaused_time = 0
stuck_time = 0
gameFrameLevelTime = 0
intervals = {[1]=0, [2]=0}
sudden_death = false
first_obj = false
first_obj_time = 0
second_obj_time = 0
first_obj_loc = "" 
second_obj_loc = ""
dyna_counter = 0
dyna_maps = {"battery", "sw_battery", "fueldump", "braundorf_b4", "etl_braundorf", "mp_sub_rc1", "sub2", "sw_oasis_b3", "oasis", "tc_base", "etl_base", "erdenberg_t2"}
plants = {}
defuses = {}
dyna_pos = {}

-- Constans
COLOR = {}
COLOR.PLACE = '^8'
COLOR.TEXT = '^w'
COLOR.TIME = '^8' -- this constant is changing in the print_message() function
 
CHAT = "bp" 
POPUP = "legacy"

timer = {}

function isEmpty(str)
	if str == nil or str == '' then
		return 0
	end
	return str
end

function roundNum(num, n) -- timelimit rounds to 6 decimals
	local mult = 10^(n or 0)
	return math.floor(num * mult + 0.5) / mult
end

function has_value (tab, val)
	for index, value in ipairs(tab) do
		if value == val then
			return true
		end
	end
	return false
end

function calcDist(pos1, pos2)
	local dist2 = (pos1[1]-pos2[1])^2 + (pos1[2]-pos2[2])^2 + ((pos1[3]-pos2[3])*2)^2
    return math.sqrt(dist2)
end

function et_InitGame(levelTime, randomSeed, restart)
    et.RegisterModname("suddendeath.lua" .. et.FindSelf())
	mapname = string.lower(et.trap_Cvar_Get("mapname"))
	gametype = tonumber(et.trap_Cvar_Get("g_gametype"))
	maptime = tonumber(et.trap_Cvar_Get("timelimit"))
	mapstart_time = et.trap_GetConfigstring(et.CS_LEVEL_START_TIME)
end

function et_RunFrame( levelTime )
	gamestate = tonumber(et.trap_Cvar_Get("gamestate"))
	if gametype == 3 then
		if gamestate == 0 then
			if mapstarted == false then
				mapstarted = true
				local winnerteam = tonumber(et.trap_Cvar_Get("sd_winnerteam")) or 1
				if has_value(dyna_maps, mapname) then
					if tonumber(et.trap_Cvar_Get("g_currentRound")) == 1 then -- round 2
						if winnerteam == 2 then -- 2 = allies, 1 = axis
							et.trap_Cvar_Set("timelimit", maptime - 0.5)
							maptime = tonumber(et.trap_Cvar_Get("timelimit"))
						else
							if et.trap_Cvar_Get("sd_bonustime") > et.trap_Cvar_Get("sd_defaulttime") then -- sudden death was activated, but dynamite defused in overtime
								et.trap_Cvar_Set("timelimit", et.trap_Cvar_Get("sd_defaulttime"))
								maptime = tonumber(et.trap_Cvar_Get("timelimit"))
							end
						end
					else
						et.trap_Cvar_Set("sd_defaulttime", maptime)
						et.trap_Cvar_Set("sd_bonustime", 0)
						et.trap_Cvar_Set("sd_winnerteam", 1)
					end
				end
			end
		end
	end
	gameFrameLevelTime = levelTime
	current = os.time()
	for dyno, temp in pairs(timer) do
		if timer[dyno]["time"] - current >= 0 then
			for key,temp in pairs(timer[dyno]) do
				if type(key) == "number" then
					if timer[dyno]["time"] - current == key then
						send_print(timer,dyno,key)
						timer[dyno][key] = nil	
						--et.G_LogPrint("dynamite key deleted: " .. dyno .." key: " .. key .. "\n")
					end
				end
			end

		else
			--et.G_LogPrint("dynamite out: " .. dyno .. "\n")
			place_destroyed(timer[dyno]["place"])
			--timer[dyno] = nil
		end
	end

	if math.fmod(levelTime, 1000) == 0 then
		if gamestate == 0 then
			if paused == true then
				local cs = et.trap_GetConfigstring(11)
				if intervals[1] == 0 then
					intervals[1] = cs
				elseif intervals[1] ~= 0 then
					if intervals[2] == 0 then
						intervals[2] = cs
					elseif intervals[2] ~= 0 then
						intervals[1] = intervals[2]
						intervals[2] = cs
						if intervals[1] == intervals[2] then
							paused = false
							unpaused_time = et.trap_Milliseconds() - 1000
							stuck_time = unpaused_time - paused_time + stuck_time
							intervals[1] = 0
							intervals[2] = 0
						end
					end
				end
			end
		
			if sudden_death == true then
				for i=0,tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
					local team = tonumber(et.gentity_get(i, "sess.sessionTeam"))
					if team == 2 then
						if et.gentity_get(i, "sess.PlayerType") == 2 then
							local health = tonumber(et.gentity_get(i, "health"))
							if health > 0 then
								local pos = et.gentity_get(i, "r.currentOrigin")
								local dist = calcDist(pos, dyna_pos)
								if dist < 600 then
									if et.gentity_get(i, "ps.ammoclip", 15) ~= 0 then
										et.gentity_set(i, "ps.ammoclip", 15, 0)
										et.RemoveWeaponFromPlayer(i, 15)
										--et.RemoveWeaponFromPlayer(i, 21)
									end
								else
									if et.gentity_get(i, "ps.ammoclip", 15) == 0 then
										et.gentity_set(i, "ps.ammoclip", 15, 1)
										et.AddWeaponToPlayer(i, 15, 1, 1, 0)
										--et.AddWeaponToPlayer(i, 21, 1, 1, 0)
									end
								end
							end
						end
					end
				end
			end

		elseif gamestate == et.GS_INTERMISSION then
			if gametype == 3 then
				local winnerteam = tonumber(isEmpty(et.Info_ValueForKey(et.trap_GetConfigstring(et.CS_MULTI_MAPWINNER), "w"))) + 1 -- change from scripting value for winner (0==AXIS, 1==ALLIES) to spawnflag value
				et.trap_Cvar_Set("sd_winnerteam", winnerteam)
			end
		end
	end
end

function et_WeaponFire(clientNum, weapon)
	if sudden_death == true then
		local team = tonumber(et.gentity_get(clientNum, "sess.sessionTeam"))
		if team == 2 then
			if et.gentity_get(clientNum, "sess.PlayerType") == 2 then
				local health = tonumber(et.gentity_get(clientNum, "health"))
				if health > 0 then
					local pos = et.gentity_get(clientNum, "r.currentOrigin")
					local dist = calcDist(pos, dyna_pos)
					if dist < 600 then
						if weapon == 21 then
							return 1
						end
					end
				end
			end
		end
	end
end

function et_ConsoleCommand()
	local arg = et.trap_Argv(1)
	if arg == "pause" then
		paused = true
		paused_time = et.trap_Milliseconds()
	end
	if arg == "unpause" then
		paused = false
		unpaused_time = et.trap_Milliseconds()
		stuck_time = unpaused_time - paused_time + stuck_time + 10000
	end
	return(0)
end

function place_destroyed(place) -- removes any dynamite timers that were planted on this objective
	for dynamite, temp in pairs(timer) do
		if timer[dynamite]["place"] == place then
			timer[dynamite] = nil
		end
	end
end

function send_print(timer,dyno,ttime)
	if SHOW == 0 then return end
	if SHOW == 1 then
		for player=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1, 1 do
			if et.gentity_get(player, "sess.sessionTeam") == timer[dyno]["team"] then
				print_message(player, ttime, timer[dyno]["place"])
			end
		end
	else
		print_message(-1, ttime, timer[dyno]["place"])
	end
end

function print_message(slot, ttime, place)
	if ttime > 3 then
		COLOR.TIME = '^8'
	else
		COLOR.TIME = '^1'
	end

	if ttime == -1 then
		et.trap_SendServerCommand( slot , string.format('%s \"%s"\n',CHAT, COLOR.TEXT .. "Dynamite planted at " .. COLOR.PLACE .. place))
	elseif ttime == -2 then
		et.trap_SendServerCommand( slot , string.format('%s \"%s"\n',CHAT, COLOR.TEXT .. "Dynamite defused at " .. COLOR.PLACE .. place))
	elseif ttime > 0 then
		et.trap_SendServerCommand( slot , string.format('%s \"%s"\n',CHAT, COLOR.TEXT .. "Dynamite at " .. COLOR.PLACE .. place .. COLOR.TEXT .. " exploding in " .. COLOR.TIME ..ttime .. COLOR.TEXT .. " seconds!"))
	end
end

function et_Print(text)
	if (string.find(text, "min Timebonus!") or string.find(text, "mins ^oTime Bonus!")) and not string.find(text, "say") then
		if sudden_death == true then
			sudden_death = false
			et.trap_Cvar_Set("timelimit", tonumber(et.trap_Cvar_Get("timelimit")) - 0.5)
		end
		maptime = tonumber(et.trap_Cvar_Get("timelimit"))
	end
	
	if string.find(text, "Dynamite_Plant") and not string.find(text, "say") then
		local junk1,junk2,id,loc = string.find(text, "^Dynamite_Plant:%s+(%d+)%s+([^\n]+)")
		table.insert(plants, {time=et.trap_Milliseconds(), name=et.gentity_get(id, "pers.netname"), location=loc, pos=et.gentity_get(id, "r.currentOrigin")})
	elseif string.find(text, "Dynamite_Diffuse") and not string.find(text, "say") then
		local junk1,junk2,id,loc = string.find(text, "^Dynamite_Diffuse:%s+(%d+)%s+([^\n]+)")
		table.insert(defuses, {time=et.trap_Milliseconds(), name=et.gentity_get(id, "pers.netname"), location=loc}) 
	end

	--legacy popup: axis planted "the Old City MG Nest"
	start,stop = string.find(text, POPUP .. " popup:",1,true) -- check that its not any player print, trying to manipulate the dyno counter
	if start and stop then
		start,stop,team,plant = string.find(text, POPUP .. " popup: (%S+) planted \"([^%\"]*)\"")
		if start and stop then -- dynamite planted
			local timestamp = et.trap_Milliseconds()
			if team == "axis" then team = 1 
			else team = 2 end
			index = #timer+1
			timer[index] = {}
			timer[index]["team"] = team
			timer[index]["place"] = plant
			timer[index]["time"] = os.time() +30

			timer[index][20] = true
			timer[index][10] = true
			timer[index][5] = true
			timer[index][3] = true
			timer[index][2] = true
			timer[index][1] = true
			timer[index][0] = true

			print_message(-1, -1, timer[index]["place"])
			--et.G_LogPrint("dynamite set: " .. index .. "\n")

			if mapname == "battery" or mapname == "sw_battery" or mapname == "fueldump" or mapname == "braundorf_b4" or mapname == "etl_braundorf" or mapname == "mp_sub_rc1" or mapname == "sub2" then
				if plant == "the Gun Controls" or plant == "the Fuel Dump" or plant == "the Bunker Controls" or plant == "the Axis Submarine" or plant == "the axis submarine" then
					local timelimit = tonumber(et.trap_Cvar_Get("timelimit")) * 1000 * 60 - 2000 --counts 2 seconds more for some reason...
					local timeleft = roundNum(timelimit - ((gameFrameLevelTime - stuck_time) - mapstart_time), 6)
					if timeleft < 30000 then
						if sudden_death == false then
							sudden_death = true
							for i, dyna in ipairs(plants) do
								if dyna.time >= timestamp - 5 and dyna.time <= timestamp then
									if plant == dyna.location then
										dyna_pos = dyna.pos
										break
									end
								end
							end
							et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death activated!\n")
							et.trap_SendServerCommand(-1, "chat \"^1Dynamite Sudden Death mode is activated!\"")
							et.trap_Cvar_Set("timelimit", tonumber(et.trap_Cvar_Get("timelimit")) + 0.5)
							et.G_globalSound("sound/misc/sudden_death.wav")
							for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
								local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
								if team == 2 then
									if et.gentity_get(j, "sess.PlayerType") == 2 then
										local health = tonumber(et.gentity_get(j, "health"))
										if health > 0 then
											local pos = et.gentity_get(j, "r.currentOrigin")
											local dist = calcDist(pos, dyna_pos)
											if dist < 600 then
												if et.gentity_get(j, "ps.ammoclip", 15) ~= 0 then
													et.gentity_set(j, "ps.ammoclip", 15, 0)
													et.RemoveWeaponFromPlayer(j, 15)
													--et.RemoveWeaponFromPlayer(j, 21)
												end
											else
												if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
													et.gentity_set(j, "ps.ammoclip", 15, 1)
													et.AddWeaponToPlayer(j, 15, 1, 1, 0)
													--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
												end
											end
											et.trap_SendServerCommand(j, "chat \"^1Sudden Death mode is activated! Can't plant additional dynamites!\"")
										end
									end
								end
							end
						end
					end
				end
			end
			if mapname == "sw_oasis_b3" or mapname == "oasis" or mapname == "tc_base" or mapname == "etl_base" or mapname == "erdenberg_t2" then
				if first_obj == true then
					if plant == "the South PAK 75mm Gun" or plant == "the North PAK 75mm Gun" or plant == "the South Anti-Tank Gun" or plant == "the North Anti-Tank Gun" or plant == "the West Flak88" or plant == "the East Flak88" or plant == "the South Radar [02]" or plant == "the North Radar [01]" or plant == "the South Radar" or plant == "the North Radar" then
						local timelimit = tonumber(et.trap_Cvar_Get("timelimit")) * 1000 * 60 - 2000 --counts 2 seconds more for some reason...
						local timeleft = roundNum(timelimit - ((gameFrameLevelTime - stuck_time) - mapstart_time), 6)
						if timeleft < 30000 then
							if sudden_death == false then
								sudden_death = true
								for i, dyna in ipairs(plants) do
									if dyna.time >= timestamp - 10 and dyna.time <= timestamp then
										if plant == dyna.location then
											dyna_pos = dyna.pos
											break
										end
									end
								end
								et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death activated!\n")
								et.trap_SendServerCommand(-1, "chat \"^1Dynamite Sudden Death mode is activated!\"")
								et.trap_Cvar_Set("timelimit", tonumber(et.trap_Cvar_Get("timelimit")) + 0.5)
								et.G_globalSound("sound/misc/sudden_death.wav")
								for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
									local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
									if team == 2 then
										if et.gentity_get(j, "sess.PlayerType") == 2 then
											local health = tonumber(et.gentity_get(j, "health"))
											if health > 0 then
												local pos = et.gentity_get(j, "r.currentOrigin")
												local dist = calcDist(pos, dyna_pos)
												if dist < 600 then
													if et.gentity_get(j, "ps.ammoclip", 15) ~= 0 then
														et.gentity_set(j, "ps.ammoclip", 15, 0)
														et.RemoveWeaponFromPlayer(j, 15)
														--et.RemoveWeaponFromPlayer(j, 21)
													end
												else
													if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
														et.gentity_set(j, "ps.ammoclip", 15, 1)
														et.AddWeaponToPlayer(j, 15, 1, 1, 0)
														--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
													end
												end
												et.trap_SendServerCommand(j, "chat \"^1Sudden Death mode is activated! Can't plant additional dynamites!\"")
											end
										end
									end
								end
							end
						end
					end
				else
					if plant == "the South PAK 75mm Gun" or plant == "the North PAK 75mm Gun" or plant == "the South Anti-Tank Gun" or plant == "the North Anti-Tank Gun" or plant == "the West Flak88" or plant == "the East Flak88" or plant == "the South Radar [02]" or plant == "the North Radar [01]" or plant == "the South Radar" or plant == "the North Radar" then
						local timelimit = tonumber(et.trap_Cvar_Get("timelimit")) * 1000 * 60 - 2000 --counts 2 seconds more for some reason...
						local timeleft = roundNum(timelimit - ((gameFrameLevelTime - stuck_time) - mapstart_time), 6)
						if timeleft < 60000 then
							if first_obj_time == 0 then
								first_obj_time = timestamp
								first_obj_loc = plant
								dyna_counter = dyna_counter + 1
							else
								if plant == first_obj_loc then
									dyna_counter = dyna_counter + 1
									first_obj_time = timestamp
								else
									second_obj_time = timestamp
									second_obj_loc = plant
									if timeleft < 30000 then
										if sudden_death == false then
											sudden_death = true
											for i, dyna in ipairs(plants) do
												if dyna.time >= timestamp - 10 and dyna.time <= timestamp then
													if plant == dyna.location then
														dyna_pos = dyna.pos
														break
													end
												end
											end
											et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death activated!\n")
											et.trap_SendServerCommand(-1, "chat \"^1Dynamite Sudden Death mode is activated!\"")
											et.trap_Cvar_Set("timelimit", tonumber(et.trap_Cvar_Get("timelimit")) + 0.5)
											et.G_globalSound("sound/misc/sudden_death.wav")
											for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
												local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
												if team == 2 then
													if et.gentity_get(j, "sess.PlayerType") == 2 then
														local health = tonumber(et.gentity_get(j, "health"))
														if health > 0 then
															local pos = et.gentity_get(j, "r.currentOrigin")
															local dist = calcDist(pos, dyna_pos)
															if dist < 600 then
																if et.gentity_get(j, "ps.ammoclip", 15) ~= 0 then
																	et.gentity_set(j, "ps.ammoclip", 15, 0)
																	et.RemoveWeaponFromPlayer(j, 15)
																	--et.RemoveWeaponFromPlayer(j, 21)
																end
															else
																if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
																	et.gentity_set(j, "ps.ammoclip", 15, 1)
																	et.AddWeaponToPlayer(j, 15, 1, 1, 0)
																	--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
																end
															end
															et.trap_SendServerCommand(j, "chat \"^1Dynamite Sudden Death mode is activated! Can't plant additional dynamites!\"")
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
			end
		end

		start,stop,team,plant = string.find(text, POPUP .. " popup: (%S+) defused \"([^%\"]*)\"")
		if start and stop then -- dynamite defused
			local timestamp = et.trap_Milliseconds()
			if team == "axis" then team = 1 
			else team = 2 end

			if mapname == "battery" or mapname == "sw_battery" or mapname == "fueldump" or mapname == "braundorf_b4" or mapname == "etl_braundorf" or mapname == "mp_sub_rc1" or mapname == "sub2" then
				if plant == "the Gun Controls" or plant == "the Fuel Dump" or plant == "the Bunker Controls" or plant == "the Axis Submarine" or plant == "the axis submarine" then
					if sudden_death == true then
						local timelimit = tonumber(et.trap_Cvar_Get("timelimit")) * 1000 * 60 - 2000 --counts 2 seconds more for some reason...
						local timeleft = roundNum(timelimit - ((gameFrameLevelTime - stuck_time) - mapstart_time), 6)
						if gametype == 4 or gametype == 6 then
							if (timelimit - 0.033333) - timeleft < (maptime * 1000 * 60) then
								sudden_death = false
								et.trap_Cvar_Set("timelimit", maptime)
								for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
									local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
									if team == 2 then
										if et.gentity_get(j, "sess.PlayerType") == 2 then
											local health = tonumber(et.gentity_get(j, "health"))
											if health > 0 then
												if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
													et.gentity_set(j, "ps.ammoclip", 15, 1)
													et.AddWeaponToPlayer(j, 15, 1, 1, 0)
													--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
												end
											end
										end
									end
								end
							elseif (timelimit - 0.033333) - timeleft >= (maptime * 1000 * 60) then
								et.trap_Cvar_Set("timelimit", 0.0001)
								et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death, Axis defused!\n")
								for i, dyna in ipairs(defuses) do
									if dyna.time == timestamp -1 then
										if plant == dyna.location then
											et.trap_SendServerCommand(-1, "chat \"" .. dyna.name .. " ^7defused ^1" .. plant .. "^7!\"")	
											break
										end
									end
								end
							end
						elseif gametype == 3 then
							if (timelimit - 0.033333) - timeleft < (maptime * 1000 * 60) then
								sudden_death = false
								et.trap_Cvar_Set("timelimit", maptime)
								for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
									local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
									if team == 2 then
										if et.gentity_get(j, "sess.PlayerType") == 2 then
											local health = tonumber(et.gentity_get(j, "health"))
											if health > 0 then
												if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
													et.gentity_set(j, "ps.ammoclip", 15, 1)
													et.AddWeaponToPlayer(j, 15, 1, 1, 0)
													--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
												end
											end
										end
									end
								end
							elseif (timelimit - 0.033333) - timeleft >= (maptime * 1000 * 60) then
								et.trap_Cvar_Set("sd_bonustime", roundNum(timelimit/1000/60 - timeleft/1000/60, 6))
								et.trap_Cvar_Set("timelimit", 0.0001)
								et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death, Axis defused!\n")
								for i, dyna in ipairs(defuses) do
									if dyna.time >= timestamp - 10 and dyna.time <= timestamp then
										if plant == dyna.location then
											et.trap_SendServerCommand(-1, "chat \"" .. dyna.name .. " ^7defused ^1" .. plant .. "^7!\"")
											break
										end
									end
								end
							end
						end
					end
				end
			end
			if mapname == "sw_oasis_b3" or mapname == "oasis" or mapname == "tc_base" or mapname == "etl_base" or mapname == "erdenberg_t2" then
				if plant == "the South PAK 75mm Gun" or plant == "the North PAK 75mm Gun" or plant == "the South Anti-Tank Gun" or plant == "the North Anti-Tank Gun" or plant == "the West Flak88" or plant == "the East Flak88" or plant == "the South Radar [02]" or plant == "the North Radar [01]" or plant == "the South Radar" or plant == "the North Radar" then
					if sudden_death == true then
						local timelimit = tonumber(et.trap_Cvar_Get("timelimit")) * 1000 * 60 - 2000 --counts 2 seconds more for some reason...
						local timeleft = roundNum(timelimit - ((gameFrameLevelTime - stuck_time) - mapstart_time), 6)
						if gametype == 4 or gametype == 6 then
							if (timelimit - 0.033333) - timeleft < (maptime * 1000 * 60) then
								if first_obj_loc == plant then
									dyna_counter = dyna_counter - 1
								end
								if dyna_counter == 0 or second_obj_loc == plant then
									if dyna_counter == 0 then
										first_obj_time = second_obj_time
										first_obj_loc = second_obj_loc
										second_obj_time = 0
										second_obj_loc = "" 
									elseif second_obj_loc == plant then
										second_obj_time = 0
										second_obj_loc = ""
									end
									sudden_death = false
									et.trap_Cvar_Set("timelimit", maptime)
									for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
										local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
										if team == 2 then
											if et.gentity_get(j, "sess.PlayerType") == 2 then
												local health = tonumber(et.gentity_get(j, "health"))
												if health > 0 then
													if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
														et.gentity_set(j, "ps.ammoclip", 15, 1)
														et.AddWeaponToPlayer(j, 15, 1, 1, 0)
														--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
													end
												end
											end
										end
									end
								end
							elseif (timelimit - 0.033333) - timeleft >= (maptime * 1000 * 60) then
								et.trap_Cvar_Set("timelimit", 0.0001)
								et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death, Axis defused!\n")
								for i, dyna in ipairs(defuses) do
									if dyna.time >= timestamp - 10 and dyna.time <= timestamp then
										if plant == dyna.location then
											et.trap_SendServerCommand(-1, "chat \"" .. dyna.name .. " ^7defused ^1" .. plant .. "^7!\"")	
											break
										end
									end
								end
							end
						elseif gametype == 3 then
							if (timelimit - 0.033333) - timeleft < (maptime * 1000 * 60) then
								if first_obj_loc == plant then
									dyna_counter = dyna_counter - 1
								end
								if dyna_counter == 0 or second_obj_loc == plant then
									if dyna_counter == 0 then
										first_obj_time = second_obj_time
										first_obj_loc = second_obj_loc
										second_obj_time = 0
										second_obj_loc = "" 
									elseif second_obj_loc == plant then
										second_obj_time = 0
										second_obj_loc = ""
									end
									sudden_death = false
									et.trap_Cvar_Set("timelimit", maptime)
									for j=0, tonumber(et.trap_Cvar_Get("sv_maxclients"))-1 do
										local team = tonumber(et.gentity_get(j, "sess.sessionTeam"))
										if team == 2 then
											if et.gentity_get(j, "sess.PlayerType") == 2 then
												local health = tonumber(et.gentity_get(j, "health"))
												if health > 0 then
													if et.gentity_get(j, "ps.ammoclip", 15) == 0 then
														et.gentity_set(j, "ps.ammoclip", 15, 1)
														et.AddWeaponToPlayer(j, 15, 1, 1, 0)
														--et.AddWeaponToPlayer(j, 21, 1, 1, 0)
													end
												end
											end
										end
									end
								end
							elseif (timelimit - 0.033333) - timeleft >= (maptime * 1000 * 60) then
								et.trap_Cvar_Set("sd_bonustime", roundNum(timelimit/1000/60 - timeleft/1000/60, 6))
								et.trap_Cvar_Set("timelimit", 0.0001)
								et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death, Axis defused!\n")
								for i, dyna in ipairs(defuses) do
									if dyna.time >= timestamp - 10 and dyna.time <= timestamp then
										if plant == dyna.location then
											et.trap_SendServerCommand(-1, "chat \"" .. dyna.name .. " ^7defused ^1" .. plant .. "^7!\"")	
											break
										end
									end
								end
							end
						end
					else
						if first_obj_loc == plant then
							dyna_counter = dyna_counter - 1
							if dyna_counter == 0 then
								first_obj_time = 0
								first_obj_loc = ""
							end
						end
					end
				end
			end

			for index,temp in pairs(timer) do
				if timer[index]["place"] == plant then
					print_message(-1, -2, timer[index]["place"])
					timer[index] = nil
					--et.G_LogPrint("dynamite removed: " .. index .. "\n")
					return
				end
			end
		end
	end

	if string.find(text, "Objective_Destroyed") and not string.find(text, "say") then
		local junk1,junk2,id,plant = string.find(text, "^Objective_Destroyed:%s+(%d+)%s+([^\n]+)")
		local name = et.gentity_get(id, "pers.netname")

		if plant == "the North Anti-Tank Gun" or plant == "the South Anti-Tank Gun" or plant == "the North PAK 75mm Gun" or plant == "the South PAK 75mm Gun" or plant == "the West Flak88" or plant == "the East Flak88" or plant == "the South Radar [02]" or plant == "the North Radar [01]" or plant == "the North Radar" or plant == "the South Radar" or plant == "the Gun Controls" or plant == "the Fuel Dump" or plant == "the Bunker Controls" or plant == "the Axis Submarine" or plant == "the axis submarine" then
			if mapname == "oasis" or mapname == "sw_oasis_b3" or mapname == "erdenberg_t2" or mapname == "tc_base" or mapname == "etl_base" then
				if first_obj == false then
					first_obj = true
				else
					if sudden_death == true then
						et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death, Allies win!\n")
					end
				end
				et.trap_SendServerCommand(-1, "chat \"" .. name .. " ^7destroyed ^1" .. plant .. "^7!\"")	
			else
				et.trap_SendServerCommand(-1, "chat \"" .. name .. " ^7destroyed ^1" .. plant .. "^7!\"")
				if sudden_death == true then
					et.G_LogPrint("LUA event: " .. mapname .. " Dynamite sudden death, Allies win!\n")
				end
			end
		end
	end
end
