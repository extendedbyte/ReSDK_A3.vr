# Руководство по использованию виртуального сборщика карт

## Обзор

Виртуальный сборщик карт - это инструмент ReSDK_A3, который позволяет собирать и валидировать карты без их загрузки в редактор 3DEN. Это значительно ускоряет процесс сборки большого количества карт и позволяет автоматизировать валидацию карт при релизе.

## Основные возможности

- **Виртуальная сборка** - сборка карт напрямую из .cpp файлов
- **Пакетная обработка** - автоматическая сборка всех карт проекта
- **Валидация** - проверка корректности карт без сборки
- **Миграция версий** - автоматическое обновление старых карт
- **Отчетность** - детальные отчеты об обработке

## Требования

1. Собранные игровые объекты (`goasm_isbuilded = true`)
2. Наличие .cpp файлов карт в папке `src/Editor/bin/Maps/`
3. Правильно настроенные пути в конфигурации

## Использование

### 1. Через графический интерфейс

Для открытия меню сборки карт:
```sqf
[] call mm_showBuildMenu;
```

Доступные опции:
- **Обычная сборка** - стандартная сборка текущей карты
- **Виртуальная сборка текущей карты** - виртуальная сборка без загрузки
- **Валидация текущей карты** - только проверка корректности
- **Пакетная обработка всех карт** - сборка всех карт проекта
- **Валидация всех карт** - проверка всех карт
- **Миграция всех карт** - обновление версий всех карт

### 2. Через консольные команды

#### Виртуальная сборка одной карты
```sqf
// Сборка текущей карты
vbuild

// Сборка конкретной карты
vbuild "map_name"

// Сборка с опциями
vbuild "map_name" ["no-success-info"]
```

#### Валидация карт
```sqf
// Валидация текущей карты
validate

// Валидация конкретной карты
validate "map_name"

// Валидация всех карт
batch_validate
```

#### Пакетная обработка
```sqf
// Сборка всех карт
batch_build

// Сборка с опциями
batch_build ["continue-on-error", "generate-report"]

// Миграция всех карт
batch_migrate

// Статус выполнения
batch_status

// Остановка процесса
batch_stop
```

### 3. Программное использование

#### Виртуальная сборка карты
```sqf
private _mapName = "test_map";
private _options = ["no-success-info"];
private _result = [_mapName, _options] call mm_virt_build;

if (_result) then {
    ["Карта %1 собрана успешно", _mapName] call printLog;
} else {
    ["Ошибка сборки карты %1", _mapName] call printError;
};
```

#### Валидация карты
```sqf
private _mapName = "test_map";
private _result = [_mapName, ["validate-only"]] call mm_virt_build;

if (_result) then {
    ["Карта %1 прошла валидацию", _mapName] call printLog;
} else {
    ["Карта %1 содержит ошибки", _mapName] call printError;
};
```

#### Пакетная обработка
```sqf
// Запуск пакетной сборки
private _options = ["continue-on-error", "generate-report"];
private _result = [_options] call mm_batch_buildAllMaps;

// Мониторинг прогресса
while {mm_batch_isRunning} do {
    [] call mm_batch_getStatus;
    uiSleep 5;
};
```

## Опции сборки

### Основные опции
- `"validate-only"` - только валидация без создания файла карты
- `"force-migrate"` - принудительная миграция версии карты
- `"no-success-info"` - отключение уведомлений об успехе
- `"no-bake-object-info"` - отключение логирования обработки объектов

### Опции пакетной обработки
- `"continue-on-error"` - продолжение при ошибках (не останавливать процесс)
- `"generate-report"` - создание файлового отчета

## Структура виртуального сборщика

### Основные компоненты

1. **mm_virt_build** - главная функция виртуальной сборки
2. **mm_virt_internal_loadMapConfig** - загрузка конфигурации карты
3. **mm_virt_extractObjects** - извлечение объектов из конфигурации
4. **mm_virt_convertPosition/Rotation** - конверторы координат
5. **mm_virt_validateObjects** - валидация объектов
6. **mm_virt_migrateMapVersion** - миграция версий

### Конверторы координат

#### Позиции
```sqf
// Конвертация позиции из 3DEN в игровой формат
private _gamePos = [_pos3den] call mm_virt_convertPosition;
```

#### Повороты  
```sqf
// Конвертация поворота из углов Эйлера в направление
private _direction = [_rotation3den] call mm_virt_convertRotation;

// Конвертация в вектор ориентации
private _vectorUp = [_rotation3den] call mm_virt_convertVectorUp;
```

## Обработка ошибок

### Типичные ошибки

1. **"Файл карты не найден"** - отсутствует .cpp файл карты
2. **"Неизвестный класс объекта"** - класс не найден в системе объектов
3. **"Ошибка загрузки конфигурации"** - поврежденный .cpp файл

### Отладка

Для включения детального логирования:
```sqf
// Включить трассировку
setLogLevel 2;

// Выполнить виртуальную сборку
[_mapName, []] call mm_virt_build;
```

## Интеграция с CI/CD

### Автоматическая валидация

Для использования в системах непрерывной интеграции:

```sqf
// Скрипт валидации всех карт
private _result = [] call mm_batch_validateAllMaps;

// Ожидание завершения
while {mm_batch_isRunning} do { uiSleep 1; };

// Проверка результатов
if (count mm_batch_failedMaps > 0) then {
    // Есть ошибки - завершить с кодом ошибки
    ["CI: Валидация карт завершилась с ошибками"] call printError;
    {
        ["CI: Ошибка в карте: %1", _x] call printError;
    } forEach mm_batch_failedMaps;
    // exit с кодом 1
} else {
    ["CI: Все карты прошли валидацию успешно"] call printLog;
    // exit с кодом 0
};
```

### Автоматическая сборка релиза

```sqf
// Скрипт полной сборки для релиза
["Начинаем сборку релиза"] call printLog;

// 1. Миграция всех карт
private _migrateResult = [] call mm_batch_migrateAllMaps;
while {mm_batch_isRunning} do { uiSleep 1; };

// 2. Валидация после миграции
private _validateResult = [] call mm_batch_validateAllMaps;
while {mm_batch_isRunning} do { uiSleep 1; };

// 3. Сборка всех карт
if (count mm_batch_failedMaps == 0) then {
    private _buildResult = [["generate-report"]] call mm_batch_buildAllMaps;
    while {mm_batch_isRunning} do { uiSleep 1; };
    
    ["Релиз готов. Успешно собрано: %1 карт", count mm_batch_processedMaps] call printLog;
} else {
    ["Релиз прерван из-за ошибок валидации"] call printError;
};
```

## Расширение функционала

### Добавление собственных валидаторов

```sqf
// Пример кастомного валидатора
function(mm_virt_validateObjects_custom)
{
    params ["_objectsList", "_options"];
    
    private _errors = [];
    
    {
        private _obj = _x;
        
        // Ваша логика валидации
        if (/* условие ошибки */) then {
            _errors pushBack "Описание ошибки";
        };
        
    } forEach _objectsList;
    
    count _errors == 0
};
```

### Добавление миграций

```sqf
// Пример кастомной миграции
function(mm_virt_applyMigrations_custom)
{
    params ["_objectsList", "_fromVersion", "_toVersion"];
    
    if (_fromVersion == "1.0" && _toVersion == "1.1") then {
        {
            // Применить миграцию к объекту _x
            // Например, переименовать класс или изменить атрибуты
        } forEach _objectsList;
    };
    
    _objectsList
};
```

## Производительность

### Рекомендации по оптимизации

1. **Используйте пакетную обработку** для множества карт
2. **Отключайте лишние логи** опцией `"no-bake-object-info"`
3. **Запускайте валидацию отдельно** от сборки
4. **Используйте асинхронный режим** для больших проектов

### Мониторинг производительности

```sqf
// Замер времени сборки
private _startTime = time;
[_mapName, []] call mm_virt_build;
private _buildTime = time - _startTime;
["Время сборки карты %1: %2 сек", _mapName, _buildTime] call printLog;
```

## Заключение

Виртуальный сборщик карт значительно упрощает работу с большими проектами, обеспечивая быструю и надежную сборку карт без необходимости их загрузки в редактор. Инструмент полностью интегрирован в ReSDK и готов к использованию в производственных процессах.