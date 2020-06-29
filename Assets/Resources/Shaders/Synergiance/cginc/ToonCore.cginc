#ifndef ACKTOONCORE
#define ACKTOONCORE

#define CUSTOM_VERT
#include "Lighting/ToonSpecular.cginc"

v2f vert (appdata_full v) {
	v2f o;
	o.pos = UnityObjectToClipPos(v.vertex);
	o.posWorld = mul(unity_ObjectToWorld, v.vertex);
	o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
	o.normal = UnityObjectToWorldNormal(v.normal);
	#ifdef _NORMALMAP
		o.tangent = float4(normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz), v.tangent.w);
	#endif
	TRANSFER_SHADOW(o)
	UNITY_TRANSFER_FOG(o, o.pos);
	#if defined(VERTEXLIGHT_ON)
		o.vertLight = Shade4PointLightsStyled(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, o.posWorld, o.normal
		);
	#else
		o.vertLight = 0;
	#endif
	o.color = v.color * _Color;
	CALC_VERT
	return o;
};

fixed4 frag (v2f i, bool isFrontFace : SV_ISFRONTFACE) : COLOR {
	// Initialize
	shadingData s;
	initializeStruct(s, i);
	
	// Calculations
	calcNormal(s);
	s.normal *= isFrontFace ? 1 : -1;

	CALC_PRELIGHT
	
	calcLightDir(s);
	calcLightScale(s);
	s.light.r = s.light.r * 0.5 + 0.5;
	#ifdef HASSPECULAR
		calcSpecular(s);
	#endif
	calcLightColor(s);
	calcAmbient(s);

	CALC_POSTLIGHT
	
	// Final Blending
	return calcFinalColor(s);
}

#endif // ACKTOONCORE