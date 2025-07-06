// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

// Основные настройки менеджера карт
mm_use_alg2_vdir_check = true; // дополнительная валидация сериализации поворота/трансформации объекта

mm_folderSaveMaps = getMissionPath "src\host\MapManager\Maps\";
mm_internal_defaultMapExt = ".sqf";

// Подключаем модули менеджера карт
#include "Maps_manager_common.sqf"
#include "Maps_manager_importOld.sqf"

/*
	Интерфейс для виртуального сборщика карт
	Вызывает функции из DynamicMapLoader.sqf
*/

/*
	Виртуальная сборка текущей карты
*/
function(mm_virtualBuildCurrentMap)
{
	private _mapName = "missionName" call golib_getCommonStorageParam;
	private _mapPath = core_path_maps + "\" + _mapName + core_path_binarizedMapFileExt;
	
	if !([_mapPath] call file_exists) exitWith {
		["Файл карты не найден: %1", _mapPath] call showError;
		false
	};
	
	// Сначала сохраняем текущую карту
	[false] call mm_saveCurrentMapToFile;
	
	["Запуск виртуальной сборки карты: %1", _mapName] call showInfo;
	
	// Вызываем виртуальный сборщик
	private _result = [_mapPath] call dml_parseMap;
	_result params ["_success", "_instructions"];
	
	if (_success) then {
		// Сохраняем результат
		private _outputPath = mm_folderSaveMaps + _mapName + mm_internal_defaultMapExt;
		private _saveResult = [_outputPath, str _instructions, false] call file_write;
		
		if (_saveResult) then {
			["Виртуальная сборка завершена успешно: %1", _outputPath] call showInfo;
		} else {
			["Ошибка сохранения файла: %1", _outputPath] call showError;
		};
	} else {
		["Ошибка виртуальной сборки карты"] call showError;
	};
	
	_success
};

/*
	Валидация текущей карты
*/
function(mm_virtualValidateCurrentMap)
{
	private _mapName = "missionName" call golib_getCommonStorageParam;
	private _mapPath = core_path_maps + "\" + _mapName + core_path_binarizedMapFileExt;
	
	if !([_mapPath] call file_exists) exitWith {
		["Файл карты не найден: %1", _mapPath] call showError;
		false
	};
	
	// Сначала сохраняем текущую карту
	[false] call mm_saveCurrentMapToFile;
	
	["Запуск валидации карты: %1", _mapName] call showInfo;
	
	// Вызываем валидацию
	private _result = [_mapPath] call dml_validateMap;
	
	if (_result) then {
		["✓ Валидация карты %1 прошла успешно", _mapName] call showInfo;
	} else {
		["✗ Валидация карты %1 завершилась с ошибками (смотрите лог)", _mapName] call showWarning;
	};
	
	_result
};

/*
	Миграция текущей карты
*/
function(mm_virtualMigrateCurrentMap)
{
	private _mapName = "missionName" call golib_getCommonStorageParam;
	private _mapPath = core_path_maps + "\" + _mapName + core_path_binarizedMapFileExt;
	private _targetVersion = "version" call golib_getCommonStorageParam;
	
	if !([_mapPath] call file_exists) exitWith {
		["Файл карты не найден: %1", _mapPath] call showError;
		false
	};
	
	// Сначала сохраняем текущую карту
	[false] call mm_saveCurrentMapToFile;
	
	["Запуск миграции карты %1 до версии %2", _mapName, _targetVersion] call showInfo;
	
	// Вызываем миграцию
	private _result = [_mapPath, _targetVersion] call dml_migrateMap;
	
	if (_result) then {
		["✓ Миграция карты %1 завершена успешно", _mapName] call showInfo;
	} else {
		["✗ Миграция карты %1 завершилась с ошибками (смотрите лог)", _mapName] call showWarning;
	};
	
	_result
};

/*
	Пакетная обработка всех карт
*/
function(mm_virtualBatchProcessMaps)
{
	params ["_operation", ["_options", createHashMap]];
	
	["Запуск пакетной обработки: %1", _operation] call showInfo;
	
	// Путь к папке с картами 
	private _mapsFolder = core_path_maps;
	
	// Вызываем пакетную обработку
	private _result = [_mapsFolder, _operation, _options] call dml_batchProcessMaps;
	_result params ["_successCount", "_failCount", "_processedMaps", "_failedMaps"];
	
	// Показываем результат
	if (_failCount == 0) then {
		["✓ Пакетная обработка завершена успешно: %1 карт обработано", _successCount] call showInfo;
	} else {
		["⚠ Пакетная обработка завершена с ошибками: %1 успешно, %2 ошибок", _successCount, _failCount] call showWarning;
	};
	
	_result
};

/*
	Расширенное меню виртуального сборщика
*/
function(mm_showVirtualBuilderMenu)
{
	private _menuItems = [
		["Обычная сборка", { [] call mm_build }],
		["---", {}],
		["Виртуальная сборка текущей карты", { [] call mm_virtualBuildCurrentMap }],
		["Валидация текущей карты", { [] call mm_virtualValidateCurrentMap }],
		["Миграция текущей карты", { [] call mm_virtualMigrateCurrentMap }],
		["---", {}],
		["Пакетная сборка всех карт", { 
			["build", createHashMap] call mm_virtualBatchProcessMaps 
		}],
		["Валидация всех карт", { 
			["validate", createHashMap] call mm_virtualBatchProcessMaps 
		}],
		["Миграция всех карт", { 
			private _targetVersion = "version" call golib_getCommonStorageParam;
			private _options = createHashMap;
			_options set ["targetVersion", _targetVersion];
			["migrate", _options] call mm_virtualBatchProcessMaps 
		}]
	];
	
	[_menuItems, "Виртуальный сборщик карт"] call control_createMenu;
};

/*
	Команды для консоли разработчика
*/
function(mm_registerVirtualBuilderCommands)
{
	// Виртуальная сборка
	registerConsoleCommand("vbuild", {
		[] call mm_virtualBuildCurrentMap;
	}, "Виртуальная сборка текущей карты");
	
	// Валидация карты
	registerConsoleCommand("validate", {
		[] call mm_virtualValidateCurrentMap;
	}, "Валидация текущей карты");
	
	// Миграция карты  
	registerConsoleCommand("migrate", {
		[] call mm_virtualMigrateCurrentMap;
	}, "Миграция текущей карты");
	
	// Пакетная сборка
	registerConsoleCommand("batch_build", {
		["build", createHashMap] call mm_virtualBatchProcessMaps;
	}, "Пакетная сборка всех карт");
	
	registerConsoleCommand("batch_validate", {
		["validate", createHashMap] call mm_virtualBatchProcessMaps;
	}, "Валидация всех карт");
	
	registerConsoleCommand("batch_migrate", {
		private _targetVersion = "version" call golib_getCommonStorageParam;
		private _options = createHashMap;
		_options set ["targetVersion", _targetVersion];
		["migrate", _options] call mm_virtualBatchProcessMaps;
	}, "Миграция всех карт");
	
	["Зарегистрированы команды виртуального сборщика"] call printTrace;
};

// Регистрируем консольные команды если доступна система команд
if (!isNil "registerConsoleCommand") then {
	[] call mm_registerVirtualBuilderCommands;
};