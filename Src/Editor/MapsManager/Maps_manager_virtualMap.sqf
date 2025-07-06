// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

// Global variables for virtual map building
mm_virt_errorCount = 0;
mm_virt_errorText = "";
mm_virt_currentMapData = createHashMap;

/*
	Виртуальная сборка карты без загрузки в редактор
	Параметры:
	_mapname - имя карты для сборки
	_options - опции сборки (массив строк):
		- "validate-only" - только валидация без сборки
		- "force-migrate" - принудительная миграция версии
		- "no-success-info" - без уведомления об успехе
		- "build-all-maps" - собрать все карты
*/
function(mm_virt_build)
{
	params ["_mapname",["_options",[]]];
	
	// Проверяем наличие системы сборки классов
	if (isNull(goasm_isbuilded) || {!goasm_isbuilded}) exitWith {
		["Виртуальная сборка карт недоступна: сборка игровых объектов не выполнена"] call printError;
		false
	};
	
	["Начинаем виртуальную сборку карты: %1", _mapname] call printLog;
	
	// Сброс состояния
	mm_virt_errorCount = 0;
	mm_virt_errorText = "";
	mm_virt_currentMapData = createHashMap;
	
	// Загружаем конфигурацию карты
	private _mapConfig = [_mapname] call mm_virt_internal_loadMapConfig;
	if (isNil "_mapConfig") exitWith {
		["Ошибка загрузки конфигурации карты: %1", _mapname] call printError;
		false
	};
	
	// Извлекаем объекты из конфигурации
	private _objectsList = [_mapConfig] call mm_virt_extractObjects;
	if (count _objectsList == 0) exitWith {
		["Карта %1 не содержит объектов или произошла ошибка парсинга", _mapname] call printError;
		false
	};
	
	["Найдено %1 объектов в карте %2", count _objectsList, _mapname] call printLog;
	
	// Только валидация, если указана опция
	if ("validate-only" in _options) exitWith {
		[_objectsList, _options] call mm_virt_validateObjects
	};
	
	// Применяем миграции если нужно
	if ("force-migrate" in _options) then {
		_objectsList = [_objectsList, _mapConfig] call mm_virt_migrateMapVersion;
	};
	
	// Виртуальная сборка объектов
	private _buildResult = [_objectsList, _mapname, _options] call mm_virt_buildObjects;
	
	if (!_buildResult) exitWith {
		["Ошибка виртуальной сборки карты %1", _mapname] call printError;
		false
	};
	
	if !("no-success-info" in _options) then {
		["Виртуальная сборка карты %1 завершена успешно", _mapname] call printLog;
	};
	
	true
};

/*
	Загрузка и парсинг конфигурации карты
*/
function(mm_virt_internal_loadMapConfig)
{
	params ["_mapName"];

	private _cfgPath = core_path_maps + "\" + _mapName + core_path_binarizedMapFileExt;
	_cfgPath = [_cfgPath,"\//",'\'] call regex_replace;

	["Загрузка конфигурации карты: %1", _cfgPath] call printTrace;

	// Проверяем существование файла
	if !([_cfgPath] call file_exists) exitWith {
		["Файл карты не найден: %1", _cfgPath] call printError;
		nil
	};

	private _cfg = loadConfig _cfgPath;
	if (isNull _cfg) exitWith {
		["Ошибка загрузки конфигурации: %1", _cfgPath] call printError;
		nil
	};

	private _cfgMap = _cfg call mm_virt_internal_cfgConvertClass;
	["Загружено %1 ключей конфигурации", count keys _cfgMap] call printTrace;
	
	// Сохраняем данные карты для дальнейшего использования
	mm_virt_currentMapData set ["name", _mapName];
	mm_virt_currentMapData set ["path", _cfgPath];
	mm_virt_currentMapData set ["config", _cfgMap];
	
	_cfgMap
};

/*
	Извлечение объектов из конфигурации карты
*/
function(mm_virt_extractObjects)
{
	params ["_mapConfig"];
	
	private _objectsList = [];
	
	// Ищем секцию с объектами (обычно Mission -> Entities)
	private _mission = _mapConfig getOrDefault ["mission", createHashMap];
	private _entities = _mission getOrDefault ["entities", createHashMap];
	
	// Рекурсивно обходим все сущности
	[_entities, _objectsList] call mm_virt_internal_parseEntities;
	
	["Извлечено %1 объектов из конфигурации", count _objectsList] call printTrace;
	_objectsList
};

/*
	Рекурсивный парсинг сущностей
*/
function(mm_virt_internal_parseEntities)
{
	params ["_entitiesConfig", "_objectsList"];
	
	{
		private _key = _x;
		private _entity = _y;
		
		// Проверяем, является ли это объектом
		if (_entity isEqualType createHashMap) then {
			private _dataType = _entity getOrDefault ["datatype", ""];
			
			// Обрабатываем различные типы данных
			switch (_dataType) do {
				case "Object": {
					[_entity] call mm_virt_internal_parseObject;
					_objectsList pushBack _entity;
				};
				case "Group": {
					// Обрабатываем группы объектов
					private _groupEntities = _entity getOrDefault ["entities", createHashMap];
					[_groupEntities, _objectsList] call mm_virt_internal_parseEntities;
				};
			};
		};
	} forEach _entitiesConfig;
};

/*
	Парсинг отдельного объекта
*/
function(mm_virt_internal_parseObject)
{
	params ["_objectConfig"];
	
	// Извлекаем базовые данные объекта
	private _type = _objectConfig getOrDefault ["type", ""];
	private _position = _objectConfig getOrDefault ["position", [0,0,0]];
	private _rotation = _objectConfig getOrDefault ["rotation", [0,0,0]];
	
	// Конвертируем позицию и поворот из формата 3DEN в игровой формат
	private _gamePosition = [_position] call mm_virt_convertPosition;
	private _gameRotation = [_rotation] call mm_virt_convertRotation;
	private _gameVectorUp = [_rotation] call mm_virt_convertVectorUp;
	
	// Сохраняем конвертированные данные
	_objectConfig set ["gamePosition", _gamePosition];
	_objectConfig set ["gameRotation", _gameRotation];
	_objectConfig set ["gameVectorUp", _gameVectorUp];
	
	// Извлекаем пользовательские атрибуты объекта
	private _attributes = _objectConfig getOrDefault ["attributes", createHashMap];
	_objectConfig set ["customProps", [_attributes] call mm_virt_parseObjectAttributes];
};

/*
	Конвертор позиций из формата 3DEN в игровые координаты
*/
function(mm_virt_convertPosition)
{
	params ["_pos3den"];
	
	// В 3DEN позиции обычно в формате [x, y, z]
	// Для игры используем тот же формат, но может потребоваться коррекция высоты
	private _gamePos = +_pos3den;
	
	// Применяем коррекцию высоты если необходимо
	// (в реальной реализации может потребоваться учет рельефа)
	
	_gamePos
};

/*
	Конвертор поворотов из формата 3DEN в игровые значения
*/
function(mm_virt_convertRotation)
{
	params ["_rotation3den"];
	
	// 3DEN хранит повороты в радианах [pitch, bank, yaw]
	// Конвертируем в направление (azimuth) в градусах
	private _yaw = _rotation3den select 2;
	private _direction = (_yaw * 180 / pi) mod 360;
	if (_direction < 0) then { _direction = _direction + 360; };
	
	_direction
};

/*
	Конвертор векторов ориентации
*/
function(mm_virt_convertVectorUp)
{
	params ["_rotation3den"];
	
	// Конвертируем углы Эйлера в вектор направления вверх
	private _pitch = _rotation3den select 0;
	private _bank = _rotation3den select 1;
	private _yaw = _rotation3den select 2;
	
	// Вычисляем матрицу поворота и извлекаем вектор вверх
	// Для простоты используем стандартный вектор, если углы небольшие
	private _vectorUp = [0, 0, 1];
	
	// Если есть значительные углы наклона, вычисляем правильный вектор
	if (abs _pitch > 0.1 || abs _bank > 0.1) then {
		// Упрощенная формула для вектора вверх
		_vectorUp = [
			sin _bank * cos _pitch,
			-sin _pitch,
			cos _bank * cos _pitch
		];
	};
	
	_vectorUp
};

/*
	Парсинг атрибутов объекта
*/
function(mm_virt_parseObjectAttributes)
{
	params ["_attributes"];
	
	private _customProps = createHashMap;
	
	{
		private _attrName = _x;
		private _attrData = _y;
		
		// Извлекаем значение атрибута в зависимости от его типа
		private _value = switch (typeName _attrData) do {
			case "HASHMAP": {
				_attrData getOrDefault ["value", nil]
			};
			case "STRING": { _attrData };
			case "SCALAR": { _attrData };
			case "BOOL": { _attrData };
			case "ARRAY": { _attrData };
			default { str _attrData };
		};
		
		if (!isNil "_value") then {
			_customProps set [_attrName, _value];
		};
	} forEach _attributes;
	
	_customProps
};

/*
	Виртуальная сборка объектов
*/
function(mm_virt_buildObjects)
{
	params ["_objectsList", "_mapName", "_options"];
	
	private _output = "";
	private _postOutput = "";
	
	// Генерируем заголовки
	_output = _output + format["__metaInfo__ = 'Virtual builded on editor version: %1';", Core_version_name];
	_output = _output + format["__metaInfoVersion__ = %1;", "version" call golib_getCommonStorageParam];
	_output = _output + "go_editor_globalRefs = createHashMap;" + endl;
	
	// Генерируем код инициализации
	_output = _output + (call golib_getCodeCallers) + endl;
	
	// Обрабатываем каждый объект
	{
		private _objResult = [_x, _foreachIndex, count _objectsList, _options] call mm_virt_handleObjectBuild;
		if (_objResult != "") then {
			_output = _output + _objResult + endl;
		};
	} forEach _objectsList;
	
	// Добавляем пост-обработку
	_output = _output + _postOutput;
	
	// Сохраняем результат
	private _outputPath = mm_folderSaveMaps + "/" + _mapName + mm_internal_defaultMapExt;
	private _saveResult = [_outputPath, _output, false] call file_write;
	
	if (!_saveResult) then {
		["Ошибка сохранения файла карты: %1", _outputPath] call printError;
		false
	} else {
		["Карта сохранена: %1", _outputPath] call printLog;
		true
	}
};

/*
	Виртуальная обработка отдельного объекта
*/
function(mm_virt_handleObjectBuild)
{
	params ["_objectData", "_index", "_total", "_options"];
	
	// Извлекаем данные объекта
	private _type = _objectData getOrDefault ["type", ""];
	private _position = _objectData getOrDefault ["gamePosition", [0,0,0]];
	private _direction = _objectData getOrDefault ["gameRotation", 0];
	private _vectorUp = _objectData getOrDefault ["gameVectorUp", [0,0,1]];
	private _customProps = _objectData getOrDefault ["customProps", createHashMap];
	
	// Валидация класса объекта
	if !([_type] call oop_reflect_hasClass) exitWith {
		mm_virt_errorCount = mm_virt_errorCount + 1;
		mm_virt_errorText = mm_virt_errorText + format["Неизвестный класс объекта: %1%2", _type, endl];
		["Неизвестный класс объекта: %1", _type] call printWarning;
		""
	};
	
	// Определяем инстанцер
	private _instancer = eden_enum_instancerNames select ([_type,"",true,"getChunkType"] call oop_getFieldBaseValue);
	
	// Генерируем код создания объекта
	private _objectCode = format["['%1',%2,%3,%4] call %5;", _type, _position, _direction, _vectorUp, _instancer];
	
	// Добавляем пользовательские свойства если есть
	if (count _customProps > 0) then {
		// Генерируем уникальное имя переменной
		private _varName = format["_vobj_%1", _index];
		_objectCode = format["%1 = %2", _varName, _objectCode];
		
		// Добавляем установку свойств
		{
			_objectCode = _objectCode + format["%1 setVariable ['%2', %3];", _varName, _x, _y];
		} forEach _customProps;
	};
	
	if !("no-bake-object-info" in _options) then {
		["Виртуально обработан объект %1 (%2/%3)", _type, _index + 1, _total] call printTrace;
	};
	
	_objectCode
};

/*
	Валидация объектов карты
*/
function(mm_virt_validateObjects)
{
	params ["_objectsList", "_options"];
	
	private _validationErrors = [];
	private _warnings = [];
	
	{
		private _obj = _x;
		private _type = _obj getOrDefault ["type", ""];
		private _position = _obj getOrDefault ["gamePosition", [0,0,0]];
		
		// Проверяем существование класса
		if !([_type] call oop_reflect_hasClass) then {
			_validationErrors pushBack format["Объект %1 в позиции %2: неизвестный класс", _type, _position];
		};
		
		// Проверяем корректность позиции
		if (_position isEqualTo [0,0,0]) then {
			_warnings pushBack format["Объект %1: возможно некорректная позиция [0,0,0]", _type];
		};
		
		// Дополнительные проверки можно добавить здесь
		
	} forEach _objectsList;
	
	// Выводим результаты валидации
	if (count _validationErrors > 0) then {
		["Валидация карты завершена с ошибками:"] call printError;
		{
			["  - %1", _x] call printError;
		} forEach _validationErrors;
		false
	} else {
		["Валидация карты прошла успешно"] call printLog;
		if (count _warnings > 0) then {
			["Предупреждения:"] call printWarning;
			{
				["  - %1", _x] call printWarning;
			} forEach _warnings;
		};
		true
	}
};

/*
	Миграция версии карты
*/
function(mm_virt_migrateMapVersion)
{
	params ["_objectsList", "_mapConfig"];
	
	// Определяем версию карты
	private _currentVersion = [_mapConfig] call mm_virt_detectMapVersion;
	private _targetVersion = "version" call golib_getCommonStorageParam;
	
	if (_currentVersion == _targetVersion) exitWith {
		["Карта уже имеет актуальную версию: %1", _currentVersion] call printLog;
		_objectsList
	};
	
	["Начинаем миграцию карты с версии %1 на %2", _currentVersion, _targetVersion] call printLog;
	
	// Применяем миграции (здесь можно добавить специфичные для версии миграции)
	private _migratedObjects = [_objectsList, _currentVersion, _targetVersion] call mm_virt_applyMigrations;
	
	["Миграция карты завершена"] call printLog;
	_migratedObjects
};

/*
	Определение версии карты
*/
function(mm_virt_detectMapVersion)
{
	params ["_mapConfig"];
	
	// Пытаемся найти информацию о версии в метаданных
	private _version = _mapConfig getOrDefault ["__metaInfoVersion__", "unknown"];
	
	if (_version == "unknown") then {
		// Пытаемся определить версию по структуре данных
		// Здесь можно добавить логику определения версии по наличию определенных полей
		_version = "legacy";
	};
	
	_version
};

/*
	Применение миграций
*/
function(mm_virt_applyMigrations)
{
	params ["_objectsList", "_fromVersion", "_toVersion"];
	
	// Здесь можно добавить специфичные миграции для разных версий
	// Например:
	// - переименование классов объектов
	// - изменение структуры атрибутов
	// - коррекция позиций и поворотов
	
	["Применяем миграции с %1 на %2", _fromVersion, _toVersion] call printTrace;
	
	// Возвращаем объекты (возможно модифицированные)
	_objectsList
};

//used from https://community.bistudio.com/wiki/loadConfig
function(mm_virt_internal_cfgConvertClass)
{
	params ["_cfgClass"];

	private _result = createHashMap;
	private _props = configProperties [_cfgClass, "true", true];
	// note: Hashmaps are case-sensitive so configName cases have to be consistent (e.g. all lowercase)
	{
		if (isNumber _x)	then { _result set [toLowerANSI configName _x, getNumber _x];	continue; };
		if (isText _x)		then { _result set [toLowerANSI configName _x, getText _x];		continue; };
		if (isArray _x)		then { _result set [toLowerANSI configName _x, getArray _x];	continue; };
	} forEach _props;

	private _classes = "true" configClasses _cfgClass;
	{
		_result set [toLowerANSI configName _x, _x call mm_virt_internal_cfgConvertClass];
	} forEach _classes;

	_result
};