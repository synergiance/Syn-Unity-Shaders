// SynToon by Synergiance
// v0.2.4

#define VERSION="v0.2.4"

#ifndef ALPHA_RAINBOW_CORE_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"
#if defined(RAINBOW)
#include "HSB.cginc"
#endif

sampler2D _MainTex;
sampler2D _BumpMap;
sampler2D _ColorMask;
sampler2D _EmissionMap;
float4 _MainTex_ST;
float4 _EmissionColor;
#if defined(PULSE)
float _EmissionSpeed;
sampler2D _EmissionPulseMap;
float4 _EmissionPulseColor;
#endif
float _Brightness;
float4 _Color;
#if !NO_SHADOW
float _ShadowAmbient;
sampler2D _ShadowRamp;
float4 _ShadowTint;
float _shadow_coverage;
float _shadow_feather;
#endif
float _Cutoff;
float _AlphaOverride;
#if defined(RAINBOW)
sampler2D _RainbowMask;
float _Speed;
#endif
uniform float _outline_width;
uniform float _outline_feather;
uniform float4 _outline_color;
//sampler2D _ToonTex;
sampler2D _SphereAddTex;
sampler2D _SphereMulTex;
uniform float4 _StaticToonLight;

static const float3 grayscale_vector = float3(0, 0.3823529, 0.01845836);

struct v2g
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float3 normal : NORMAL;
    fixed4 amb : COLOR0;
    fixed3 direct : COLOR1;
    fixed3 indirect : COLOR2;
    float4 posWorld : TEXCOORD2;
    float3 normalDir : TEXCOORD3;
    float3 tangentDir : TEXCOORD4;
    float3 bitangentDir : TEXCOORD5;
    float4 lightData : TEXCOORD8;
    float3 reflectionMap : TEXCOORD9;
    float lightModifier : TEXCOORD10;
	float4 pos : CLIP_POS;
	LIGHTING_COORDS(6,7)
	UNITY_FOG_COORDS(11)
};

struct VertexOutput
{
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
    fixed4 amb : COLOR0; //
    fixed3 direct : COLOR1; //
    fixed3 indirect : COLOR2; //
	float4 posWorld : TEXCOORD2;
	float3 normalDir : TEXCOORD3;
	float3 tangentDir : TEXCOORD4;
	float3 bitangentDir : TEXCOORD5;
    float4 lightData : TEXCOORD8; //
    float3 reflectionMap : TEXCOORD9; //
    float lightModifier : TEXCOORD10; //
	float4 col : COLOR3;
	bool is_outline : IS_OUTLINE;
	LIGHTING_COORDS(6,7)
	UNITY_FOG_COORDS(11)
};

float grayscaleSH9(float3 normalDirection)
{
    return dot(ShadeSH9(half4(normalDirection, 1.0)), grayscale_vector);
}

#if defined(RAINBOW)
float3 hueShift(float3 col, float3 mask)
{
    float3 newc = col;
    newc = float3(applyHue(newc, _Time[1] * _Speed * _Speed * _Speed));
    newc = float3((newc * mask) + (col * (1 - mask)));
    return newc;
}
#endif

v2g vert(appdata_full v)
{
    v2g o;
	o.pos = UnityObjectToClipPos(v.vertex);
    o.normal = v.normal;
    o.normalDir = normalize(UnityObjectToWorldNormal(v.normal));
    o.amb = _LightColor0;
    o.direct = ShadeSH9(half4(0.0, 1.0, 0.0, 1.0));
    o.indirect = ShadeSH9(half4(0.0, -1.0, 0.0, 1.0));
    o.tangentDir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
    o.bitangentDir = normalize(cross(o.normalDir, o.tangentDir) * v.tangent.w);
    o.posWorld = mul(unity_ObjectToWorld, v.vertex);
    o.vertex = v.vertex;
    o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv1 = v.texcoord1;
	TRANSFER_VERTEX_TO_FRAGMENT(o);
	UNITY_TRANSFER_FOG(o, o.pos);
    
    // Calc
    o.lightData.r = dot(_LightColor0.rgb, grayscale_vector);       // grayscalelightcolor
    o.lightData.g = grayscaleSH9(float3(0.0, -1.0, 0.0));          // bottomIndirectLighting
    o.lightData.b = grayscaleSH9(float3(0.0, 1.0, 0.0));           // topIndirectLighting
    o.lightData.a = o.lightData.b + o.lightData.r - o.lightData.g; // lightDifference
    
    float4 objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
    o.reflectionMap = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, normalize((_WorldSpaceCameraPos - objPos.rgb)), 7), unity_SpecCube0_HDR)* 0.02;
    float3 lightColor = o.direct + o.amb.rgb * 2 + o.reflectionMap;
    float brightness = lightColor.r * 0.3 + lightColor.g * 0.59 + lightColor.b * 0.11;
    float correctedBrightness = -1 / (brightness * 2 + 1) + 1 + brightness * 0.1;
    o.lightModifier = correctedBrightness / brightness;
    return o;
}

float3 calcShadow(float3 position, float3 normal)
{// Generate the shadow based on the light direction (and soon take shadow maps into account)
    float3 bright = float3(1.0, 1.0, 1.0);
    #if !NO_SHADOW
    #if STATIC_LIGHT
    // Places light at a specific vector relative to the model
    float lightScale = dot(normal, _StaticToonLight.rgb) * 0.5 + 0.5;
    #elif VRCHAT_HACK
    // This hack gets directionless directional lights, a common phenominon in VRChat, to get a direction.
    float3 lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - position, _WorldSpaceLightPos0.w * 0.99998 + 0.00001));
    float lightScale = dot(normal, lightDirection) * 0.5 + 0.5;
    #else
    // Normal lighting
    float3 lightDirection = normalize(lerp(_WorldSpaceLightPos0.xyz, _WorldSpaceLightPos0.xyz - position, _WorldSpaceLightPos0.w));
    float lightScale = dot(normal, lightDirection) * 0.5 + 0.5;
    #endif
    #if TINTED_SHADOW
    float lightContrib = saturate(smoothstep((1 - _shadow_feather) * _shadow_coverage, _shadow_coverage, lightScale));
    bright = lerp(_ShadowTint.rgb, float3(1.0, 1.0, 1.0), lightContrib);
    #elif RAMP_SHADOW
    bright = tex2D(_ShadowRamp, float2(lightScale, lightScale)).rgb;
    #else
    #endif
    #endif
    return bright;
}

float3 artsyOutline(float3 color, float3 view, float3 normal)
{// Outline
    #if ARTSY_OUTLINE
    float3 outlineColor = color;
    #if TINTED_OUTLINE
    outlineColor *= _outline_color.rgb;
    #elif COLORED_OUTLINE
    outlineColor = float3((_outline_color.rgb * _outline_color.a) + (color * (1 - _outline_color.a)));
    #endif
    color = lerp(outlineColor,color.rgb,smoothstep(_outline_width - _outline_feather / 10, _outline_width, dot(view, normal)));
    // Outline Effects
    
    #endif
    return color;
}

float3 applySphere(float3 color, float3 normal)
{// Applies add and multiply spheres
    #if !NO_SPHERE
	float3 viewNormal = normalize( mul( (float3x3)UNITY_MATRIX_MV, normal ));
	float2 sphereUv = viewNormal.xy * 0.5 + 0.5;
    #if ADD_SPHERE
	float4 sphereAdd = tex2D( _SphereAddTex, sphereUv );
    color += sphereAdd.rgb;
    #elif MUL_SPHERE
	float4 sphereMul = tex2D( _SphereMulTex, sphereUv );
    color *= sphereMul.rgb;
    #endif
    #endif
}

float4 frag(VertexOutput i) : SV_Target
{
    // Variables
    float4 color = tex2D(_MainTex, i.uv);
    float4 _EmissionMap_var = tex2D(_EmissionMap, i.uv);
    float3 emissive = (_EmissionMap_var.rgb*_EmissionColor.rgb);
    float4 _ColorMask_var = tex2D(_ColorMask, i.uv);
    #if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON)
    clip (color.a - _Cutoff);
    #endif
    color = lerp((color.rgba*_Color.rgba),color.rgba,_ColorMask_var.r);
    
    // Lighting
    float _AmbientLight = 0.8;
    i.normalDir = normalize(i.normalDir);
    float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
    float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,i.uv));
    float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform));
    float3 viewDirection = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);
    float3 directLighting = (saturate(i.direct + i.reflectionMap + i.amb.rgb) + i.amb.rgb) / 2;
    float3 lightColor = saturate((lerp(0.0, i.direct, _AmbientLight ) + _LightColor0.rgb + i.reflectionMap) * _Brightness * ((i.lightModifier + 1) / 2));
    float3 bright = calcShadow(i.posWorld.xyz, normalDirection);
    
    // Pulse
    #if defined(PULSE)
    float4 pulsemask = tex2D(_EmissionPulseMap, i.uv);
    emissive = lerp(emissive, _EmissionPulseColor.rgb*pulsemask.rgb, (sin(_Time[1] * _EmissionSpeed * _EmissionSpeed * _EmissionSpeed) + 1) / 2);
    #endif
    
    // Primary effects
    // Rainbow
    #if defined(RAINBOW)
    float4 maskcolor = tex2D(_RainbowMask, i.uv);
    color = float4(hueShift(color.rgb, maskcolor.rgb),color.a);
    bright = hueShift(bright, maskcolor.rgb);
    emissive = hueShift(emissive, 1);
    #endif
    
    // Secondary Effects

    // Outline
    color.rgb = artsyOutline(color.rgb, viewDirection, normalDirection);
    emissive = artsyOutline(emissive, viewDirection, normalDirection);
    
    #if !NO_SPHERE
	float3 viewNormal = normalize( mul( (float3x3)UNITY_MATRIX_MV, i.normalDir ));
	float2 sphereUv = viewNormal.xy * 0.5 + 0.5;
    #if ADD_SPHERE
	float4 sphereAdd = tex2D( _SphereAddTex, sphereUv );
    color.rgb += sphereAdd.rgb;
    #elif MUL_SPHERE
	float4 sphereMul = tex2D( _SphereMulTex, sphereUv );
    color.rgb *= sphereMul.rgb
    #endif
    #endif
    
    // Combining
    UNITY_APPLY_FOG(i.fogCoord, color);
    return float4(bright * lightColor, _AlphaOverride) * color + float4(emissive, 0);
}

float4 frag4(VertexOutput i) : COLOR
{
    // Variables
    float4 color = tex2D(_MainTex, i.uv);
    float4 _ColorMask_var = tex2D(_ColorMask, i.uv);
    #if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON)
    clip (color.a - _Cutoff);
    #endif
    color = lerp((color.rgba*_Color.rgba),color.rgba,_ColorMask_var.r);
    
    // Lighting
    i.normalDir = normalize(i.normalDir);
    float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
    float3 _BumpMap_var = UnpackNormal(tex2D(_BumpMap,i.uv));
    float3 normalDirection = normalize(mul(_BumpMap_var.rgb, tangentTransform));
    float3 viewDirection = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);
    float3 lightColor = saturate(i.amb.rgb * _Brightness * i.lightModifier * saturate(i.lightModifier) * 0.5);
    float3 bright = calcShadow(i.posWorld.xyz, normalDirection);
    
    // Rainbow
    #if defined(RAINBOW)
    float4 maskcolor = tex2D(_RainbowMask, i.uv);
    color = float4(hueShift(color.rgb, maskcolor.rgb),color.a);
    bright = hueShift(bright, maskcolor.rgb);
    #endif

    // Outline
    color.rgb = artsyOutline(color.rgb, viewDirection, normalDirection);
    
    #if !NO_SPHERE
	float3 viewNormal = normalize( mul( (float3x3)UNITY_MATRIX_MV, i.normalDir ));
	float2 sphereUv = viewNormal.xy * 0.5 + 0.5;
    #if ADD_SPHERE
	float4 sphereAdd = tex2D( _SphereAddTex, sphereUv );
    color.rgb += sphereAdd.rgb;
    #elif MUL_SPHERE
	float4 sphereMul = tex2D( _SphereMulTex, sphereUv );
    color.rgb *= sphereMul.rgb
    #endif
    #endif
    
    // Combining
    UNITY_APPLY_FOG(i.fogCoord, color);
    return float4(bright * lightColor, _AlphaOverride) * color;
}

float4 frag5(VertexOutput i) : COLOR
{
    // Variables
    float4 color = tex2D(_MainTex, i.uv);
    float4 _ColorMask_var = tex2D(_ColorMask, i.uv);
    #if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON)
    clip (color.a - _Cutoff);
    #endif
    color = lerp((color.rgba*_Color.rgba),color.rgba,_ColorMask_var.r);
    
    // Lighting
    float3 lightColor = saturate(i.amb.rgb * _Brightness * i.lightModifier * saturate(i.lightModifier) * 0.5);
    
    // Primary Effects
    // Rainbow
    #if defined(RAINBOW)
    float4 maskcolor = tex2D(_RainbowMask, i.uv);
    color = float4(hueShift(color.rgb, maskcolor.rgb),color.a);
    #endif
    
    // Secondary Effects

    // Outline
    #if TINTED_OUTLINE
    color.rgb *= _outline_color.rgb;
    #elif COLORED_OUTLINE
    color.rgb = float3((_outline_color.rgb * _outline_color.a) + (color.rgb * (1 - _outline_color.a)));
    #endif
    // Outline Effects
    
    // Combining
    UNITY_APPLY_FOG(i.fogCoord, color);
    return float4(lightColor, _AlphaOverride) * color;
}

[maxvertexcount(6)]
void geom(triangle v2g IN[3], inout TriangleStream<VertexOutput> tristream)
{
	VertexOutput o;
	for (int ii = 0; ii < 3; ii++)
	{
		o.pos = UnityObjectToClipPos(IN[ii].vertex);
		o.uv = IN[ii].uv;
		o.uv1 = IN[ii].uv1;
		o.col = fixed4(1., 1., 1., 0.);
		o.posWorld = mul(unity_ObjectToWorld, IN[ii].vertex);
		o.normalDir = UnityObjectToWorldNormal(IN[ii].normal);
		o.tangentDir = IN[ii].tangentDir;
		o.bitangentDir = IN[ii].bitangentDir;
		o.is_outline = false;
        
        o.amb = IN[ii].amb;
        o.direct = IN[ii].direct;
        o.indirect = IN[ii].indirect;
        o.lightData = IN[ii].lightData;
        o.reflectionMap = IN[ii].reflectionMap;
        o.lightModifier = IN[ii].lightModifier;

		// Pass-through the shadow coordinates if this pass has shadows.
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
		o._ShadowCoord = IN[ii]._ShadowCoord;
		#endif

		// Pass-through the light coordinates if this pass has shadows.
		#if defined (POINT) || defined (SPOT) || defined (POINT_COOKIE) || defined (DIRECTIONAL_COOKIE)
		o._LightCoord = IN[ii]._LightCoord;
		#endif

		// Pass-through the fog coordinates if this pass has shadows.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[ii].fogCoord;
		#endif

		tristream.Append(o);
	}

	tristream.RestartStrip();
}

[maxvertexcount(6)]
void geom2(triangle v2g IN[3], inout TriangleStream<VertexOutput> tristream)
{
	VertexOutput o;
	for (int ii = 0; ii < 3; ii++)
	{
		#if OUTSIDE_OUTLINE
        o.pos = UnityObjectToClipPos(IN[ii].vertex + normalize(IN[ii].normal) * (_outline_width * .01));
        #elif SCREENSPACE_OUTLINE
        o.pos = UnityObjectToClipPos(IN[ii].vertex + normalize(IN[ii].normal) * (_outline_width * .05) * distance(_WorldSpaceCameraPos,mul(unity_ObjectToWorld, IN[ii].vertex).rgb));
        #else
        o.pos = UnityObjectToClipPos(IN[ii].vertex);
        #endif
		o.uv = IN[ii].uv;
		o.uv1 = IN[ii].uv1;
		o.col = fixed4( _outline_color.r, _outline_color.g, _outline_color.b, 1);
		o.posWorld = mul(unity_ObjectToWorld, IN[ii].vertex);
		o.normalDir = UnityObjectToWorldNormal(IN[ii].normal);
		o.tangentDir = IN[ii].tangentDir;
		o.bitangentDir = IN[ii].bitangentDir;
		o.is_outline = false;
        
        o.amb = IN[ii].amb;
        o.direct = IN[ii].direct;
        o.indirect = IN[ii].indirect;
        o.lightData = IN[ii].lightData;
        o.reflectionMap = IN[ii].reflectionMap;
        o.lightModifier = IN[ii].lightModifier;

		// Pass-through the shadow coordinates if this pass has shadows.
		#if defined (SHADOWS_SCREEN) || ( defined (SHADOWS_DEPTH) && defined (SPOT) ) || defined (SHADOWS_CUBE)
		o._ShadowCoord = IN[ii]._ShadowCoord;
		#endif

		// Pass-through the light coordinates if this pass has shadows.
		#if defined (POINT) || defined (SPOT) || defined (POINT_COOKIE) || defined (DIRECTIONAL_COOKIE)
		o._LightCoord = IN[ii]._LightCoord;
		#endif

		// Pass-through the fog coordinates if this pass has shadows.
		#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
		o.fogCoord = IN[ii].fogCoord;
		#endif

		tristream.Append(o);
	}

	tristream.RestartStrip();
}

#endif