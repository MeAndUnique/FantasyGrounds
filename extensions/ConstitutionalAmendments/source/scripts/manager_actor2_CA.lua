-- 
-- Please see the license.html file included with this distribution for 
-- attribution and copyright information.
--

function getPercentWounded(rActor)
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);

	if sActorType == "pc" then
		return getPercentWounded2("pc", nodeActor);
	elseif sActorType == "ct" then
		return getPercentWounded2("ct", nodeActor);
	end
	
	return 0, "";
end

function getPercentWounded2(sNodeType, node)
	local nHP, nWounds, nDeathSaveFail;
	if sNodeType == "pc" then
		nHP = math.max(DB.getValue(node, "hp.total", 0), 0);
		nWounds = math.max(DB.getValue(node, "hp.wounds", 0), 0);
		nDeathSaveFail = DB.getValue(node, "hp.deathsavefail", 0);
	elseif sNodeType == "ct" then
		nHP = math.max(DB.getValue(node, "hptotal", 0), 0);
		nWounds = math.max(DB.getValue(node, "wounds", 0), 0);
		nDeathSaveFail = DB.getValue(node, "deathsavefail", 0);
	end
	
	local nPercentWounded = 0;
	if nHP > 0 then
		nPercentWounded = nWounds / nHP;
	end
	
	local sStatus;
	if nPercentWounded >= 1 then
		if nDeathSaveFail >= 3 then
			sStatus = "Dead";
		else
			local rActor;
			if sNodeType == "pc" then
				rActor = ActorManager.getActor("pc", node);
			elseif sNodeType == "ct" then
				rActor = ActorManager.getActor("ct", node);
			end
			if EffectManager5E.hasEffect(rActor, "Stable") then
				sStatus = "Unconscious";
			else
				sStatus = "Dying";
			end
			if nDeathSaveFail > 0 then
				sStatus = sStatus .. " (" .. nDeathSaveFail .. ")";
			end
		end
	elseif OptionsManager.isOption("WNDC", "detailed") then
		if nPercentWounded >= .75 then
			sStatus = "Critical";
		elseif nPercentWounded >= .5 then
			sStatus = "Heavy";
		elseif nPercentWounded >= .25 then
			sStatus = "Moderate";
		elseif nPercentWounded > 0 then
			sStatus = "Light";
		else
			sStatus = "Healthy";
		end
	else
		if nPercentWounded >= .5 then
			sStatus = "Heavy";
		elseif nPercentWounded > 0 then
			sStatus = "Wounded";
		else
			sStatus = "Healthy";
		end
	end
	
	return nPercentWounded, sStatus;
end

-- Based on the percent wounded, change the font color for the Wounds field
function getWoundColor(sNodeType, node)
	local nPercentWounded, sStatus = getPercentWounded2(sNodeType, node);
	
	local sColor = ColorManager.getHealthColor(nPercentWounded, false);

	return sColor, nPercentWounded, sStatus;
end

-- Based on the percent wounded, change the token health bar color
function getWoundBarColor(sNodeType, node)
	local nPercentWounded, sStatus = getPercentWounded2(sNodeType, node);
	
	local sColor = ColorManager.getTokenHealthColor(nPercentWounded, true);

	return sColor, nPercentWounded, sStatus;
end

function getAbilityEffectsBonus(rActor, sAbility)
	if not rActor or not sAbility then
		return 0, 0;
	end
	
	local sAbilityEffect = DataCommon.ability_ltos[sAbility];
	if not sAbilityEffect then
		return 0, 0;
	end
	
	-- this is modified to not re-enable skipped effects	
	local nAbilityMod, nAbilityEffects = EffectManager5ECA.getEffectsBonus(rActor, sAbilityEffect, true);
	
	local nAbilityScore = getAbilityScore(rActor, sAbility);
	if nAbilityScore > 0 then
		local nAffectedScore = math.max(nAbilityScore + nAbilityMod, 0);
		
		local nCurrentBonus = math.floor((nAbilityScore - 10) / 2);
		local nAffectedBonus = math.floor((nAffectedScore - 10) / 2);
		
		nAbilityMod = nAffectedBonus - nCurrentBonus;
	else
		if nAbilityMod > 0 then
			nAbilityMod = math.floor(nAbilityMod / 2);
		else
			nAbilityMod = math.ceil(nAbilityMod / 2);
		end
	end

	return nAbilityMod, nAbilityEffects;
end

function getClassLevel(nodeActor, sValue)
	local sClassName = DataCommon.class_valuetoname[sValue];
	if not sClassName then
		return 0;
	end
	sClassName = sClassName:lower();
	
	for _, vNode in pairs(DB.getChildren(nodeActor, "classes")) do
		if DB.getValue(vNode, "name", ""):lower() == sClassName then
			return DB.getValue(vNode, "level", 0);
		end
	end
	
	return 0;
end

function getAbilityScore(rActor, sAbility)
	if not sAbility then
		return -1;
	end
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if not nodeActor then
		return -1;
	end
	
	local nStatScore = -1;
	
	local sShort = string.sub(string.lower(sAbility), 1, 3);
	if sShort == "lev" then
		if sActorType == "pc" then
			nStatScore = DB.getValue(nodeActor, "level", 0);
		else
			local sHD = StringManager.trim(DB.getValue(nodeActor, "hd", ""));
			nStatScore = 0;
			for sLevelSub in sHD:gmatch("(%d+)[dD](%d+)") do
				nStatScore = nStatScore + (tonumber(sLevelSub) or 0);
			end
		end
	elseif sShort == "prf" then
		if sActorType == "pc" then
			nStatScore = DB.getValue(nodeActor, "profbonus", 0);
		else
			local nCR = tonumber(DB.getValue(nodeActor, "cr", ""):match("^%d+$")) or 0;
			nStatScore = math.max(2, math.floor((nCR - 1) / 4) + 2);
		end
	elseif sShort == "str" then
		nStatScore = DB.getValue(nodeActor, "abilities.strength.score", 0);
	elseif sShort == "dex" then
		nStatScore = DB.getValue(nodeActor, "abilities.dexterity.score", 0);
	elseif sShort == "con" then
		nStatScore = DB.getValue(nodeActor, "abilities.constitution.score", 0);
	elseif sShort == "int" then
		nStatScore = DB.getValue(nodeActor, "abilities.intelligence.score", 0);
	elseif sShort == "wis" then
		nStatScore = DB.getValue(nodeActor, "abilities.wisdom.score", 0);
	elseif sShort == "cha" then
		nStatScore = DB.getValue(nodeActor, "abilities.charisma.score", 0);
	elseif StringManager.contains(DataCommon.classes, sAbility) then
		nStatScore = getClassLevel(nodeActor, sAbility);
	end
	
	return nStatScore;
end

function getAbilityBonus(rActor, sAbility)
	if not sAbility then
		return 0;
	end
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if not nodeActor then
		return 0;
	end
	
	local nStatScore = getAbilityScore(rActor, sAbility);
	if nStatScore < 0 then
		return 0;
	end
	
	local nStatVal = 0;
	if StringManager.contains(DataCommon.abilities, sAbility) then
		nStatVal = math.floor((nStatScore - 10) / 2);
	else
		nStatVal = nStatScore;
	end
	
	return nStatVal;
end

function getSave(rActor, sSave)
	local bADV = false;
	local bDIS = false;
	local nValue = getAbilityBonus(rActor, sSave);
	local aAddText = {};
	
	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if sActorType == "pc" then
		nValue = nValue + DB.getValue(nodeActor, "abilities." .. sSave .. ".savemodifier", 0);

		-- Check for saving throw proficiency
		if DB.getValue(nodeActor, "abilities." .. sSave .. ".saveprof", 0) == 1 then
			nValue = nValue + DB.getValue(nodeActor, "profbonus", 0);
		end

		-- Check for armor non-proficiency
		if StringManager.contains({"strength", "dexterity"}, sSave) then
			if DB.getValue(nodeActor, "defenses.ac.prof", 1) == 0 then
				table.insert(aAddText, Interface.getString("roll_msg_armor_nonprof"));
				bDIS = true;
			end
		end
	else
		local sSaves = DB.getValue(nodeActor, "savingthrows", "");
		for _,v in ipairs(StringManager.split(sSaves, ",;\r", true)) do
			local sAbility, sSign, sMod = string.match(v, "(%w+)%s*([%+%-–]?)(%d+)");
			if sAbility then
				if DataCommon.ability_stol[sAbility:upper()] then
					sAbility = DataCommon.ability_stol[sAbility:upper()];
				elseif DataCommon.ability_ltos[sAbility:lower()] then
					sAbility = sAbility:lower();
				else
					sAbility = nil;
				end
				
				if sAbility == sSave then
					nValue = tonumber(sMod) or 0;
					if sSign == "-" or sSign == "–" then
						nValue = 0 - nValue;
					end
					break;
				end
			end
		end
	end
	
	return nValue, bADV, bDIS, table.concat(aAddText, " ");
end

function getCheck(rActor, sCheck, sSkill)
	local bADV = false;
	local bDIS = false;
	local nValue = getAbilityBonus(rActor, sCheck);
	local aAddText = {};

	local sActorType, nodeActor = ActorManager.getTypeAndNode(rActor);
	if sActorType == "pc" then
		nValue = nValue + DB.getValue(nodeActor, "abilities." .. sCheck .. ".checkmodifier", 0);

		-- Check for armor non-proficiency
		if StringManager.contains({"strength", "dexterity"}, sCheck) then
			if DB.getValue(nodeActor, "defenses.ac.prof", 1) == 0 then
				table.insert(aAddText, Interface.getString("roll_msg_armor_nonprof"));
				bDIS = true;
			end
		end
		
		-- Check for armor stealth disadvantage
		if sSkill and sSkill:lower() == Interface.getString("skill_value_stealth"):lower() then
			if DB.getValue(nodeActor, "defenses.ac.disstealth", 0) == 1 then
				table.insert(aAddText, Interface.getString("roll_msg_armor_disstealth"));
				bDIS = true;
			end
		end
	end
	
	return nValue, bADV, bDIS, table.concat(aAddText, " ");
end

function getDefenseAdvantage(rAttacker, rDefender, aAttackFilter)
	if not rDefender then
		return false, false;
	end
	
	-- Check effects
	local bADV = false;
	local bDIS = false;
	local bProne = false;
	
	if ActorManager.hasCT(rDefender) then
		if EffectManager5E.hasEffect(rAttacker, "ADVATK", rDefender, true) then
			bADV = true;
		elseif #(EffectManager5E.getEffectsByType(rAttacker, "ADVATK", aAttackFilter, rDefender, true)) > 0 then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rAttacker, "DISATK", rDefender, true) then
			bDIS = true;
		elseif #(EffectManager5E.getEffectsByType(rAttacker, "DISATK", aAttackFilter, rDefender, true)) > 0 then
			bDIS = true;
		end
		if EffectManager5E.hasEffect(rAttacker, "Invisible", rDefender, true) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "GRANTADVATK", rAttacker) then
			bADV = true;
		elseif #(EffectManager5E.getEffectsByType(rDefender, "GRANTADVATK", aAttackFilter, rAttacker)) > 0 then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "GRANTDISATK", rAttacker) then
			bDIS = true;
		elseif #(EffectManager5E.getEffectsByType(rDefender, "GRANTDISATK", aAttackFilter, rAttacker)) > 0 then
			bDIS = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Blinded", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Invisible", rAttacker) then
			bDIS = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Paralyzed", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Prone", rAttacker) then
			bProne = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Restrained", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Stunned", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Unconscious", rAttacker) then
			bADV = true;
			bProne = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Dodge", rAttacker) and 
				not (EffectManager5E.hasEffect(rDefender, "Paralyzed", rAttacker) or
				EffectManager5E.hasEffect(rDefender, "Stunned", rAttacker) or
				EffectManager5E.hasEffect(rDefender, "Incapacitated", rAttacker) or
				EffectManager5E.hasEffect(rDefender, "Unconscious", rAttacker) or
				EffectManager5E.hasEffect(rDefender, "Grappled", rAttacker) or
				EffectManager5E.hasEffect(rDefender, "Restrained", rAttacker)) then
			bDIS = true;
		end
		
		if bProne then
			if StringManager.contains(aAttackFilter, "melee") then
				bADV = true;
			elseif StringManager.contains(aAttackFilter, "ranged") then
				bDIS = true;
			end
		end
	end
	-- if bProne then
		-- local nodeAttacker = ActorManager.getCTNode(rAttacker);
		-- local nodeDefender = ActorManager.getCTNode(rDefender);
		-- if nodeAttacker and nodeDefender then
			-- local tokenAttacker = CombatManager.getTokenFromCT(nodeAttacker);
			-- local tokenDefender = CombatManager.getTokenFromCT(nodeDefender);
			-- if tokenAttacker and tokenDefender then
				-- local nodeAttackerContainer = tokenAttacker.getContainerNode();
				-- local nodeDefenderContainer = tokenDefender.getContainerNode();
				-- if nodeAttackerContainer.getNodeName() == nodeDefenderContainer.getNodeName() then
					-- local nDU = GameSystem.getDistanceUnitsPerGrid();
					-- local nAttackerSpace = math.ceil(DB.getValue(nodeAttacker, "space", nDU) / nDU);
					-- local nDefenderSpace = math.ceil(DB.getValue(nodeDefender, "space", nDU) / nDU);
					-- local xAttacker, yAttacker = tokenAttacker.getPosition();
					-- local xDefender, yDefender = tokenDefender.getPosition();
					-- local nGrid = nodeAttackerContainer.getGridSize();
					
					-- local xDiff = math.abs(xAttacker - xDefender);
					-- local yDiff = math.abs(yAttacker - yDefender);
					-- local gx = math.floor(xDiff / nGrid);
					-- local gy = math.floor(yDiff / nGrid);
					
					-- local nSquares = 0;
					-- local nStraights = 0;
					-- if gx > gy then
						-- nSquares = nSquares + gy;
						-- nSquares = nSquares + gx - gy;
					-- else
						-- nSquares = nSquares + gx;
						-- nSquares = nSquares + gy - gx;
					-- end
					-- nSquares = nSquares - (nAttackerSpace / 2);
					-- nSquares = nSquares - (nDefenderSpace / 2);
					-- -- DEBUG - FINISH - Need to be able to get grid type and grid size from token container node
				-- end
			-- end
		-- end
	-- end

	return bADV, bDIS;
end

function getDefenseValue(rAttacker, rDefender, rRoll)
	if not rDefender or not rRoll then
		return nil, 0, 0, false, false;
	end
	
	-- Base calculations
	local sAttack = rRoll.sDesc;
	
	local sAttackType = string.match(sAttack, "%[ATTACK.*%((%w+)%)%]");
	local bOpportunity = string.match(sAttack, "%[OPPORTUNITY%]");
	local nCover = tonumber(string.match(sAttack, "%[COVER %-(%d)%]")) or 0;

	local nDefense = 10;
	local sDefenseStat = "dexterity";

	local sDefenderType, nodeDefender = ActorManager.getTypeAndNode(rDefender);
	if not nodeDefender then
		return nil, 0, 0, false, false;
	end

	if sDefenderType == "pc" then
		nDefense = DB.getValue(nodeDefender, "defenses.ac.total", 10);
		sDefenseStat = DB.getValue(nodeDefender, "ac.sources.ability", "");
		if sDefenseStat == "" then
			sDefenseStat = "dexterity";
		end
	else
		nDefense = DB.getValue(nodeDefender, "ac", 10);
	end
	nDefenseStatMod = getAbilityBonus(rDefender, sDefenseStat);
	
	-- Effects
	local nAttackEffectMod = 0;
	local nDefenseEffectMod = 0;
	local bADV = false;
	local bDIS = false;
	if ActorManager.hasCT(rDefender) then
		local nBonusAC = 0;
		local nBonusStat = 0;
		local nBonusSituational = 0;
		
		local aAttackFilter = {};
		if sAttackType == "M" then
			table.insert(aAttackFilter, "melee");
		elseif sAttackType == "R" then
			table.insert(aAttackFilter, "ranged");
		end
		if bOpportunity then
			table.insert(aAttackFilter, "opportunity");
		end

		local aBonusTargetedAttackDice, nBonusTargetedAttack = EffectManager5E.getEffectsBonus(rAttacker, "ATK", false, aAttackFilter, rDefender, true);
		nAttackEffectMod = nAttackEffectMod + StringManager.evalDice(aBonusTargetedAttackDice, nBonusTargetedAttack);
					
		local aACEffects, nACEffectCount = EffectManager5E.getEffectsBonusByType(rDefender, {"AC"}, true, aAttackFilter, rAttacker);
		for _,v in pairs(aACEffects) do
			nBonusAC = nBonusAC + v.mod;
		end
		
		nBonusStat = getAbilityEffectsBonus(rDefender, sDefenseStat);
		if sDefenderType == "pc" and (nBonusStat > 0) then
			local sMaxDexBonus = DB.getValue(nodeDefender, "defenses.ac.dexbonus", "");
			if sMaxDexBonus == "no" then
				nBonusStat = 0;
			elseif sMaxDexBonus == "max2" then
				local nMaxEffectStatModBonus = math.max(2 - nDefenseStatMod, 0);
				if nBonusStat > nMaxEffectStatModBonus then 
					nBonusStat = nMaxEffectStatModBonus; 
				end
			elseif sMaxDexBonus == "max3" then
				local nMaxEffectStatModBonus = math.max(3 - nDefenseStatMod, 0);
				if nBonusStat > nMaxEffectStatModBonus then 
					nBonusStat = nMaxEffectStatModBonus; 
				end
			end
		end
		
		local bProne = false;
		if EffectManager5E.hasEffect(rAttacker, "ADVATK", rDefender, true) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rAttacker, "DISATK", rDefender, true) then
			bDIS = true;
		end
		if EffectManager5E.hasEffect(rAttacker, "Invisible", rDefender, true) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "GRANTADVATK", rAtracker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "GRANTDISATK", rAtracker) then
			bDIS = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Invisible", rAttacker) then
			bDIS = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Paralyzed", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Prone", rAttacker) then
			bProne = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Restrained", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Stunned", rAttacker) then
			bADV = true;
		end
		if EffectManager5E.hasEffect(rDefender, "Unconscious", rAttacker) then
			bADV = true;
			bProne = true;
		end
		
		if bProne then
			if sAttackType == "M" then
				bADV = true;
			elseif sAttackType == "R" then
				bDIS = true;
			end
		end
		
		if nCover < 5 then
			local aCover = EffectManager5E.getEffectsByType(rDefender, "SCOVER", aAttackFilter, rAttacker);
			if #aCover > 0 or EffectManager5E.hasEffect(rDefender, "SCOVER", rAttacker) then
				nBonusSituational = nBonusSituational + 5 - nCover;
			elseif nCover < 2 then
				aCover = EffectManager5E.getEffectsByType(rDefender, "COVER", aAttackFilter, rAttacker);
				if #aCover > 0 or EffectManager5E.hasEffect(rDefender, "COVER", rAttacker) then
					nBonusSituational = nBonusSituational + 2 - nCover;
				end
			end
		end
		
		nDefenseEffectMod = nBonusAC + nBonusStat + nBonusSituational;
	end
	
	-- Results
	return nDefense, nAttackEffectMod, nDefenseEffectMod, bADV, bDIS;
end

function isAlignment(rActor, sAlignCheck)
	local nCheckLawChaosAxis = 0;
	local nCheckGoodEvilAxis = 0;
	local aCheckSplit = StringManager.split(sAlignCheck:lower(), " ", true);
	for _,v in ipairs(aCheckSplit) do
		if nCheckLawChaosAxis == 0 and DataCommon.alignment_lawchaos[v] then
			nCheckLawChaosAxis = DataCommon.alignment_lawchaos[v];
		end
		if nCheckGoodEvilAxis == 0 and DataCommon.alignment_goodevil[v] then
			nCheckGoodEvilAxis = DataCommon.alignment_goodevil[v];
		end
	end
	if nCheckLawChaosAxis == 0 and nCheckGoodEvilAxis == 0 then
		return false;
	end
	
	local nActorLawChaosAxis = 2;
	local nActorGoodEvilAxis = 2;
	local sType, nodeActor = ActorManager.getTypeAndNode(rActor);
	local sField = "alignment";
	local aActorSplit = StringManager.split(DB.getValue(nodeActor, sField, ""):lower(), " ", true);
	for _,v in ipairs(aActorSplit) do
		if nActorLawChaosAxis == 2 and DataCommon.alignment_lawchaos[v] then
			nActorLawChaosAxis = DataCommon.alignment_lawchaos[v];
		end
		if nActorGoodEvilAxis == 2 and DataCommon.alignment_goodevil[v] then
			nActorGoodEvilAxis = DataCommon.alignment_goodevil[v];
		end
	end
	
	local bLCReturn = true;
	if nCheckLawChaosAxis > 0 then
		if nActorLawChaosAxis > 0 then
			bLCReturn = (nActorLawChaosAxis == nCheckLawChaosAxis);
		else
			bLCReturn = false;
		end
	end
	
	local bGEReturn = true;
	if nCheckGoodEvilAxis > 0 then
		if nActorGoodEvilAxis > 0 then
			bGEReturn = (nActorGoodEvilAxis == nCheckGoodEvilAxis);
		else
			bGEReturn = false;
		end
	end
	
	return (bLCReturn and bGEReturn);
end

function isSize(rActor, sSizeCheck)
	local sSizeCheckLower = StringManager.trim(sSizeCheck:lower());

	local sCheckOp = sSizeCheckLower:match("^[<>]?=?");
	if sCheckOp then
		sSizeCheckLower = StringManager.trim(sSizeCheckLower:sub(#sCheckOp + 1));
	end
	
	local nCheckSize = 0;
	if DataCommon.creaturesize[sSizeCheckLower] then
		nCheckSize = DataCommon.creaturesize[sSizeCheckLower];
	end
	if nCheckSize == 0 then
		return false;
	end
	
	local nActorSize = 0;
	local sType, nodeActor = ActorManager.getTypeAndNode(rActor);
	local sField = "size";
	local aActorSplit = StringManager.split(DB.getValue(nodeActor, sField, ""):lower(), " ", true);
	for _,v in ipairs(aActorSplit) do
		if nActorSize == 0 and DataCommon.creaturesize[v] then
			nActorSize = DataCommon.creaturesize[v];
			break;
		end
	end
	if nActorSize == 0 then
		nActorSize = 3;
	end
	
	local bReturn = true;
	if sCheckOp then
		if sCheckOp == "<" then
			bReturn = (nActorSize < nCheckSize);
		elseif sCheckOp == ">" then
			bReturn = (nActorSize > nCheckSize);
		elseif sCheckOp == "<=" then
			bReturn = (nActorSize <= nCheckSize);
		elseif sCheckOp == ">=" then
			bReturn = (nActorSize >= nCheckSize);
		else
			bReturn = (nActorSize == nCheckSize);
		end
	else
		bReturn = (nActorSize == nCheckSize);
	end
	
	return bReturn;
end

function getCreatureTypeHelper(sTypeCheck, bUseDefaultType)
	local aCheckSplit = StringManager.split(sTypeCheck:lower(), ", %(%)", true);
	
	local aTypeCheck = {};
	local aSubTypeCheck = {};
	
	-- Handle half races
	local nHalfRace = 0;
	for k = 1, #aCheckSplit do
		if aCheckSplit[k]:sub(1, #DataCommon.creaturehalftype) == DataCommon.creaturehalftype then
			aCheckSplit[k] = aCheckSplit[k]:sub(#DataCommon.creaturehalftype + 1);
			nHalfRace = nHalfRace + 1;
		end
	end
	if nHalfRace == 1 then
		if not StringManager.contains (aCheckSplit, DataCommon.creaturehalftypesubrace) then
			table.insert(aCheckSplit, DataCommon.creaturehalftypesubrace);
		end
	end
	
	-- Check each word combo in the creature type string against standard creature types and subtypes
	for k = 1, #aCheckSplit do
		for _,sMainType in ipairs(DataCommon.creaturetype) do
			local aMainTypeSplit = StringManager.split(sMainType, " ", true);
			if #aMainTypeSplit > 0 then
				local bMatch = true;
				for i = 1, #aMainTypeSplit do
					if aMainTypeSplit[i] ~= aCheckSplit[k - 1 + i] then
						bMatch = false;
						break;
					end
				end
				if bMatch then
					table.insert(aTypeCheck, sMainType);
					k = k + (#aMainTypeSplit - 1);
				end
			end
		end
		for _,sSubType in ipairs(DataCommon.creaturesubtype) do
			local aSubTypeSplit = StringManager.split(sSubType, " ", true);
			if #aSubTypeSplit > 0 then
				local bMatch = true;
				for i = 1, #aSubTypeSplit do
					if aSubTypeSplit[i] ~= aCheckSplit[k - 1 + i] then
						bMatch = false;
						break;
					end
				end
				if bMatch then
					table.insert(aSubTypeCheck, sSubType);
					k = k + (#aSubTypeSplit - 1);
				end
			end
		end
	end
	
	-- Make sure we have a default creature type (if requested)
	if bUseDefaultType then
		if #aTypeCheck == 0 then
			table.insert(aTypeCheck, DataCommon.creaturedefaulttype);
		end
	end
	
	-- Combine into a single list
	for _,vSubType in ipairs(aSubTypeCheck) do
		table.insert(aTypeCheck, vSubType);
	end
	
	return aTypeCheck;
end

function isCreatureType(rActor, sTypeCheck)
	local aTypeCheck = getCreatureTypeHelper(sTypeCheck, false);
	if #aTypeCheck == 0 then
		return false;
	end
	
	local sType, nodeActor = ActorManager.getTypeAndNode(rActor);
	local sField = "race";
	if sType ~= "pc" then
		sField = "type";
	end
	local aTypeActor = getCreatureTypeHelper(DB.getValue(nodeActor, sField, ""), true);

	for _,vCheck in ipairs(aTypeCheck) do
		if StringManager.contains(aTypeActor, vCheck) then
			return true;
		end
	end
	return false;
end
