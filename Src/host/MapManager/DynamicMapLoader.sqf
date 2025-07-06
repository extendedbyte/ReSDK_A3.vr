// ======================================================
// Copyright (c) 2017-2025 the ReSDK_A3 project
// sdk.relicta.ru
// ======================================================
#include "..\engine.hpp"
#include "..\oop.hpp"
#include "..\struct.hpp"

struct(BinaryMapInstructions)

	def(_buffer) null;
	def(_bufferEnd) null;
	def(_errorCount) 0;
	def(_errorList) [];

	def(_generated) 0; 

	def(_allSpawnPoints) null;
	def(_validationMode) false; // Режим только валидации без генерации кода
	def(_migrateMode) false; // Режим миграции версий

	def(init)
	{
		self setv(_errorList,[]);
		self setv(_buffer,[]);
		self setv(_bufferEnd,[]);
		self setv(_allSpawnPoints,[]);
		self setv(_validationMode,false);
		self setv(_migrateMode,false);
	}

	def(isSuccessBuild) {(self getv(_errorCount)) == 0}

	def(printErr)
	{
		private _mformat = format _this;
		
		error(_mformat);

		self callp(addError,_mformat);
	}

	def(addError)
	{
		params ["_message"];
		if !(_message in (self getv(_errorList))) then {
			self getv(_errorList) pushBack _message;
		};
		self setv(_errorCount,(self getv(_errorCount)) + 1);
	}

	def(prepareCode)
	{
		if (self getv(_validationMode)) exitWith {
			// В режиме валидации возвращаем пустую функцию
			compile "{}"
		};
		
		private _buff = array_copy(self getv(_buffer));
		private _buffEnd = self getv(_bufferEnd);
		_buff append _buffEnd;

		compile (_buff joinString "");
	}

	endstruct

// https://github.com/CBATeam/CBA_A3/issues/1352#issuecomment-665343452
dml_internal_eulerToVec = {
	params ["_rotation"];
	_rotation params ["_rotX", "_rotY", "_rotZ"];

	_vectorDirAndUp = [
		[
			(cos _rotY) * (sin _rotZ),
			(cos _rotX)*(cos _rotZ)+(sin _rotX)*(sin _rotY)*(sin _rotZ),
			-(sin _rotX)*(cos _rotZ)+(cos _rotX)*(sin _rotY)*(sin _rotZ)
		],
		[
			-sin _rotY, 
			(sin _rotX)*(cos _rotY), 
			(cos _rotX)*(cos _rotY)
		]
	];
	_vectorDirAndUp
};

// Константы для конвертации
dml_const_zOffset = 6.04903;
dml_const_radToDeg = 180 / pi;

// Улучшенные конверторы позиций и поворотов
dml_convertPosition = {
	params ["_pos3den", "_atlOffset"];
	
	// Конвертируем из формата 3DEN [x,z,y] в игровой [x,y,z]
	private _gamePos = [
		_pos3den select 0,           // x остается x
		_pos3den select 2,           // z становится y  
		(_pos3den select 1) - _atlOffset  // y становится z с учетом ATL offset
	];
	
	// Применяем коррекцию высоты если необходимо
	if ((_gamePos select 2) > 1000) then {
		_gamePos set [2, (_gamePos select 2) - dml_const_zOffset];
	};
	
	_gamePos
};

dml_convertRotation = {
	params ["_eulerAngles"];
	
	// Используем существующую функцию для получения векторов направления
	([_eulerAngles] call dml_internal_eulerToVec) params ["_vectorDir", "_vectorUp"];
	
	// Вычисляем азимут (направление) в градусах
	private _azimuth = ((_vectorDir select 0) atan2 (_vectorDir select 1)) * dml_const_radToDeg;
	if (_azimuth < 0) then { _azimuth = _azimuth + 360; };
	
	[_azimuth, _vectorDir, _vectorUp]
};

// Функция валидации карты
dml_validateMap = {
	params ["_mapPath"];
	
	private _cfg = LoadConfig _mapPath;
	if (isNull _cfg) exitWith {
		setLastError("Cannot load config: " + _mapPath);
		false
	};
	
	private _cfgMap = _cfg call dml_prepMapConfig;
	private _bmap = struct_new(BinaryMapInstructions);
	_bmap setv(_validationMode, true);

	[_cfgMap,_bmap] call dml_prepareMapBuffer;

	private _isValid = _bmap callv(isSuccessBuild);
	private _errorList = _bmap getv(_errorList);
	
	if (!_isValid) then {
		{
			errorformat("Validation error: %1", _x);
		} forEach _errorList;
	};
	
	traceformat("Map validation %1: %2 objects processed, %3 errors", 
		ifcheck(_isValid,"PASSED","FAILED"), 
		_bmap getv(_generated), 
		count _errorList
	);
	
	_isValid
};

// Функция миграции версии карты
dml_migrateMap = {
	params ["_mapPath", "_targetVersion"];
	
	traceformat("Starting map migration to version %1", _targetVersion);
	
	private _cfg = LoadConfig _mapPath;
	if (isNull _cfg) exitWith {
		setLastError("Cannot load config for migration: " + _mapPath);
		false
	};
	
	private _cfgMap = _cfg call dml_prepMapConfig;
	private _bmap = struct_new(BinaryMapInstructions);
	_bmap setv(_migrateMode, true);

	// Применяем миграции к конфигурации
	_cfgMap = [_cfgMap, _targetVersion] call dml_applyMigrations;
	
	[_cfgMap,_bmap] call dml_prepareMapBuffer;

	if !(_bmap callv(isSuccessBuild)) exitWith {
		setLastError("Error on migrating map: " + _mapPath);
		false
	};

	traceformat("Map migration completed: %1 objects migrated", _bmap getv(_generated));
	true
};

// Применение миграций к конфигурации карты
dml_applyMigrations = {
	params ["_cfgMap", "_targetVersion"];
	
	// Определяем текущую версию карты
	private _currentVersion = [_cfgMap] call dml_detectMapVersion;
	
	if (_currentVersion == _targetVersion) exitWith {
		traceformat("Map already at target version %1", _targetVersion);
		_cfgMap
	};
	
	traceformat("Migrating from %1 to %2", _currentVersion, _targetVersion);
	
	// Здесь можно добавить специфичные миграции для разных версий
	// Например:
	// if (_currentVersion == "1.0" && _targetVersion == "1.1") then {
	//     _cfgMap = [_cfgMap] call dml_migrate_1_0_to_1_1;
	// };
	
	// Обновляем версию в метаданных
	private _entities = [_cfgMap, "Mission\Entities"] call dml_internal_getPath;
	if (!isNil "_entities") then {
		{
			private _entity = _y;
			if (_entity isEqualType createHashMap && 
				{_entity getOrDefault ["type", ""] == "Land_Orange_01_F"}) then {
				
				private _attributes = _entity getOrDefault ["attributes", createHashMap];
				private _init = _attributes getOrDefault ["init", ""];
				
				if (_init != "") then {
					// Обновляем версию в метаданных карты
					private _initData = call (call compile _init);
					if ("missionName" in _initData) then {
						_initData set ["version", _targetVersion];
						_attributes set ["init", str _initData];
					};
				};
			};
		} forEach _entities;
	};
	
	_cfgMap
};

// Определение версии карты
dml_detectMapVersion = {
	params ["_cfgMap"];
	
	private _version = "unknown";
	
	// Ищем объект с метаданными карты (обычно Land_Orange_01_F)
	private _entities = [_cfgMap, "Mission\Entities"] call dml_internal_getPath;
	if (!isNil "_entities") then {
		{
			private _entity = _y;
			if (_entity isEqualType createHashMap && 
				{_entity getOrDefault ["type", ""] == "Land_Orange_01_F"}) then {
				
				private _attributes = _entity getOrDefault ["attributes", createHashMap];
				private _init = _attributes getOrDefault ["init", ""];
				
				if (_init != "") then {
					private _initData = call (call compile _init);
					if ("version" in _initData) then {
						_version = _initData get "version";
					};
				};
			};
		} forEach _entities;
	};
	
	// Если версия не найдена, пытаемся определить по структуре
	if (_version == "unknown") then {
		_version = "legacy";
	};
	
	_version
};

// Пакетная обработка карт
dml_batchProcessMaps = {
	params ["_mapFolder", "_operation", ["_options", []]];
	
	private _mapFiles = [_mapFolder] call file_getFileList;
	private _processedMaps = [];
	private _failedMaps = [];
	
	traceformat("Starting batch %1 for %2 maps", _operation, count _mapFiles);
	
	{
		private _mapPath = _mapFolder + "\" + _x;
		private _mapName = [_x, ".cpp", ""] call str_replace;
		
		traceformat("Processing map %1 (%2/%3)", _mapName, _foreachIndex + 1, count _mapFiles);
		
		private _result = false;
		switch (_operation) do {
			case "validate": {
				_result = [_mapPath] call dml_validateMap;
			};
			case "migrate": {
				private _targetVersion = _options getOrDefault ["targetVersion", "1.0"];
				_result = [_mapPath, _targetVersion] call dml_migrateMap;
			};
			case "build": {
				_result = [_mapPath] call dml_parseMap;
				_result = _result select 0;
			};
		};
		
		if (_result) then {
			_processedMaps pushBack _mapName;
			traceformat("✓ %1 completed for %2", _operation, _mapName);
		} else {
			_failedMaps pushBack _mapName;
			errorformat("✗ %1 failed for %2", _operation, _mapName);
		};
		
	} forEach _mapFiles;
	
	traceformat("Batch %1 completed: %2 success, %3 failed", 
		_operation, count _processedMaps, count _failedMaps);
	
	if (count _failedMaps > 0) then {
		errorformat("Failed maps: %1", _failedMaps joinString ", ");
	};
	
	[count _processedMaps, count _failedMaps, _processedMaps, _failedMaps]
};

//загрузчик карты
dml_loadMap = {
	params ["_path"];
	([_path] call dml_parseMap) params ["_status","_instr"];
	if (_status) then {
		call _instr;
	};
};

//подготовка загрузочных инструкций
dml_parseMap = {
	params ["_mapPath"];
	_mapPath = [_mapPath,"\//",'\'] call regex_replace;

	traceformat("Attempt load config %1",_mapPath);

	private _cfg = LoadConfig _mapPath;
	private _cfgMap = _cfg call dml_prepMapConfig;
	private _bmap = struct_new(BinaryMapInstructions);

	[_cfgMap,_bmap] call dml_prepareMapBuffer;

	if !(_bmap callv(isSuccessBuild)) exitWith {
		setLastError("Error on loading map: " + _mapPath);
		[false,{}]
	};

	traceformat("Map parsing done; Objects %1",_bmap getv(_generated));

	[true,_bmap callv(prepareCode)];
};

dml_prepareMapBuffer = {
	params ["_cfg","_bmap"];
	private _objlist = [_cfg,"Mission\Entities"] call dml_internal_getPath;
	if isNullVar(_objlist) exitWith {
		_bmap callp(printErr,"Error on get object root tree");
	};

	// Добавляем заголовки только если не в режиме валидации
	if (!(_bmap getv(_validationMode))) then {
		[_bmap] call dml_internal_addMapHeaders;
	};

	private _itCount = _objlist get "items";
	{
		if equalTypes(_y,hashMapNull) then {
			[_y,_bmap] call dml_internal_handleObj;
		};
	} foreach _objlist;
	
};

dml_internal_addMapHeaders = {
	params ["_bmap"];
	private _buffer = _bmap getv(_buffer);

	_buffer pushBack "go_editor_globalRefs = createHashMap;";
	_buffer pushBack endl;
	_buffer pushBack endl;
	private _ecodeInstr = "reditor_binding_fc = {" + toString {
		private _o = _this deleteAt 0;
		private _m = _this deleteAt 0;
		if (count _this == 0) then {
			callFuncReflect(_o,_m)
		} else {
			callFuncReflectParamsInline(_o,_m,_this)
		};
	} + "};
	reditor_binding_gv = {" + toString {
		private _o = _this deleteAt 0;
		private _m = _this deleteAt 0;
		getVarReflect(_o,_m)
	} + "};
	reditor_binding_sv = {" + toString {
		private _o = _this deleteAt 0;
		private _m = _this deleteAt 0;
		setVarReflect(_o,_m,_this)
	} + "};
	reditor_binding_gref = {" + toString {
		private _o = _this deleteAt 0;
		private _m = _this deleteAt 0;
		go_editor_globalRefs getOrDefault [_m,nullPtr];
	} + "};";
	_buffer pushBack _ecodeInstr;
	_buffer pushBack endl;
	_buffer pushBack endl;
};

dml_const_enum_instancerNames = ["InitItem","InitStruct","InitDecor"];
dml_const_tab = toString [9];

dml_internal_handleObj = {
	params ["_mapDat","_bmap"];

	private _dataType = _mapDat get "datatype";//group(mob),object
	private _id = _mapDat getOrDefault ["id","ERR_UNDEFINED"];
	
	//handle layer
	if (_dataType=="layer") exitWith {
		//empty layer skip
		if !("entities" in _mapDat) exitWith {};

		private _objlist = _mapDat get "entities";
		private _atlOffset = _mapDat get "atloffset";
		private _itCount = _objlist get "items";
		traceformat("Loading layer: %1",_mapDat get "name");
		{
			if equalTypes(_y,hashMapNull) then {
				[_y,_bmap] call dml_internal_handleObj;
			};
		} foreach _objlist;
	};

	if (_dataType!="object")exitWith {
		traceformat("Skipped loading id %1 (type %2)",_id arg _dataType);
		true
	};

	#define deserializeHashData(val) (call (call compile val))
	#define sizeof_float 5


	//deser hash: call (call compile _serializedData)
	private _posI = _mapDat get "positioninfo" get "position"; //x,z,y
	private _atlOffset = _mapDat get "atloffset";
	private _rotI = _mapDat get "positioninfo" get "angles";
	private _hashData = _mapDat get "attributes" get "init";
	private _otype = _mapDat get "type"; //normal classname

	private _hd = deserializeHashData(_hashData);
	if ("missionName" in _hd && {_otype == "Land_Orange_01_F"}) exitWith {
		private _mapVersion = _hd get "version";
		traceformat("Map metadata object found, version: %1", _mapVersion);
		
		// В режиме валидации проверяем версию
		if (_bmap getv(_validationMode)) then {
			if (isNil "_mapVersion" || _mapVersion == "") then {
				_bmap callp(printErr, "Map version not specified in metadata");
			};
		};
	};

	if (count _hd == 0) exitWith {
		_bmap callp(printErr,format vec2("Empty data for object with id %1",_id));
	};
	private _class = _hd get "class";
	if !isImplementClass(_class) exitWith {
		_bmap callp(printErr,format vec3("Unknown class %1 for object with id %2",_class,_id));
	};

	private _instancer = dml_const_enum_instancerNames select ([_class,"",true,"getChunkType"] call oop_getFieldBaseValue);
	assert_str(!isNullVar(_instancer),"Unknown chunk type for class " + _class);

	private _counterNotNeedLvar = 0;
	private _realocModel = "";
	private _isEffectModel = false;

	//reassign model
	private _mpath = [_class,"model",true,"getModel"] call oop_getFieldBaseValue;

	if ((_mpath select [0,1]) == "\") then {
		_mpath = _mpath select [1,count _mpath];
	};
	
	private _mPathFromCfg = core_cfg2model getvariable _otype;
	if isNullVar(_mPathFromCfg) exitWith {
		_bmap callp(printErr,format vec3("Cant find model for config %2 with id %1",_id,_otype));	
	};
	
	private _model = ifcheck(".p3d" in _mpath,_mPathFromCfg,_otype);
	if ((_model select [0,1]) == "\") then {
		_model = _model select [1,count _model];
	};
	_isEffectModel = "land_vr_block_" in (tolower _otype);
	if (_mpath != _model && !_isEffectModel) then {
		INC(_counterNotNeedLvar);
		_realocModel = _model;
	};

	// УЛУЧШЕННАЯ КОНВЕРТАЦИЯ ПОЗИЦИЙ И ПОВОРОТОВ
	private _pos = [_posI, _atlOffset] call dml_convertPosition;
	([_rotI] call dml_convertRotation) params ["_vdir", "_vectorDir", "_vup"];

	private _randSpawn = false;
	private _randSpawnString = "";
	private _randPos = false;
	private _randPosString = "";
	private _objcustomdata = [];
	private _initCodeArgs = [];
		private _addPreInitHandler = false;

	if (_realocModel != "") then {
		_initCodeArgs pushBack (format["%1 setvariable ['%2','%3'];",'_thisObj','model',_realocModel]);
	};

	private _customProps = _hd getOrDefault ["customProps",[]];

	//get native preinit vars
	private _sysvars = [];
	private _tObj = typeGetFromString(_class);
	private _arrAdd = null;
	{
		_arrAdd = typeGetVar(typeGetFromString(_x),__handleNativePreInitVars__);
			
		if !isNullVar(_arrAdd) then {
			if equalTypes(_arrAdd,{}) then {
				_sysvars append (call _arrAdd);
			};
		};
		if (_x == "gameobject") then {break};
	} foreach typeGetVar(_tObj,__inhlist);
	_sysvars = _sysvars apply {tolower _x};
	_sysvars = _sysvars arrayintersect _sysvars;
	
	{
		[_x,_y] params ["_name","_val"];

		if (_name == "spawnPointName" && {_class == "SpawnPoint"}) then {
			private _ind = (_bmap getv(_allSpawnPoints)) findif {_x == _val};

			if (_ind != -1) exitWith {
				_bmap callp(printErr,format vec2("SpawnPoint %1 double define",_val));
			};
			if (":" in _val) exitWith {
				_bmap callp(printErr,format vec2("SpawnPoint %1 has wrong name; Unexpected ':'",_val));
			};
			if !("spawnpointname" in _customProps) then {
				_bmap callp(printErr,format vec2("SpawnPoint %1 without 'spawnpointname' property",_val));
			};
			
			(_bmap getv(_allSpawnPoints)) pushBack _val;
			continue;
		};
		if (_name == "spawnPointName" && {_class == "CollectionSpawnPoint"}) then {
			if (":" in _val) exitWith {
				_bmap callp(printErr,format vec2("CollectionSpawnPoint %1 has wrong name; Unexpected ':'",_val));
			};
			if !("spawnpointname" in _customProps) then {
				_bmap callp(printErr,format vec2("CollectionSpawnPoint %1 without 'spawnpointname' property",_val));
			};
			continue;
		};

		//serialize string
		if equalTypes(_val,"") then {_val = str _val};

		if (_name == "model") then {continue};
		if (_name == "light") then {
			//! light can parse only from editor
			private _realVal = _val select [1,count _val - 2];
			private _cfgName = "#ERR#";
			if (is3DEN) then {
				_cfgName = [_realVal,"#ERR#"] call vcom_emit_io_parseScriptedConfigName;
			};
			if (_cfgName != "#ERR#") then {
				if (is3DEN) then {
					if !(call vcom_emit_io_isEnumConfigsLoaded) then {
						[true] call vcom_emit_io_loadEnumAssoc;
					};
					private _idxlight = (keys vcom_emit_io_enumAssocKeyStr) findif {_cfgName==_x};
					if (_idxlight == -1) exitWith {
						_bmap callp(printErr,format vec2("Cant find light %1",_realVal));
						continue;
					};

					_val = format["%1 call lightSys_getConfigIdByName",_val];
				} else {
					_bmap callp(printErr,format vec2("Light validation is not supported in non-editor %1",_realVal));
				};
			} else {
				_bmap callp(printErr,format vec2("Cant resolve light name %1",_realVal));
			};
		};
		if ("@preinit" in _name) then {
			_addPreInitHandler = true;
			_initCodeArgs pushBack (format["%1 setvariable ['%2',%3];",'_thisObj',_name,_val]);
			continue;
		};
		if (tolower _name in _sysvars) then {
			_addPreInitHandler = true;
			_initCodeArgs pushBack (format["%1 setvariable ['%2',%3];",'_thisObj',_name,_val]);
			continue;
		};
		if (_name == "lightIsEnabled" || _name == "light") then {
			_initCodeArgs pushBack (format["%1 setvariable ['%2',%3];",'_thisObj',_name,_val]);
			continue;
		};
		if (_x == "__effinit") then {
			INC(_counterNotNeedLvar);
			_objcustomdata pushBack (format["[%1,%2] call (%1 getvariable '"+PROTOTYPE_VAR_NAME+"' getvariable 'setEffectType');","%1",_val]);
			continue;
		};

		_objcustomdata pushBack (format["%1 setvariable ['%2',%3];","%1",_name,_val]);

	} foreach _customProps;

	private _code_init = _hd get "code_onInit";
	private _tryErrorOnInit = false;
	private _customCodeOnInit = "";
	if !isNullVar(_code_init) exitWith {
		if (is3DEN) then {
			private _retStrCode = [_code_init,false] call golib_code_prepareInstructions;
			if (_retStrCode == "!ERROR!") exitWith {
				_bmap callp(printErr,format vec2("ECode compile error at id %1",_id));
			};

			INC(_counterNotNeedLvar);

			_objcustomdata pushBackUnique "";
			_customCodeOnInit = _retStrCode;
		} else {
			_bmap callp(printErr,format vec2("ECode instructions not supported; Error class %1",_class));
		};
	};

	//* electronic device connection
	private _edConnected = _hd get "edConnected";
	if !isNullVar(_edConnected) then {
		{
			INC(_counterNotNeedLvar);
			_objcustomdata pushBack (format["[%1,go_editor_globalRefs get ""%2""] call (%1 getvariable '"+PROTOTYPE_VAR_NAME+"' getvariable 'addConnection');","%1",_x]);
		} foreach _edConnected;
	};

	//* Container content
	private _containerContent = _hd get "containerContent";
	if !isNullVar(_containerContent) then {
		{
			INC(_counterNotNeedLvar);
			_x params ["_hashItem","_count"];
			_hashItem = deserializeHashData(_hashItem);
			private _stringStruct = format["'%1',%2,%3",_hashItem get "class",_count,_hashItem getOrDefault ["prob",100]];
			private _arrAtrs = [];
			{
				[_x,_y] params ["_key","_val"];
				_arrAtrs pushback ["var",_key,_val];
			} foreach (_hashItem get "customProps");

			if (count _arrAtrs > 0) then {
				_stringStruct = _stringStruct + "," + str _arrAtrs;
			};

			_objcustomdata pushBack (format["[%1,%2] call (%1 getvariable '"+PROTOTYPE_VAR_NAME+"' getvariable 'createItemInContainer');","%1",_stringStruct]);
		} foreach _containerContent;
	};

	if (_tryErrorOnInit) exitWith {};

	// В режиме валидации не генерируем код
	if (_bmap getv(_validationMode)) exitWith {
		_bmap setv(_generated,(_bmap getv(_generated)) + 1);
	};

	private _atlPos = _pos;
	private _poses = ((_atlPos select 0) toFixed sizeof_float) + ((_atlPos select 1) toFixed sizeof_float) + ((_atlPos select 2) toFixed sizeof_float);
	private _varname = "_" + (_poses splitString "-." joinString "_");

	// * Global reference
	private _registeredMark = "";

	if ("rdir" in _hd) then {
		_vdir = "random 360";
	};
	if ("prob" in _hd) then {
		private _val = (_hd get "prob") / 100; //проценты в нормализованные знач.
		_randSpawn = true;
		_randSpawnString = format["if ((random 1) < %1) then {" + endl + dml_const_tab + "%2};" + endl,_val,"%1"];
	};
	if ("rpos" in _hd) then {
		private _val = (_hd get "rpos");
		_randPos = true;
		_randPosString = format["%1 call{__v = _this select [0,3];__r = random 360;__v = __v vectorAdd [sin __r * %2,cos __r * %2,0];if (count _this > 3) then {__v = __v + [true]};__v}","%1",_val];
	};
	if ("mark" in _hd) then {
		_registeredMark = _hd get "mark";
		_initCodeArgs pushBack format["go_editor_globalRefs set [""%1"",%2];",_registeredMark,"_thisObj"] + endl;
	};

	// Дополнительная обработка сложных поворотов
	if not_equals(_vup,vec3(0,0,1)) then {
		_pos = _pos + [true]; // convert poscoords для объектов с нестандартной ориентацией
		
		// Используем реальные векторы направления вместо заглушек
		private _zPosVDir = parseNumber((_vectorDir select 2) toFixed 1);
		private _editedVdir = false;
		if equalTypes(_vdir,"") then {_editedVdir = true}; //if rdir enabled then do not override vdir

		if (_zPosVDir <= -0.85 || _zPosVDir >= 0.85 && !_editedVdir) then {
			_vdir = _vectorDir;
			_editedVdir = true;
		};
	};

	private _addictPost = "";
	if (_realocModel != "") then {
		_addictPost = " ;'REALOC MODEL';";
	};
	if (_isEffectModel) then {
		_addictPost = " ;'EFFECT';";
	};

	if (_addPreInitHandler) then {
		_initCodeArgs pushBack (
			format["%1 call (%1 getvariable '"+PROTOTYPE_VAR_NAME+"' getvariable '__handlePreInitVars__');","_thisObj"]
		)
	};

	//pre init code initializer
	_initCode = if (count _initCodeArgs > 0) then {", {" + (_initCodeArgs joinString " ")+"}"} else {""};

	//* BINARIZE
	if (_counterNotNeedLvar > 0) then {
		//do need create lvar
		if (_randPos) then {
			_pos = format[_randPosString,_pos];
		};	
		
		private _inst = format["['%1',%2,%3,%4%7] call %5; %6" + endl,_class,_pos,_vdir,_vup,_instancer,_addictPost,_initCode];

		if (_randSpawn) then {
			_inst = format[_randSpawnString,_inst];
		};

		(_bmap getv(_buffer)) pushBack format["%1 = %2",_varname,_inst];

		if (count _objcustomdata > 0) then {
			private _buffEnd = _bmap getv(_bufferEnd);
			_buffEnd pushBack format["if (!isNil'%1') then {" + endl,_varname];

			{
				_buffEnd pushBack (dml_const_tab + format[_x,_varName] + endl);
			} foreach _objcustomdata;

			

			if (_customCodeOnInit != "") then {
				_buffEnd pushBack ("_o="+_varName+";"+endl);
				_buffEnd pushBack (_customCodeOnInit + endl);
			};
			
			_buffEnd pushBack ("};" + endl);
		};

	} else {

		if (_randPos) then {
			_pos = format[_randPosString,_pos];
		};

		private _inst = format["['%1',%2,%3,%4%7] call %5; %6" + endl,_class,_pos,_vdir,_vup,_instancer,_addictPost,_initCode];

		if (_randSpawn) then {
			_inst = format[_randSpawnString,_inst];
		};

		//not need create lvar
		(_bmap getv(_buffer)) pushBack _inst;
	};

	_bmap setv(_generated,(_bmap getv(_generated)) + 1);
};

dml_internal_getPath = {
	params ["_cfg","_pathList"];
	if equalTypes(_pathList,"") then {
		_pathList = _pathList splitString " \/.:>";
	};
	private _curcfg = _cfg;
	private _key = null;
	{
		_key = toLowerANSI _x;
		if !(_key in _curcfg) exitWith {_curcfg = null};
		_curcfg = _curcfg get _key;
	} foreach _pathList;
	_curcfg
};

dml_prepMapConfig = {
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
		_result set [toLowerANSI configName _x, _x call dml_prepMapConfig];
	} forEach _classes;

	_result;
};