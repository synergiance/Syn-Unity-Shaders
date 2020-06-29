#ifndef ACKLIGHTINGSPECULAR
#define ACKLIGHTINGSPECULAR

#define HASSPECULAR
#include "Core.cginc"

Texture2D _MetallicGlossMap;
float _Metallic;
float _Glossiness;
float _GlossMapScale;
float _SmoothnessTextureChannel;

struct BoxProjectData {
	float3 direction;
	float3 position;
	float4 cubemapPosition;
	float3 boxMin;
	float3 boxMax;
};

float3 BoxProject(BoxProjectData i) {
	float3 direction = i.direction;
	#if UNITY_SPECCUBE_BOX_PROJECTION
		[branch] if (i.cubemapPosition.w > 0) {
			float3 factors = ((i.direction > 0 ? i.boxMax : i.boxMin) - i.position) / i.direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = i.direction * scalar + (i.position - i.cubemapPosition);
		}
	#endif
	return direction;
}

#ifndef LIGHTSPECOVERRIDE
void calcSpecular(inout shadingData s) {
	float3 halfVector = normalize(s.lightDir + s.normal);
	float specular = pow(saturate(dot(s.normal, halfVector)), _Glossiness * 100);
	
	BoxProjectData bpd;
	bpd.direction = reflect(-s.viewDir, s.normal);
	bpd.position = s.posWorld;
	bpd.cubemapPosition = unity_SpecCube0_ProbePosition;
	bpd.boxMin = unity_SpecCube0_BoxMin;
	bpd.boxMax = unity_SpecCube0_BoxMax;
	
	fixed3 probe = 0;
	Unity_GlossyEnvironmentData envData;
	envData.roughness = 1 - _Glossiness;
	envData.reflUVW = BoxProject(bpd);
	float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
	#if UNITY_SPECCUBE_BLENDING
		float interpolator = unity_SpecCube0_BoxMin.w;
		UNITY_BRANCH
		if (interpolator < 0.99999) {
			bpd.cubemapPosition = unity_SpecCube1_ProbePosition;
			bpd.boxMin = unity_SpecCube1_BoxMin;
			bpd.boxMax = unity_SpecCube1_BoxMax;
			envData.reflUVW = BoxProject(bpd);
			float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube0_HDR, envData);
			probe = lerp(probe1, probe0, interpolator);
		} else {
			probe = probe0;
		}
	#else
		probe = probe0;
	#endif
	
	s.specular += specular * s.lightCol + probe;
}
#endif // LIGHTSPECOVERRIDE

/*
float3 BoxProjection(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax) {
	#if UNITY_SPECCUBE_BOX_PROJECTION
		[branch] if (cubemapPosition.w > 0) {
			float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = direction * scalar + (position - cubemapPosition);
		}
	#endif
	return direction;
}

float3 calcSpecular(float3 lightDir, float3 viewDir, float3 normalDir, float3 lightColor, VertexOutput i, float atten, float env) {
	float3 specularIntensity = _SpecularMap.Sample(sampler_MainTex, i.uv.xy).rgb * _SpecularColor.rgb;
	float3 halfVector = normalize(lightDir + viewDir);
	float3 specular = pow( saturate( dot( normalDir, halfVector)), _SpecularPower);
	float3 probe = float3(0, 0, 0);
	
	// http://wiki.unity3d.com/index.php/Anisotropic_Highlight_Shader
	[branch] if (_Anisotropic > 0) {
		float3 anisodir = normalDir;
		[branch] switch (_Anisotropic) {
			case 1: // Texture
				float3x3 tangentTransform = float3x3(i.tangentDir, i.bitangentDir, i.normalDir);
				float3 anisotexdir = UnpackNormal(_AnisoTex.Sample(sampler_MainTex, i.uv.xy));
				anisodir = normalize(mul(anisotexdir.rgb, tangentTransform));
				break;
			case 2: // Horizontal
				anisodir = i.tangentDir;
				break;
			case 3: // Vertical
				anisodir = i.bitangentDir;
				break;
		}
		float NdotL = saturate(dot(normalDir, lightDir));
		fixed HdotA = dot(normalize(normalDir + anisodir.rgb), halfVector);
		float aniso = max(0, sin(radians((HdotA + _AnisoOffset) * 180)));
		specular = saturate(pow(aniso, _SpecularPower));
	}
	
	if (env > 0.00001) {
		float3 reflectionDir = reflect(-viewDir, normalDir);
		Unity_GlossyEnvironmentData envData;
		envData.roughness = 1 - _ProbeClarity;
		envData.reflUVW = BoxProjection(reflectionDir, i.posWorld, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
		float3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
		#if UNITY_SPECCUBE_BLENDING
			float interpolator = unity_SpecCube0_BoxMin.w;
			[branch] if (interpolator < 0.99999) {
				envData.reflUVW = BoxProjection(reflectionDir, i.posWorld, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
				float3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube0_HDR, envData);
				probe = lerp(probe1, probe0, interpolator);
			} else {
				probe = probe0;
			}
		#else
			probe = probe0;
		#endif
	}
	
	specular = specular * specularIntensity * lightColor * atten + probe * env;
	return specular;
}
*/

#endif // ACKLIGHTINGSPECULAR