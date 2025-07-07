// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

#include <..\engine.hpp>
#include <..\lang.hpp>

decl(string) TF_ADDON_VERSION = "TF RELICTA ADDON API 2.0";
//список языков
decl(string[]) vs_list_langs = [
	"human","eater","ghost","human_notongue","human_block"
];
//список кого слышат эти персонажи
//["eater",["eater","human"]] -> жруны слышат жрунов и людей
decl(map<string;string[]>) vs_map_whohear = createHashMapFromArray [
	["human",["human"]],
	["human_block",["human"]],
	["human_notongue",["human"]],
	["eater",["human"]],
	["ghost",["human"]]
];
if !isNull(relicta_global_textChatEnabled) then {
	//no hearing any
	{vs_map_whohear set [_x,[]]} foreach vs_map_whohear;
};