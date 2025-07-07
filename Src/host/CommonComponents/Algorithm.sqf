// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

#include <..\engine.hpp>
#include <..\lang.hpp>

//algorithm helpers namespace not set to avoid renaming; just annotate

decl(bool(any[])) allOf = {
	params ["_list"];
	!(false in _list)
};

decl(bool(any[])) anyOf = {
	params ["_list"];
	true in _list
};

decl(bool(any[])) noneOf = {
	params ["_list"];
	!(true in _list)
};