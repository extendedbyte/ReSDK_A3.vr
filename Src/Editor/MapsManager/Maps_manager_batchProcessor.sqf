// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================

/*
	Пакетный процессор карт для виртуальной сборки
	Предоставляет командный интерфейс для автоматической обработки всех карт
*/

// Глобальные переменные для пакетной обработки
mm_batch_currentMapIndex = 0;
mm_batch_totalMaps = 0;
mm_batch_processedMaps = [];
mm_batch_failedMaps = [];
mm_batch_isRunning = false;

/*
	Пакетная сборка всех карт
	Параметры:
	_options - опции обработки:
		- "validate-only" - только валидация
		- "force-migrate" - принудительная миграция
		- "continue-on-error" - продолжать при ошибках
		- "generate-report" - создать отчет об обработке
*/
function(mm_batch_buildAllMaps)
{
	params [["_options", []]];
	
	if (mm_batch_isRunning) exitWith {
		["Пакетная обработка уже запущена"] call printWarning;
		false
	};
	
	["Начинаем пакетную обработку карт"] call printLog;
	
	// Получаем список всех карт
	private _mapsList = [] call mm_batch_getAllMapsList;
	if (count _mapsList == 0) exitWith {
		["Не найдено карт для обработки"] call printWarning;
		false
	};
	
	// Инициализируем пакетную обработку
	mm_batch_isRunning = true;
	mm_batch_currentMapIndex = 0;
	mm_batch_totalMaps = count _mapsList;
	mm_batch_processedMaps = [];
	mm_batch_failedMaps = [];
	
	["Найдено %1 карт для обработки", mm_batch_totalMaps] call printLog;
	
	// Запускаем асинхронную обработку
	[_mapsList, _options] spawn mm_batch_processMapsList;
	
	true
};

/*
	Получение списка всех карт
*/
function(mm_batch_getAllMapsList)
{
	// Получаем список файлов из папки карт
	private _mapFiles = [core_path_maps] call file_getFileList;
	
	// Фильтруем только файлы с расширением карт
	private _mapsList = [];
	{
		if (core_path_binarizedMapFileExt in _x) then {
			private _mapName = [_x, core_path_binarizedMapFileExt, ""] call str_replace;
			_mapsList pushBack _mapName;
		};
	} forEach _mapFiles;
	
	["Найдено %1 файлов карт", count _mapsList] call printTrace;
	_mapsList
};

/*
	Асинхронная обработка списка карт
*/
function(mm_batch_processMapsList)
{
	params ["_mapsList", "_options"];
	
	private _startTime = time;
	private _continueOnError = "continue-on-error" in _options;
	
	{
		mm_batch_currentMapIndex = _foreachIndex;
		private _mapName = _x;
		
		["Обработка карты %1 (%2/%3)", _mapName, _foreachIndex + 1, count _mapsList] call printLog;
		
		// Обрабатываем карту
		private _result = [_mapName, _options] call mm_virt_build;
		
		if (_result) then {
			mm_batch_processedMaps pushBack _mapName;
			["✓ Карта %1 обработана успешно", _mapName] call printLog;
		} else {
			mm_batch_failedMaps pushBack _mapName;
			["✗ Ошибка обработки карты %1", _mapName] call printError;
			
			if (!_continueOnError) exitWith {
				["Пакетная обработка прервана из-за ошибки"] call printError;
			};
		};
		
		// Небольшая пауза между картами для стабильности
		uiSleep 0.1;
		
	} forEach _mapsList;
	
	// Завершаем пакетную обработку
	mm_batch_isRunning = false;
	private _totalTime = time - _startTime;
	
	// Выводим итоги
	[_mapsList, _totalTime, _options] call mm_batch_generateReport;
};

/*
	Генерация отчета о пакетной обработке
*/
function(mm_batch_generateReport)
{
	params ["_mapsList", "_totalTime", "_options"];
	
	private _successCount = count mm_batch_processedMaps;
	private _failCount = count mm_batch_failedMaps;
	private _totalCount = count _mapsList;
	
	// Консольный отчет
	[""] call printLog;
	["=== ОТЧЕТ О ПАКЕТНОЙ ОБРАБОТКЕ КАРТ ==="] call printLog;
	["Общее время обработки: %1 сек", _totalTime toFixed 1] call printLog;
	["Всего карт: %1", _totalCount] call printLog;
	["Успешно обработано: %1", _successCount] call printLog;
	["Ошибок: %1", _failCount] call printLog;
	["Процент успеха: %1%", ((_successCount / _totalCount) * 100) toFixed 1] call printLog;
	
	if (_failCount > 0) then {
		[""] call printLog;
		["Карты с ошибками:"] call printError;
		{
			["  - %1", _x] call printError;
		} forEach mm_batch_failedMaps;
	};
	
	// Создаем файловый отчет если запрошено
	if ("generate-report" in _options) then {
		[_mapsList, _totalTime] call mm_batch_saveReportToFile;
	};
	
	["=== КОНЕЦ ОТЧЕТА ==="] call printLog;
	[""] call printLog;
};

/*
	Сохранение отчета в файл
*/
function(mm_batch_saveReportToFile)
{
	params ["_mapsList", "_totalTime"];
	
	private _reportContent = "";
	private _timestamp = [] call getFormattedTime;
	
	_reportContent = _reportContent + format["Отчет о пакетной обработке карт%1", endl];
	_reportContent = _reportContent + format["Дата и время: %1%2", _timestamp, endl];
	_reportContent = _reportContent + format["Версия редактора: %1%2", Core_version_name, endl];
	_reportContent = _reportContent + format["%1", endl];
	
	_reportContent = _reportContent + format["Общее время обработки: %1 сек%2", _totalTime toFixed 1, endl];
	_reportContent = _reportContent + format["Всего карт: %1%2", count _mapsList, endl];
	_reportContent = _reportContent + format["Успешно обработано: %1%2", count mm_batch_processedMaps, endl];
	_reportContent = _reportContent + format["Ошибок: %1%2", count mm_batch_failedMaps, endl];
	_reportContent = _reportContent + format["%1", endl];
	
	if (count mm_batch_processedMaps > 0) then {
		_reportContent = _reportContent + format["Успешно обработанные карты:%1", endl];
		{
			_reportContent = _reportContent + format["  + %1%2", _x, endl];
		} forEach mm_batch_processedMaps;
		_reportContent = _reportContent + format["%1", endl];
	};
	
	if (count mm_batch_failedMaps > 0) then {
		_reportContent = _reportContent + format["Карты с ошибками:%1", endl];
		{
			_reportContent = _reportContent + format["  - %1%2", _x, endl];
		} forEach mm_batch_failedMaps;
	};
	
	// Сохраняем отчет
	private _reportPath = format["%1/batch_report_%2.txt", core_path_bin, [_timestamp, ":", "_"] call str_replace];
	private _saveResult = [_reportPath, _reportContent, false] call file_write;
	
	if (_saveResult) then {
		["Отчет сохранен: %1", _reportPath] call printLog;
	} else {
		["Ошибка сохранения отчета: %1", _reportPath] call printError;
	};
};

/*
	Валидация всех карт без сборки
*/
function(mm_batch_validateAllMaps)
{
	["validate-only", "continue-on-error", "generate-report"] call mm_batch_buildAllMaps
};

/*
	Миграция всех карт на новую версию
*/
function(mm_batch_migrateAllMaps)
{
	["force-migrate", "continue-on-error", "generate-report"] call mm_batch_buildAllMaps
};

/*
	Получение статуса пакетной обработки
*/
function(mm_batch_getStatus)
{
	if (!mm_batch_isRunning) exitWith {
		["Пакетная обработка не запущена"] call printLog;
	};
	
	private _progress = ((mm_batch_currentMapIndex + 1) / mm_batch_totalMaps) * 100;
	["Прогресс: %1% (%2/%3 карт)", _progress toFixed 1, mm_batch_currentMapIndex + 1, mm_batch_totalMaps] call printLog;
	["Обработано успешно: %1", count mm_batch_processedMaps] call printLog;
	["Ошибок: %1", count mm_batch_failedMaps] call printLog;
};

/*
	Остановка пакетной обработки
*/
function(mm_batch_stop)
{
	if (!mm_batch_isRunning) exitWith {
		["Пакетная обработка не запущена"] call printWarning;
	};
	
	mm_batch_isRunning = false;
	["Пакетная обработка остановлена пользователем"] call printWarning;
};

/*
	Получение отформатированного времени
*/
function(getFormattedTime)
{
	private _time = systemTime;
	format["%1-%2-%3_%4-%5-%6", 
		_time select 0,		// год
		(_time select 1) call formatNumber,	// месяц
		(_time select 2) call formatNumber,	// день
		(_time select 3) call formatNumber,	// час
		(_time select 4) call formatNumber,	// минута
		(_time select 5) call formatNumber	// секунда
	]
};

/*
	Форматирование числа с ведущим нулем
*/
function(formatNumber)
{
	private _num = _this;
	if (_num < 10) then {
		format["0%1", _num]
	} else {
		str _num
	}
};