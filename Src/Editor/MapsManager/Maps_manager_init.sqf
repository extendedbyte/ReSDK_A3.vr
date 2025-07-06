// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

// Основные настройки менеджера карт
mm_use_alg2_vdir_check = true; // дополнительная валидация сериализации поворота/трансформации объекта

mm_folderSaveMaps = "Maps";
mm_internal_defaultMapExt = ".sqf";

// Подключаем модули менеджера карт
#include "Maps_manager_common.sqf"
#include "Maps_manager_importOld.sqf"
#include "Maps_manager_virtualMap.sqf"
#include "Maps_manager_batchProcessor.sqf"

/*
	Инициализация менеджера карт
*/
function(mm_init)
{
	["Инициализация менеджера карт"] call printLog;
	
	// Проверяем существование папки для сохранения карт
	if !([mm_folderSaveMaps] call file_folderExists) then {
		["Создание папки для сохранения карт: %1", mm_folderSaveMaps] call printLog;
		[mm_folderSaveMaps] call file_createFolder;
	};
	
	// Инициализируем переменные виртуального сборщика
	mm_virt_errorCount = 0;
	mm_virt_errorText = "";
	mm_virt_currentMapData = createHashMap;
	
	// Инициализируем переменные пакетного процессора
	mm_batch_currentMapIndex = 0;
	mm_batch_totalMaps = 0;
	mm_batch_processedMaps = [];
	mm_batch_failedMaps = [];
	mm_batch_isRunning = false;
	
	["Менеджер карт инициализирован"] call printLog;
};

/*
	Расширенное меню сборки карт
*/
function(mm_showBuildMenu)
{
	private _menuItems = [
		["Обычная сборка", { [] call mm_build }],
		["Виртуальная сборка текущей карты", { 
			private _mapName = "missionName" call golib_getCommonStorageParam;
			[_mapName, []] call mm_virt_build;
		}],
		["Валидация текущей карты", {
			private _mapName = "missionName" call golib_getCommonStorageParam;
			[_mapName, ["validate-only"]] call mm_virt_build;
		}],
		["---", {}],
		["Пакетная обработка всех карт", { [] call mm_batch_buildAllMaps }],
		["Валидация всех карт", { [] call mm_batch_validateAllMaps }],
		["Миграция всех карт", { [] call mm_batch_migrateAllMaps }],
		["---", {}],
		["Статус пакетной обработки", { [] call mm_batch_getStatus }],
		["Остановить пакетную обработку", { [] call mm_batch_stop }]
	];
	
	[_menuItems, "Меню сборки карт"] call control_createMenu;
};

/*
	Команды для консоли разработчика
*/
function(mm_registerConsoleCommands)
{
	// Виртуальная сборка
	registerConsoleCommand("vbuild", {
		params [["_mapName", ""], ["_options", []]];
		if (_mapName == "") then {
			_mapName = "missionName" call golib_getCommonStorageParam;
		};
		[_mapName, _options] call mm_virt_build;
	}, "Виртуальная сборка карты. Использование: vbuild [имя_карты] [опции]");
	
	// Валидация карты
	registerConsoleCommand("validate", {
		params [["_mapName", ""]];
		if (_mapName == "") then {
			_mapName = "missionName" call golib_getCommonStorageParam;
		};
		[_mapName, ["validate-only"]] call mm_virt_build;
	}, "Валидация карты. Использование: validate [имя_карты]");
	
	// Пакетная обработка
	registerConsoleCommand("batch_build", {
		params [["_options", []]];
		[_options] call mm_batch_buildAllMaps;
	}, "Пакетная сборка всех карт. Использование: batch_build [опции]");
	
	registerConsoleCommand("batch_validate", {
		[] call mm_batch_validateAllMaps;
	}, "Валидация всех карт");
	
	registerConsoleCommand("batch_migrate", {
		[] call mm_batch_migrateAllMaps;
	}, "Миграция всех карт");
	
	registerConsoleCommand("batch_status", {
		[] call mm_batch_getStatus;
	}, "Статус пакетной обработки");
	
	registerConsoleCommand("batch_stop", {
		[] call mm_batch_stop;
	}, "Остановка пакетной обработки");
	
	["Зарегистрированы консольные команды для менеджера карт"] call printTrace;
};

// Автоматическая инициализация при загрузке
[] call mm_init;

// Регистрируем консольные команды если доступна система команд
if (!isNil "registerConsoleCommand") then {
	[] call mm_registerConsoleCommands;
};