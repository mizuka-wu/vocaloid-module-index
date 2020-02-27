////////////////////////////////////////////////////////////////////////////////////////////////
//
//	ごった煮オブジェクトシェーダ ver1.0
//	作った人： ビームマンP
//  ベース：
//	ソフトライトHLシェーディング ver1.3.1
//  ふゅりあ
//	full_SimpleSoftShadow_ex
//	ビームマンP
//	MechanicFull
//	ビームマンP
//
////////////////////////////////////////////////////////////////////////////////////////////////

//熊音さん用追加パラメータ
float PowParam = 1.3;
float MulParam = 1.17;
float AddParam = -0.05;

//---ソフトシャドウ用パラメータ---//
//ソフトシャドウ明るさ補正
float LightParam = 1;
//ソフトシャドウ用ぼかし率
float SoftShadowParam = 1;
//シャドウマップサイズ
//通常：1024 CTRL+Gで解像度を上げた場合 4096
#define SHADOWMAP_SIZE 1024


float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "sceneorobject";
	string ScriptOrder = "standard";
> = 0.8;
    
// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix               : VIEW;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
float4   EdgeColor         : EDGECOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

bool     parthf;   // パースペクティブフラグ
bool     transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     1

float4	 EgColor;			// アクセサリ用アンビエント色

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE</*
	int Width = 512;
	int Height = 512;*/
	int MipLevels = 0;
//	string Format = "A8R8G8B8" ;
>;
sampler DefObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

texture UseMipmapObjectTexture : RENDERCOLORTARGET <
	int Width = 512;
	int Height = 512;
	int MipLevels = 0;
	string Format = "A8R8G8B8" ;
>;
sampler ObjTexSampler = sampler_state {
	texture = <UseMipmapObjectTexture>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = LINEAR;
	MAXANISOTROPY = 16;
};

texture2D DepthBuffer : RenderDepthStencilTarget <
	int Width = 512;
	int Height = 512;
	string Format = "D24S8";
>;

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

//--各種マップテクスチャ
#define ANISO_NUM 16
//スペキュラマップ
texture2D SpMap <
    string ResourceName = "SpMap.png";
    int MipLevels = 8;
>;
sampler SpMapSamp = sampler_state {
    texture = <SpMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
    AddressU  = WRAP;
    AddressV = WRAP;
};
texture2D HeightMap <
    string ResourceName = "HeightMap.png";
    int MipLevels = 8;
>;
sampler HeightMapSamp = sampler_state {
    texture = <HeightMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
    AddressU  = WRAP;
    AddressV = WRAP;
};
texture2D NormalMap <
    string ResourceName = "NormalMap.png";
    int MipLevels = 8;
>;
sampler NormalMapSamp = sampler_state {
    texture = <NormalMap>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = ANISOTROPIC;
	
	MAXANISOTROPY = ANISO_NUM;
    AddressU  = WRAP;
    AddressV = WRAP;
};



// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;

//ソフトライト合成関数
float3 SoftLight(float3 fg , float3 bg){
	float3 under  = bg+(bg-pow(bg,2.0))*(2.0f*fg-1.0f);
	float3 middle = bg+(bg-pow(bg,2.0f))*(2.0f*fg-1.0f)*(3.0f-8.0f*bg);
	float3 upper  = bg+(pow(bg,0.5f)-bg)*(2.0f*fg-1.0f);

	const float bgLimit = 32.0f / 255.0f;
	
	float3 Dst = (float3)0;
	
	Dst.r = fg.r < 0.5f ? under.r : bg.r <= bgLimit ? middle.r : upper.r;
	Dst.g = fg.g < 0.5f ? under.g : bg.g <= bgLimit ? middle.g : upper.g;
	Dst.b = fg.b < 0.5f ? under.b : bg.b <= bgLimit ? middle.b : upper.b;

	return Dst;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ミップマップ作成

struct VS_OUTPUT_MIPMAPCREATER {
    float4 Pos	: POSITION;
    float2 Tex	: TEXCOORD0;
};
VS_OUTPUT_MIPMAPCREATER VS_MipMapCreater( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT_MIPMAPCREATER Out;
    Out.Pos = Pos;
    Out.Tex = Tex;
    Out.Tex += ViewportOffset;
    return Out;
}

float4  PS_MipMapCreater(float2 Tex: TEXCOORD0) : COLOR0
{
	return tex2D(DefObjTexSampler,Tex);
}

// 輪郭描画

// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
    // 輪郭色で塗りつぶし
    return EdgeColor;
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge {
        AlphaBlendEnable = FALSE;
        AlphaTestEnable  = FALSE;

        VertexShader = compile vs_2_0 ColorRender_VS();
        PixelShader  = compile ps_2_0 ColorRender_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
    // カメラ視点のワールドビュー射影変換
    return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
    // アンビエント色で塗りつぶし
    return float4(AmbientColor.rgb, 0.65f);
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 法線計算関数

float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float3 Eye        : TEXCOORD3;   // カメラとの相対位置
    float2 SpTex      : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color      : COLOR0;      // ディフューズ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color *= tex2D(ObjSphareSampler,IN.SpTex);
    }
    
    if ( useToon ) {
        // トゥーン適用
        float LightNormal = dot( IN.Normal, -LightDirection );
        Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 5 + 0.5));
    }
    
    float diffContrib = dot( normalize(IN.Normal) , -LightDirection) * 0.5 +0.5;
	
	float RimPower = max( 0.0f, dot( -normalize(IN.Eye), -LightDirection ) );
	float Rim = 1.0f - max( 0.0f, dot( normalize(IN.Normal),normalize(IN.Eye)) );
	diffContrib += Rim*RimPower;
	
	diffContrib = pow(diffContrib,1.0f/0.75);
	
	float3 mColor = diffContrib * Color;
	float3 sColor = SoftLight( diffContrib * 0.75f, Color);
	
	//彩度取得
	float Imax,Imin;
	Imax = max(Color.r , max(Color.g , Color.b ));
	Imin = min(Color.r , min(Color.g , Color.b ));
	
	//HSV 彩度
	float s = (Imax-Imin) / Imax;
	
	s = s/2.0f;
	s = pow(s,1.0f/0.5f);
	
	Color.rgb = lerp(sColor,mColor,s);

    // スペキュラ適用
    Color.rgb += Specular;
    
    return Color;
}

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
}

technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false;
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false;
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
    }
}

technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; 
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
    }
}

technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
    }
}

technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; 
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
    VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
    // R色成分にZ値を記録する
    return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 ZValuePlot_VS();
        PixelShader  = compile ps_2_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0) ;

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
//    float4 Color    : COLOR0;       // ディフューズ色
    float4 WorldPos		: TEXCOORD5;
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	//初期座標保存
	Out.WorldPos = mul(Pos,WorldMatrix);
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
    
    /*
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );
    */
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    if ( useSphereMap ) {
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }
    
    return Out;
}
float time : TIME;
// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
	//視線ベクトルの正規化
	float3 Eye = normalize(CameraPosition-IN.WorldPos);
	/*
	//高さマップ処理
	IN.Tex = IN.Tex - Eye.xy * tex2D( HeightMapSamp, IN.Tex) * 0.001;
    */
	float Height = tex2D( HeightMapSamp, IN.Tex).r;
	
    //法線マップ処理
    float4 NormalColor = tex2D( NormalMapSamp, IN.Tex)*2;	
	NormalColor = NormalColor.rgba;
	NormalColor.a = 1;
	float3x3 tangentFrame = compute_tangent_frame(IN.Normal, Eye, IN.Tex);
	IN.Normal = normalize(mul(NormalColor - 1.0f, tangentFrame));
    
    float4 Color = float4(1,1,1,MaterialDiffuse.a);
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color = TexColor;
        ShadowColor *= TexColor;
    }
    if ( useSphereMap ) {
        // スフィアマップ適用
        float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
        if(spadd) {
            Color.rgb += TexColor.rgb;
            ShadowColor.rgb += TexColor.rgb;
        } else {
            Color *= TexColor;
            ShadowColor *= TexColor;
        }
    }
    

    // スペキュラ色計算
    float3 HalfVector = normalize( Eye + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * Color.rgb * 0.1;
    Specular *= tex2D(SpMapSamp,IN.Tex).r;
    //return float4(Specular,1);
    // スペキュラ適用
	ShadowColor.rgb += Specular;
	//Color.rgb = 1;    
	//Zテクスチャ作り直し
	float4 WP = IN.WorldPos;
	WP.xyz += IN.Normal*Height*0.1;
    
    IN.ZCalcTex = mul( WP, LightWorldViewProjMatrix );
    
    // テクスチャ座標に変換
    IN.ZCalcTex /= IN.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
    
    if( any( saturate(TransTexCoord) != TransTexCoord ) ) {
        // シャドウバッファ外
        float comp = 1;
        float4 ans;
        if(useToon){
        	comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
        
			ans = ShadowColor * (comp+float4(MaterialToon,1)*(1-comp)) +  float4(Specular,0) * comp;
			
			float diffContrib = dot( normalize(IN.Normal) , -LightDirection) * 0.5 +0.5;
			
		    float RimPower = max( 0.0f, dot( -normalize(Eye), -LightDirection ) );
		    float Rim = 1.0f - max( 0.0f, dot( normalize(IN.Normal),normalize(Eye)) );
		    diffContrib += Rim*RimPower;
		    
		    diffContrib = pow(diffContrib,1.0f/0.75);
		    
			float3 mColor = diffContrib * ans;
			float3 sColor = SoftLight( diffContrib * 0.75f, ans);

			//彩度取得
			float Imax,Imin;
			Imax = max(ans.r , max(ans.g , ans.b ));
			Imin = min(ans.r , min(ans.g , ans.b ));
			
			//HSV 彩度
			float s = (Imax-Imin) / Imax;

			s = s/2.0f;
			s = pow(s,1.0f/0.5f);

        	ans.rgb = lerp(sColor,mColor,s);
        	
        }else{
       		ans = (EgColor + MaterialDiffuse * pow(dot(normalize(IN.Normal), -LightDirection ) *0.5+0.5,1/0.5));
       		ans = (ans*Color + float4(Specular,0))*comp + EgColor*Color*(1-comp);
        }
        
        ans.rgb = pow(ans.rgb * MulParam + AddParam,PowParam) + AddParam;
        
        return ans;
    } else {
        float comp = 0;
		float U = SoftShadowParam / SHADOWMAP_SIZE;
		float V = SoftShadowParam / SHADOWMAP_SIZE;
        if(parthf) {
            // セルフシャドウ mode2
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
        } else {
            // セルフシャドウ mode1
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,0)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(0,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(-U,-V)).r , 0.0f)*SKII1-0.3f);
	        comp += saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord+float2(U,-V)).r , 0.0f)*SKII1-0.3f);
        }
        comp = 1-saturate(comp/9);
        if ( useToon ) {
            // トゥーン適用
            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            //ShadowColor.rgb *= MaterialToon;
        }
        
        /*
        float4 ans = lerp(ShadowColor, Color, comp);
        if( transp ) ans.a = 0.5f;
        */
        float4 ans;
        if(useToon){
			ans = ShadowColor * (comp+float4(MaterialToon,1)*(1-comp)) +  float4(Specular,0) * comp;
			
			float diffContrib = dot( normalize(IN.Normal) , -LightDirection) * 0.5 +0.5;
			
		    float RimPower = max( 0.0f, dot( -normalize(IN.Eye), -LightDirection ) );
		    float Rim = 1.0f - max( 0.0f, dot( normalize(IN.Normal),normalize(IN.Eye)) );
		    diffContrib += Rim*RimPower;
		    
		    diffContrib = pow(diffContrib,1.0f/0.75);
		    
			float3 mColor = diffContrib * ans;
			float3 sColor = SoftLight( diffContrib * 0.75f, ans);

			//彩度取得
			float Imax,Imin;
			Imax = max(ans.r , max(ans.g , ans.b ));
			Imin = min(ans.r , min(ans.g , ans.b ));
			
			//HSV 彩度
			float s = (Imax-Imin) / Imax;

			s = s/2.0f;
			s = pow(s,1.0f/0.5f);

        	ans.rgb = lerp(sColor,mColor,s);
        	
        }else{
       		ans = (EgColor + MaterialDiffuse * pow(dot(normalize(IN.Normal), -LightDirection ) *0.5+0.5,1/0.5));
       		ans = (ans*Color + float4(Specular,0))*comp + EgColor*Color*(1-comp);
        }
        ans.rgb = pow(ans.rgb * MulParam + AddParam,PowParam) + AddParam;
        return ans;
    }
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; 
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
    }
}

technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; 
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
    }
}

technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true;
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
    }
}

technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
    }
}

technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true;
	string Script= 
		"RenderColorTarget0=UseMipmapObjectTexture;"
			"RenderDepthStencilTarget=DepthBuffer;"
				"ClearSetColor=ClearColor;"
				"ClearSetDepth=ClearDepth;"
				"Clear=Color;"
				"Clear=Depth;"
			"Pass=CreateMipmap;"
		"RenderColorTarget0=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawObject;"
		;
 > {
	pass CreateMipmap < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable = FALSE;
		ZEnable = FALSE;
		VertexShader = compile vs_2_0 VS_MipMapCreater();
		PixelShader  = compile ps_2_0 PS_MipMapCreater();
	}
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
