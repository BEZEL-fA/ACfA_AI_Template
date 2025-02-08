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
Initparam =
{
	ap = 29396;
	legs = 0;
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

--▼フラグ
Initset = true; --0の時だけ初期のパラメータ取得処理を行う

--変数
Static = --安定パラメータ
{
	self = 
	{
		legs = 0; --脚部カテゴリ
		firstap = 0; --初期AP
	};
	enemy = 
	{
		legs = 0;
		firstap = 0; --初期AP
	};
};


Now = --現在のパラメータ
{
	self = --自機パラメータ
	{
		ap = 0; --AP実数値
		aprate = 0; --AP率
		en = 0; --EN実数値
		enrate = 0; --EN率
		PA = 0; --PA実数値
		parate = 0; --PA率
		yaw = 0; --自機から見た敵機の横の角度
		pitch = 0; --自機から見た敵機の縦の角度
		alt_g = 0; --地面との距離
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
		pitch = 0; --敵機から見た自機の縦の角度
		alt_g = 0;
	};
	relative = --相対パラメータ
	{
		xz = 0; --相手とのxz距離
		alt = 0; --相手とのy距離
		dist = 0; --相手との直線距離
	};
};

Prev = --以前のパラメータ
{
	self = --自機パラメータ
	{
		ap = 0; --AP実数値
		aprate = 0; --AP率
		en = 0; --EN実数値
		enrate = 0; --EN率
		PA = 0; --PA実数値
		parate = 0; --PA率
		yaw = 0; --自機から見た敵機の横の角度
		pitch = 0; --自機から見た敵機の縦の角度
		alt_g = 0; --地面との距離
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
		pitch = 0; --敵機から見た自機の縦の角度
		alt_g = 0;
	};
	relative = --相対パラメータ
	{
		xz = 0; --相手とのxz距離
		alt = 0; --相手とのy距離
		dist = 0; --相手との直線距離
	};
};

Variation = --相対変化量
{
	self = --自機パラメータ
	{
		ap = 0; --ap変化量
		aprate = 0; --AP率変化量
		en = 0; --EN変化量
		enrate = 0; --EN率変化量
		PA = 0; --PA変化量
		parate = 0; --PA率変化量
		yaw = 0; --自機から見た敵機の横の角度
		pitch = 0; --自機から見た敵機の縦の角度
		alt_g = 0; --地面との距離
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
		pitch = 0; --敵機から見た自機の縦の角度
		alt_g = 0;
	};
	relative = --相対パラメータ
	{
		xz = 0; --相手とのxz距離
		alt = 0; --相手とのy距離
		dist = 0; --相手との直線距離
	};
}

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

--▼敵機から見た自分のpitchを取得する
function GetTargetToSelfPitch(context)
	local pitch = -90;
	while (SelfIsInTargetPartialSphere(context, pitch + 1, pitch, -180, 180) == false) do
			pitch = pitch + 1;
	end
	return pitch;
end

--▼自分から見た敵機のpitchを取得する
function GetSelfToTargetPitch(context)
	local pitch = -90;
	while (IsInTargetPartialSphere(context, pitch + 1, pitch, -180, 180) == false) do
			pitch = pitch + 1;
	end
	return pitch;
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

--移動系本体
function Move(context)
	--▼初期値獲得/一度だけ実行される
	if (Initset == true) then
		--▼初期状態獲得/自機
		Static.self.legs = Initparam.legs
		Static.self.firstap = GetEntityAP(context, 1000); --間違ってるかも？ 自分の実数値を取得できないかも
		--▼初期状態獲得/敵機
		Static.enemy.legs = GetEntityLegCategory(context, 0);
		Static.self.firstap = GetEntityAP(context, 0);
		Initset = false;

		--▼初期APやPAなどが把握できない場合、ここに計算式を入れてもよい

		--▲
	end

	--▼ターゲット捕捉時
	if (IsExistTarget(context)) then

		--**Get Parameter**--
		--▼状態取得/自機
		Now.self.ap = GetEntityAP(context, 1000); --間違ってるかも？ 自分の実数値を取得できないかも
		Now.self.aprate = GetMyApRate(context);
		Now.self.en = GetEntityEnergy(context, 1000); --間違ってるかも？ 自分の実数値を取得できないかも
		Now.self.enrate = GetMyEnergyRate(context);
		Now.self.pa = GetEntityPAStability(context, 1000); --間違ってるかも？ 自分の実数値を取得できないかも
		Now.self.parate = GetMyPaRate(context);
		Now.self.yaw = GetSelfToTargetYaw(context);
		Now.self.pitch = GetSelfToTargetPitch(context);
		Now.self.alt_g = GetAltitudeGroundRelation(context);

		--▼状態取得/敵機
		Now.enemy.ap = GetEntityAP(context, 0);
		Now.enemy.aprate = GetEntityAPRate(context, 0);
		Now.enemy.en = GetEntityEnergy(context, 0);
		Now.enemy.enrate = GetEntityEnergyRate(context, 0);
		Now.enemy.pa = GetEntityPAStability(context, 0);
		Now.enemy.parate = GetEntityPAStabilityRate(context, 0);
		Now.enemy.yaw = GetTargetToSelfYaw(context);
		Now.enemy.pitch = GetTargetToSelfPitch(context);

		--▼状態取得/相対
		Now.relative.xz = GetToTargetDistanceXZ(context);
		Now.relative.alt = GetToTargetAltitude(context);
		Now.relative.dist = GetToTargetDistance(context);

		--****--





	--▼ターゲット非捕捉時
	else
	end
end
