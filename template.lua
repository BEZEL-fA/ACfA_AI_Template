--[[
@brief Arena_AI_Template
@author BEZEL
@ver0.98
]]--

--//////////////////////////////////////////////////////////////////////////////////
--Section 01 Definition ////////////////////////////////////////////////////////////

--▼依存ファイル
LoadAIStdScriptFile(CURR_DLLUA_INSTANCE);

--▼可変定数(ここを弄って調節)
InitSelf =
{
	legs = 0; --脚部カテゴリ
	firstap = 29396; --初期AP
}

Track = --捕捉用
{
	dist = 4000;
	angle = 360;
};

Distanse = --距離による挙動変更用
{
	long = 400;
	short = 150;
};

Threshold = --しきい値、ACAIParam.binの移植
{
	energy = 
	{
		goair = 0; --空中に行こうとするエネルギー閾値
		goground = 0; --空中にい続けることを断念するエネルギー閾値
		qt = 0; --ターンブーストするときのエネルギー閾値
	};
	angle = 
	{
		qt = 45; --ターンブースト判定する正面からの角度
	}
};

Ct_vartime_limit = 10; --パラメータの差分を出す間隔

--▼特殊定数
Front = 1;
Right = 2;
Left = 3;
Back = 4;

R_hand = 1;
R_back = 2;
L_hand = 3;
L_back = 4;
Shoulder = 5;

--▼カウンタ
Ct_jump_walk = 0; --jumpとwalkの頻度の切り替え
Ct_vartime = 10; --相対変化量を算出するために使うカウンタ。フレーム指定

--▼フラグ
Initset = true; --trueの時だけ初期のパラメータ取得処理を行う
Operation = false; --trueは攻めオペレーション、falseは引きオペレーション

--変数
Initenemy = --初期の敵パラメータ
{
	legs = 0; --脚部カテゴリ
	firstap = 0; --初期AP
	firsten = 0; --初期EN
	firstpa = 0; --初期PA
	weapon = --武器カテゴリ
	{
		raw = 0;
		law = 0;
		rbw = 0;
		lbw = 0;
	};
};


Now = --現在のパラメータ
{
	self = --自機パラメータ
	{
		ap = 0; --AP実数値
		aprate = 0; --AP率
		enrate = 0; --EN率
		parate = 0; --PA率
		yaw = 0; --自機から見た敵機の横の角度
		pitch = 0; --自機から見た敵機の縦の角度
		alt_g = 0; --地面との距離

		islocked = false; --ロックされているか
	};
	enemy = --敵機パラメータ
	{
		ap = 0;
		aprate = 0;
		en = 0;
		enrate = 0;
		pa = 0;
		parate = 0;
		yaw = 0; --敵機から見た自機の横の角度

		islocked = { --ロックされているか
			raw = false;
			law = false;
			rbw = false;
			lbw = false;
		};
	};
	relative = --相対パラメータ
	{
		xz = 0; --敵機とのxz距離
		alt = 0; --敵機とのy距離
		dist = 0; --敵機との直線距離
		apgap = 0; --敵機とのAP差
	};
};

Prev = --以前のパラメータ
{
	self = --自機パラメータ
	{
		yaw = 0; --自機から見た敵機の横の角度
		pitch = 0; --自機から見た敵機の縦の角度
	};
	enemy = --敵機パラメータ
	{
		yaw = 0; --敵機から見た自機の横の角度
	};
	relative = --相対パラメータ
	{
		xz = 0; --敵機とのxz距離
		alt = 0; --敵機とのy距離
		dist = 0; --敵機との直線距離
		apgap = 0; --敵機とのAP差
	};
};

Variation = --変化量
{
	self = --自機パラメータ
	{
		yaw = 0; --自機から見た敵機の横の角度
		pitch = 0; --自機から見た敵機の縦の角度
	};
	enemy = --敵機パラメータ
	{
		yaw = 0; --敵機から見た自機の横の角度
	};
	relative = --相対パラメータ
	{
		xz = 0; --敵機とのxz距離
		alt = 0; --敵機とのy距離
		dist = 0; --敵機との直線距離
		apgap = 0; --敵機とのAP差
	};
};

Ammo = --残弾数
{
	self = 
	{
		raw = 100;
		law = 100;
		rbw = 100;
		lbw = 100;
	};
	enemy = 
	{
		raw = 100;
		law = 100;
		rbw = 100;
		lbw = 100;
	}
};

--Section 01 End ///////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////
--Section 02 Original Functions ////////////////////////////////////////////////////

--▼敵機から見た自分のyawを取得する
function GetTargetToSelfYaw(context)
	local yaw = -180;
	while (SelfIsInTargetPartialSphere(context, 90, -90, yaw + 1, yaw) == false) do
			yaw = yaw + 1;
	end
	return yaw;
end

--▼自分から見た敵機のyawを取得する
function GetSelfToTargetYaw(context)
	local yaw = -180;
	while (IsInTargetPartialSphere(context, 90, -90, yaw + 1, yaw) == false) do
			yaw = yaw + 1;
	end
	return yaw;
end

--▼自分から見た敵機のpitchを取得する
function GetSelfToTargetPitch(context)
	local pitch = -90;
	while (IsInTargetPartialSphere(context, pitch + 1, pitch, -180, 180) == false) do
			pitch = pitch + 1;
	end
	return pitch;
end

--▼自分の下の地面自体の絶対高度を取得する
function GetGroundAltitude(context)
	local enalt = GetEntityAltitude(context, 0);
	local relalt = GetToTargetAltitude(context);
	local mygalt = GetAltitudeGroundRelation(context);
	local alt = enalt - relalt - mygalt;
	return alt;
end

--▼通常QTを利用可能にする
function SetEnableNomalQT(context, nowyaw, maxyaw, minyaw)
	if (nowyaw < minyaw or nowyaw > maxyaw) then
		SetEnableTurnToTarget(context, true);
		if (nowyaw <= 0) then
			return 2; --左向きQTを利用した
		else
			return 3; --右向きQTを利用した
		end
	else
		SetEnableTurnToTarget(context, false);
		return 1; --QTを利用しなかった
	end
end

--▼開発中の関数

--▼予測QTを利用可能にする(QT反応角が0の場合に有効) QT旋回中は発動しない minYaw~maxYaw内でQT発動
function SetEnablePredictQT(context, prevyaw, nowyaw, minyaw, maxyaw) --Yaw*2<<実際のQT旋回角が理想。LAHIRE脚の場合は30°以内が良い
	local yaw_var = nowyaw - prevyaw;
	if (yaw_var > 1 or yaw_var < -1) then --Yaw変化量が大きい場合はQTしない 変な動きをするならここを弄る
		SetEnableTurnToTarget(context, false);
		return 1; --QTを利用しなかった
	elseif (nowyaw <= maxyaw and nowyaw >= minyaw) then
		SetEnableTurnToTarget(context, true);
		if (nowyaw <= 0) then
			return 2; --左向きQTを利用した(右側扱い)
		else
			return 3; --右向きQTを利用した(左側扱い)
		end
	end
end

--▲

--Section 02 End ///////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////
--Section 03 Initialize ////////////////////////////////////////////////////////////

--▼スクリプト初期化
function InitialSetup(context)
	--▼オペレーションレイヤー作成
	--▼移動
	AddInitialLayer_EveryFrame(context, "InitMove", "Move");
	--▼攻撃
    AddInitialLayer_EveryFrame(context, "Init_R_Attack", "R_Attack");
	AddInitialLayer_EveryFrame(context, "Init_L_Attack", "L_Attack");
	AddInitialLayer_EveryFrame(context, "Init_S_Attack", "S_Attack");
	
	--▼基本設定/高度調整
	DefaultSetup(context, true);
	SetAltitudeParam(context, 0, 40);
	SetAdjustAltitudeBase(context, ADJUST_ALTITUDE_BASE__TARGET_RELATIVE);
	--▼ブースト
	SetEstimation_WalkDashRate(context, 0, 0);
	SetEstimation_BoostEnableEnergyRange(context, 0, 1, 1, 1);
	
	--▼ジャンプ     
	SetTimeLengthJump(context, 1, 0);
	--▼ターゲット補足関数
	Targetting_CatchUpWithConeInSide(context, Track.dist, Track.angle);
end

--▼初期化
RegistInitializeFuncitonName("InitialSetup");

--Section 03 End ///////////////////////////////////////////////////////////////////
--//////////////////////////////////////////////////////////////////////////////////
--Section 04 Movements /////////////////////////////////////////////////////////////

--▼移動系
function InitMove(context)
	LogAI("AI(Movement) Initialzed");
end

--▼移動系本体
function Move(context)
	--▼初期値獲得/一度だけ実行される
	if (Initset == true) then
		--▼初期状態獲得/敵機
		Initenemy.legs = GetEntityLegCategory(context, 0);
		Initenemy.firstap = GetEntityAP(context, 0);
		Initenemy.firsten = GetEntityEnergy(context, 0);
		Initenemy.firstpa = GetEntityPAStability(context, 0);

		Initenemy.weapon.raw = GetEntityMainWeaponCategory(context, 0);
		Initenemy.weapon.law = GetEntitySubWeaponCategory(context, 0);
		Initenemy.weapon.rbw = GetEntity3rdWeaponCategory(context, 0);
		Initenemy.weapon.lbw = GetEntity4thWeaponCategory(context, 0);

		--**自機の基本項目設定 通常は上書きされる**--
		--▼ブーストレンジ設定
		SetEstimation_BoostEnableEnergyRange( context , 0 , 1 , 1 , 1 );
		--▼歩き/走り設定
		SetEstimation_WalkDashRate( context , 1 , 0 );
		--▼ジャンプ設定
		SetTimeLengthJump( context , 1, 0 );

		Initset = false;

		--▼初期APやPAなどが把握できない場合、ここに計算式を入れてもよい

		--▲
	end

	--▼ターゲット捕捉時
	if (IsExistTarget(context)) then

		--**Get Parameter**--
		--▼状態取得/自機
		Now.self.aprate = GetMyApRate(context);
		Now.self.ap = InitSelf.firstap * Now.self.aprate; --最初のAPにレートを乗算する
		Now.self.enrate = GetMyEnergyRate(context);
		Now.self.parate = GetMyPaRate(context);
		Now.self.yaw = GetSelfToTargetYaw(context);
		Now.self.pitch = GetSelfToTargetPitch(context);
		Now.self.alt_g = GetAltitudeGroundRelation(context);

		Now.self.islocked = HasPerfectLockedByTarget(context);

		Ammo.self.raw = GetBulletRestMySelf(context, WEAPON_ID__MAIN);
		Ammo.self.law = GetBulletRestMySelf(context, WEAPON_ID__SUB);
		Ammo.self.rbw = GetBulletRestMySelf(context, WEAPON_ID__THIRD);
		Ammo.self.lbw = GetBulletRestMySelf(context, WEAPON_ID__FOURTH);

		--▼状態取得/敵機
		Now.enemy.ap = GetEntityAP(context, 0);
		Now.enemy.aprate = GetEntityAPRate(context, 0);
		Now.enemy.en = GetEntityEnergy(context, 0);
		Now.enemy.enrate = GetEntityEnergyRate(context, 0);
		Now.enemy.pa = GetEntityPAStability(context, 0);
		Now.enemy.parate = GetEntityPAStabilityRate(context, 0);
		Now.enemy.yaw = GetTargetToSelfYaw(context);

		Now.enemy.islocked.raw = WeaponIsLocked(context, WEAPON_ID__MAIN);
		Now.enemy.islocked.law = WeaponIsLocked(context, WEAPON_ID__SUB);
		Now.enemy.islocked.rbw = WeaponIsLocked(context, WEAPON_ID__THIRD);
		Now.enemy.islocked.lbw = WeaponIsLocked(context, WEAPON_ID__FOURTH);

		Ammo.enemy.raw = GetEntityMainWeaponBulletRest(context, 0);
		Ammo.enemy.law = GetEntitySubWeaponBulletRest(context, 0);
		Ammo.enemy.rbw = GetEntity3rdWeaponBulletRest(context, 0);
		Ammo.enemy.lbw = GetEntity4thWeaponBulletRest(context, 0);

		--▼状態取得/相対
		Now.relative.xz = GetToTargetDistanceXZ(context);
		Now.relative.alt = GetToTargetAltitude(context);
		Now.relative.dist = GetToTargetDistance(context);
		Now.relative.apgap = Now.self.ap - Now.enemy.ap; --+だとgood

		--**Get Variation and Set Prev**--
		if(Prev.self.ap ~= 0 and Ct_vartime >= Ct_vartime_limit) then --初期のPrevを読み込まないようにする
			Variation.self.yaw = Now.self.yaw - Prev.self.yaw;
			Variation.self.pitch = Now.self.pitch - Prev.self.pitch;
			Variation.enemy.yaw = Now.enemy.yaw - Prev.enemy.yaw;
			Variation.relative.xz = Now.relative.xz - Prev.relative.xz;
			Variation.relative.alt = Now.relative.alt - Prev.relative.alt;
			Variation.relative.dist = Now.relative.dist - Prev.relative.dist;
			Variation.relative.apgap = Now.relative.apgap - Prev.relative.apgap;

			Prev.self.yaw = Now.self.yaw;
			Prev.self.pitch = Now.self.pitch;
			Prev.enemy.yaw = Now.enemy.yaw;
			Prev.relative.xz = Now.relative.xz;
			Prev.relative.alt = Now.relative.alt;
			Prev.relative.dist = Now.relative.dist;
			Prev.relative.apgap = Now.relative.apgap;
		end

		--**Boost Operation / Line Operation**--

		--**Quick Boost Qperation**--

		--**Counter**--
		Ct_vartime = Ct_vartime + 1;

	--▼ターゲット非捕捉時
	else
	end

	--Section 04 End ///////////////////////////////////////////////////////////////////
	--//////////////////////////////////////////////////////////////////////////////////
	--Section 05 ATTACK ////////////////////////////////////////////////////////////////

	--▼右攻撃系
	function Init_R_Attack()
		--
	end

	--▼右攻撃系本体
	function R_Attack(context)

	end

	--▼左攻撃系
	function Init_L_Attack()
		--
	end

	--▼左攻撃系本体
	function L_Attack(context)

	end

	--▼肩攻撃系
	function Init_S_Attack()
		--
	end

	--▼肩攻撃系本体
	function S_Attack(context)

	end




end
