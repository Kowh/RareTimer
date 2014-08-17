-- Thanks to Leosky for the proper translations. The butchered ones are my own. :D

local Locale = "frFR"
local IsDefaultLocale = false
local L = Apollo.GetPackage("Gemini:Locale-1.0").tPackage:NewLocale("RareTimer", Locale, IsDefaultLocale)
if not L then return end

L["LocaleName"] = Locale

--Heading strings
L["CmdListHeading"] = "RareTimer registre d'�tat:" 
L["AlertHeading"] = "Alerte de RareTimer:"
L["Name"] = "Nom"
L["Status"] = "Condition"
L["Last kill"] = "Tu�"
L["Health"] = "Vie"

--Option strings
L["OptTargetTimeout"] = "N'alerter pas apr�s avoir cibl� (minutes)"
L["OptTargetTimeoutDesc"] = "N'alerter pas si on a cibl� l'ennemi dans le d�lai."
L["OptPlaySound"] = "Faire sonner"
L["OptPlaySoundDesc"] = "Faire sonner lorsque l'alerte est d�clencher."

--Time strings
L["s"] = "s" -- Seconds
L["m"] = "m" -- Minutes
L["h"] = "h" -- Hours
L["d"] = "j" -- Days

-- State strings
L["StateUnknown"] = 'Inconnu'
L["StateKilled"] = 'Tu� � %s'
L["StateDead"] = 'Tu� au plus tard � %s'
L["StatePending"] = 'Devrait reparaitre avant %s'
L["StateAlive"] = 'En vie (%s)'
L["StateInCombat"] = 'En combat'
L["StateExpired"] = 'Inconnu (vu la derni�re fois � %s)'
 
-- Mob names
L["Scorchwing"] = 'Ailardente'

