////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SeriousShaderM.fx v0.21
//  データP
//  full.fx v1.2(舞力介入P)をベースに改変
//  質感向上: MipmapTexture＆AnisotropicFilter Furia氏
//  VSM: SpotLight2 そぼろ氏
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define ShadowDarkness 1.6		// セルフシャドウの最大暗さ
#define UnderSkinDiffuse 0.1	// 皮下散乱
#define ToonPower	0.6			// 影の暗さ
#define OverBright	1.2			// 白飛びする危険性をおかして明るくする。

// テクスチャ改善バッファサイズ
#define TEXBUFFWIDTH 512
#define TEXBUFFHEIGHT 512
#define TEXBUFFSIZE { TEXBUFFWIDTH, TEXBUFFHEIGHT }

// ソフトシャドウ 補正係数
#define SOFTSHADOW_DISTANCE 0.1	// ソフトシャドウを打ち切る距離(小さいほど遠い)
#define SOFTSHADOW_THRESHOLD 0.0006 // ソフトシャドウ補正値 大きいほど影が薄い

// シャドウマップサイズ
#define SHADOWMAP_WIDTH 4048
#define SHADOWMAP_HEIGHT 4048

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

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler OrgObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


// テクスチャの質感向上用Mipmap
texture UseMipmapObjectTexture : RENDERCOLORTARGET <
	int2 Dimensions = TEXBUFFSIZE;
	int MipLevels = 0;
>;

// テクスチャの質感向上 異方性フィルタ
sampler ObjTexSampler = sampler_state {
	texture = <UseMipmapObjectTexture>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = LINEAR;
	MAXANISOTROPY = 16;
};

// UseMipmapObjectTexture用深度バッファ
texture UMOTDepth : RENDERDEPTHSTENCILTARGET <
	int2 Dimensions = TEXBUFFSIZE;
>;

const static float2 MipmapOffset = {0.5/TEXBUFFWIDTH, 0.5/TEXBUFFHEIGHT};
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1;

////////////////////////////////////////////////////////////////////////////////////////////////
// テクスチャコピー
struct VS_OUT_COPYTEX {
    float4 Pos	: POSITION;
    float2 Tex	: TEXCOORD0;
};
VS_OUT_COPYTEX CopyTex_VS( float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float2 TexOffset ){
	VS_OUT_COPYTEX o;
	o.Pos = Pos;
	o.Tex = Tex + TexOffset;
	return o;
}

float4 CopyTex_PS(float2 Tex: TEXCOORD0, uniform sampler TexSampler) : COLOR0 {
	return tex2D(TexSampler,Tex);
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
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
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
    float comp = 1;
    if(useToon){
		comp = dot(IN.Normal,-LightDirection);
		ShadowColor.rgb *= pow(MaterialToon,ToonPower);
		Color.rgb*=OverBright;
	}

    comp*= (comp>=0) ? 1.0 : ShadowDarkness -1.0;
	Color = lerp(ShadowColor, Color, comp);

    // スペキュラ適用
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular;

	float d = pow(abs(dot(normalize(IN.Normal),normalize(IN.Eye))),UnderSkinDiffuse);
	Color.rgb += SpecularColor*(1.0-d);

    return Color;
}


// オブジェクト描画用テクニック
// 不要なものは削除可
#define BASIC_TEC_TEX(name, sphere, toon) \
	technique name < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = sphere; bool UseToon = toon; \
		string Script = \
			"RenderColorTarget=UseMipmapObjectTexture;" \
				"RenderDepthStencilTarget=UMOTDepth;" \
					"ClearSetColor=ClearColor;" \
					"ClearSetDepth=ClearDepth;" \
					"Clear=Color;" \
					"Clear=Depth;" \
				"Pass=CreateMipmap;" \
			"RenderColorTarget=;" \
				"RenderDepthStencilTarget=;" \
				"Pass=DrawObject;" \
		; \
	> { \
		pass CreateMipmap < string Script= "Draw=Buffer;"; >{ \
			AlphaBlendEnable = false; \
			AlphaTestEnable = false; \
			ZEnable = false; \
			VertexShader = compile vs_2_0 CopyTex_VS(MipmapOffset); \
			PixelShader  = compile ps_2_0 CopyTex_PS(OrgObjTexSampler); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_2_0 Basic_VS(true, sphere, toon); \
			PixelShader  = compile ps_2_0 Basic_PS(true, sphere, toon); \
		} \
	}
#define BASIC_TEC_NOTEX(name, sphere, toon) \
	technique name < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = sphere; bool UseToon = toon; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_2_0 Basic_VS(false, sphere, toon); \
			PixelShader  = compile ps_2_0 Basic_PS(false, sphere, toon); \
		} \
	}

BASIC_TEC_TEX(MainTec0, false, false)
BASIC_TEC_TEX(MainTec1, true,  false)
BASIC_TEC_TEX(MainTec2, false, true)
BASIC_TEC_TEX(MainTec3, true,  true)

BASIC_TEC_NOTEX(MainTec4, false, false)
BASIC_TEC_NOTEX(MainTec5, true,  false)
BASIC_TEC_NOTEX(MainTec6, false, true)
BASIC_TEC_NOTEX(MainTec7, true,  true)

////////////////////////////////////////////////////////////////////////////////
// MMD標準のセルフシャドウの明るさ計算
// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);
#define ShadowMapSampler DefSampler

float MMDShadowBrightness(float2 ShadowMapPos, float DepthRef){
	float shadow = max(DepthRef - tex2D(ShadowMapSampler,ShadowMapPos).r, 0);
	float comp = 1 - saturate(shadow*
		(parthf ? SKII2*ShadowMapPos.y // セルフシャドウモード2
				: SKII1 // セルフシャドウモード1
		)-0.3);
    return comp;
}

static const float2 sampstep = float2(1.0/SHADOWMAP_WIDTH, 1.0/SHADOWMAP_HEIGHT);


////////////////////////////////////////////////////////////////////////////////
// 小さめのソフトシャドウ
// VSM方式 9点サンプリング
// Original Code: そぼろ氏 SpotLightShadow_Object
float2 GetZBuffSampleD2(float2 pos){
	float d=tex2D(ShadowMapSampler, pos).r;
	return float2(d, d*d);
}

// 9点サンプリング
float2 GetZBufSample(float2 texc){
	float2 Out;
	float step = sampstep;

	Out = GetZBuffSampleD2(texc) * 2;

	Out += GetZBuffSampleD2(texc + float2(0, step));
	Out += GetZBuffSampleD2(texc + float2(0, -step));
	Out += GetZBuffSampleD2(texc + float2(step, 0));
	Out += GetZBuffSampleD2(texc + float2(-step, 0));
	Out += GetZBuffSampleD2(texc + float2(step, step)) * 0.7071; // 0.7071=sqrt(0.5) 中心からの距離
	Out += GetZBuffSampleD2(texc + float2(-step, step))* 0.7071;
	Out += GetZBuffSampleD2(texc + float2(step, -step))* 0.7071;
	Out += GetZBuffSampleD2(texc + float2(-step, -step))* 0.7071;

	Out /= 2 + 4 + 4*(0.7071);
	return Out;
}

float ShadowBrightness(float2 ShadowMapPos, float DepthRef){
	float comp;
	if(parthf && (ShadowMapPos.y<SOFTSHADOW_DISTANCE)){
		comp = MMDShadowBrightness(ShadowMapPos, DepthRef);
	}
	else{
		float2 d = GetZBufSample(ShadowMapPos);
		d.y += SOFTSHADOW_THRESHOLD;
		float sigma2 = d.y - d.x * d.x;
		comp = sigma2 / (sigma2 + DepthRef - d.x);
		comp = (comp<0) + saturate(comp);
	}
    return comp;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
    float4 Color    : COLOR0;       // ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul(Pos,WorldViewProjMatrix);

    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
    // 頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul(Pos, LightWorldViewProjMatrix);

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
// シャドウマップが違うので、自前描画の時は、モード１相当とする。
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
    float4 Color = IN.Color;
    float4 ShadowColor = float4(AmbientColor, Color.a);  // 影の色
    if ( useTexture ) {
        // テクスチャ適用
        float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
        Color *= TexColor;
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
    float comp = 1;
    if(useToon){
		comp = dot(IN.Normal,-LightDirection);
		ShadowColor.rgb *= pow(MaterialToon,ToonPower);
		Color.rgb*=OverBright;
	}
    // テクスチャ座標に変換
	IN.ZCalcTex/=IN.ZCalcTex.w;
	float2 ShadowMapPos;
	ShadowMapPos.x = (1.0 + IN.ZCalcTex.x)*0.5;
	ShadowMapPos.y = (1.0 - IN.ZCalcTex.y)*0.5;

	float shadow=1;
	if( !any( saturate(ShadowMapPos) != ShadowMapPos ) ) {
		shadow = ShadowBrightness(ShadowMapPos.xy, IN.ZCalcTex.z);
	}
    comp *= (comp>=0) ? shadow*ShadowDarkness+1.0-ShadowDarkness : ShadowDarkness -1.0;
	Color = lerp(ShadowColor, Color, comp);

    // スペキュラ適用
    // スペキュラ色計算
    float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
    Color.rgb += Specular*shadow;

	float d = pow(abs(dot(normalize(IN.Normal),normalize(IN.Eye))),UnderSkinDiffuse);
	Color.rgb += SpecularColor*(1.0-d);
    if( transp ) Color.a *= 0.5f;
    return Color;
}

// オブジェクト描画用テクニック
// 不要なものは削除可
#define SELFSHADOW_TEC_TEX(name, sphere, toon) \
	technique name < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = sphere; bool UseToon = toon; \
		string Script = \
			"RenderColorTarget=UseMipmapObjectTexture;" \
				"RenderDepthStencilTarget=UMOTDepth;" \
					"ClearSetColor=ClearColor;" \
					"ClearSetDepth=ClearDepth;" \
					"Clear=Color;" \
					"Clear=Depth;" \
				"Pass=CreateMipmap;" \
			"RenderColorTarget=;" \
				"RenderDepthStencilTarget=;" \
				"Pass=DrawObject;" \
		; \
	> { \
		pass CreateMipmap < string Script= "Draw=Buffer;"; >{ \
			AlphaBlendEnable = false; \
			AlphaTestEnable = false; \
			ZEnable = false; \
			VertexShader = compile vs_2_0 CopyTex_VS(MipmapOffset); \
			PixelShader  = compile ps_2_0 CopyTex_PS(OrgObjTexSampler); \
		} \
		pass DrawObject { \
			VertexShader = compile vs_3_0 BufferShadow_VS(true, sphere, toon); \
			PixelShader  = compile ps_3_0 BufferShadow_PS(true, sphere, toon); \
		} \
	}
#define SELFSHADOW_TEC_NOTEX(name, sphere, toon) \
	technique name < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = sphere; bool UseToon = toon; \
	> { \
		pass DrawObject { \
			VertexShader = compile vs_3_0 BufferShadow_VS(false, sphere, toon); \
			PixelShader  = compile ps_3_0 BufferShadow_PS(false, sphere, toon); \
		} \
	}

SELFSHADOW_TEC_TEX(BSTec0, false, false)
SELFSHADOW_TEC_TEX(BSTec1, true,  false)
SELFSHADOW_TEC_TEX(BSTec2, false, true)
SELFSHADOW_TEC_TEX(BSTec3, true,  true)

SELFSHADOW_TEC_NOTEX(BSTec4, false, false)
SELFSHADOW_TEC_NOTEX(BSTec5, true,  false)
SELFSHADOW_TEC_NOTEX(BSTec6, false, true)
SELFSHADOW_TEC_NOTEX(BSTec7, true,  true)

///////////////////////////////////////////////////////////////////////////////////////////////
