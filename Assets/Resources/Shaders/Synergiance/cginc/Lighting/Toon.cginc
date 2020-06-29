#ifndef ACKLIGHTINGTOON
#define ACKLIGHTINGTOON

#define LIGHTCOLOROVERRIDE
#define LIGHTAMBIENTOVERRIDE
#include "Core.cginc"

#ifdef USES_GRADIENTS
	#include "../Gradient.cginc"
	DEFINEGRADIENT(Toon)
#endif

fixed _AmbDirection;
fixed _ToonAmb;
half3 _FallbackLightDir;
#ifdef SHADOWMAP
	Texture2D _ToonMap;
	#ifdef SECONDSHADOWLAYER
		Texture2D _ToonMap2;
	#endif //SECONDSHADOWLAYER
#endif //SHADOWMAP
#ifdef SHADOWRAMP
	sampler2D _ShadowRamp;
#endif
fixed _ToonIntensity;
#if !defined(USES_GRADIENTS) && !defined(SHADOWRAMP) && !defined(SHADOWMAP)
	fixed _ToonFeather;
	fixed _ToonCoverage;
	fixed4 _ToonColor;
	#ifdef SECONDSHADOWLAYER
		fixed _ToonFeather2;
		fixed _ToonCoverage2;
		fixed4 _ToonColor2;
	#endif // SECONDSHADOWLAYER
#endif // Not USES_GRADIENTS

float stylizeAtten(float atten, float feather, float coverage) {
	fixed ref = 1 - feather;
	fixed ref2 = ref * (1 - coverage);
	return smoothstep(ref2, ref2 + feather, atten);
}

float3 calcLightColorInternal(float ndotl, float atten, float shade, float3 albedo, float3 lightColor) {
	#if defined(USES_GRADIENTS) || defined(SHADOWRAMP)
		#ifdef USES_GRADIENTS
			float4 sample = SampleGradientToon(ndotl * shade);
		#else
			float4 sample = tex2D(_ShadowRamp, ndotl * shade);
		#endif
		float3 lightCol = atten * lightColor;
		#ifdef BASE_PASS
			lightCol *= lerp(lerp(fixed3(1,1,1), albedo, _ToonIntensity), float3(1,1,1), sample.a);
		#else
			lightCol = lerp(float3(0,0,0), lightCol, sample.a);
		#endif
		return max(0, lightCol) * sample.rgb;
	#else
		#ifdef LIGHT_IN_VERTEX
			fixed feather = _ToonFeather;
		#else
			fixed feather = max((ddx(ndotl) + ddy(ndotl)) * 2, _ToonFeather);
		#endif
		fixed3 shadeCol = fixed3(0,0,0);
		#ifdef BASE_PASS
			shadeCol = _ToonColor.rgb * lerp(fixed3(1,1,1), albedo, _ToonIntensity);
		#endif
		return max(0, lerp(shadeCol, fixed3(1,1,1), stylizeAtten(ndotl * shade, feather, _ToonCoverage)) * atten * lightColor);
	#endif
}

void calcLightColor(inout shadingData s) {
	s.light.rgb = calcLightColorInternal(s.light.r, s.light.g, s.light.b, s.color.rgb, s.lightCol.rgb);
}

float3 calcAmbientInternal(float3 normal, float3 albedo, float atten) {
	float3 amb = 0;
	#ifdef BASE_PASS
		float3 sh9amb = max(0, ShadeSH9(half4(lerp(half3(0,0,0), normal, _AmbDirection), 1.0)));
		half3 probeLightDir = normalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz);
		[branch] if (!any(abs(probeLightDir) > 0.01)) probeLightDir = _FallbackLightDir;
		float probeAtten = dot(normal, probeLightDir);
		#ifdef USES_GRADIENTS
			float4 sample = SampleGradientToon(atten);
			fixed styleAtten = sample.a;
		#elif defined(SHADOWRAMP)
			float4 sample = tex2D(_ShadowRamp, atten);
			fixed styleAtten = sample.a;
		#else
			#ifdef LIGHT_IN_VERTEX
				fixed feather = _ToonFeather;
			#else
				fixed feather = max(ddx(probeAtten) + ddy(probeAtten), _ToonFeather);
			#endif
			fixed styleAtten = stylizeAtten(dot(normal, probeLightDir), feather, _ToonCoverage);
		#endif
		float3 posLight = max(0, ShadeSH9(half4(probeLightDir *  0.5, 1.0)));
		float3 negLight = max(0, ShadeSH9(half4(probeLightDir * -0.5, 1.0)));
		#if defined(USES_GRADIENTS) || defined(SHADOWRAMP)
			float3 toonamb = lerp(negLight * 0.5 + posLight * 0.5 * lerp(fixed3(1,1,1), albedo, _ToonIntensity), posLight, styleAtten) * sample.rgb;
		#else
			float3 toonamb = lerp(negLight * 0.5 + posLight * 0.5 * _ToonColor.rgb * lerp(fixed3(1,1,1), albedo, _ToonIntensity), posLight, styleAtten);
		#endif
		amb = lerp(sh9amb, toonamb, _ToonAmb);
	#endif // BASE_PASS
	return amb;
}

void calcAmbient(inout shadingData s) {
	s.light.rgb += s.vertLight.rgb + calcAmbientInternal(s.normal.xyz, s.color.rgb, s.light.r * s.light.g);
}

#if defined(USES_GRADIENTS) || defined(SHADOWRAMP)
	float3 calcStyledAtten(float atten) {
		#ifdef USES_GRADIENTS
			float4 sample = SampleGradientToon(atten);
		#else
			float4 sample = tex2Dlod(_ShadowRamp, float4(atten, atten, 0, 0));
		#endif
		return saturate(sample.rgb * sample.a);
	}
#else
	float calcStyledAtten(float atten) {
		return saturate(stylizeAtten(atten, _ToonFeather, _ToonCoverage));
	}
#endif

// Basically copied out of the unity include files, with some modifications
float3 Shade4PointLightsStyled (
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,
    float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3,
    float4 lightAttenSq, float3 pos, float3 normal)
{
    // to light vectors
    float4 toLightX = lightPosX - pos.x;
    float4 toLightY = lightPosY - pos.y;
    float4 toLightZ = lightPosZ - pos.z;
    // squared lengths
    float4 lengthSq = 0;
    lengthSq += toLightX * toLightX;
    lengthSq += toLightY * toLightY;
    lengthSq += toLightZ * toLightZ;
    // don't produce NaNs if some vertex position overlaps with the light
    lengthSq = max(lengthSq, 0.000001);

    // NdotL
    float4 ndotl = 0;
    ndotl += toLightX * normal.x;
    ndotl += toLightY * normal.y;
    ndotl += toLightZ * normal.z;
    // correct NdotL
    float4 corr = rsqrt(lengthSq);
    ndotl = max (float4(0,0,0,0), ndotl * corr);
    // attenuation
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    float4 diff = ndotl * atten;
    // final color
    float3 col = 0;
    col += max(0, lightColor0 * calcStyledAtten(diff.x));
    col += max(0, lightColor1 * calcStyledAtten(diff.y));
    col += max(0, lightColor2 * calcStyledAtten(diff.z));
    col += max(0, lightColor3 * calcStyledAtten(diff.w));
    return col;
}

#endif // ACKLIGHTINGTOON