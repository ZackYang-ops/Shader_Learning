// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

// Upgrade NOTE: replaced '_LightMatrix0' with 'unity_WorldToLight'

Shader "Custom/CombineAttenAndShadow"
{
	Properties
	{
		_Diffuse("Diffuse Color", Color) = (1, 1, 1, 1)
		_Specular("Specular Color", Color) = (1, 1, 1, 1)
		_Gloss("Gloss", Range(8.0, 256)) = 20
	}

	SubShader
	{
		Pass 
		{
			Tags
			{
				"LightMode" = "ForwardBase"
			}

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdbase			//保证在shader中使用的光照衰减等变量可以被正确赋值
			#include "Lighting.cginc"
			#include "AutoLight.cginc"

			float4 _Diffuse;
			float4 _Specular;
			float _Gloss;

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				float3 worldNormal : TEXCOORD1; 
				SHADOW_COORDS(2)			//声明一个用于对shadowmap采样的坐标，参数为下一个可用的插值寄存器的index
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);

				//Pass shadow coordinates to fragment shader
				TRANSFER_SHADOW(o);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 halfDir = normalize(lightDir + viewDir);

				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, lightDir));
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, halfDir)), _Gloss);

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				return fixed4(ambient + (diffuse + specular) * atten, 1.0);
			}

			ENDCG
		}


		Pass
		{
			//pass for pixel light other than directional _LightColor0
			Tags
			{
				"LightMode" = "ForwardAdd"
			}

			Blend One One  						//开启混合模式,使该pass所计算出的结果可以与base pass中的结果进行叠加

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_fwdadd			//保证在shader中使用的光照衰减等变量可以被正确赋值
			#include "Lighting.cginc"
			#include "AutoLight.cginc"				//用于得到所有计算阴影的宏

			float4 _Diffuse;
			float4 _Specular;
			float _Gloss;

			struct a2v
			{
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 pos : SV_POSITION;
				float3 worldPos : TEXCOORD0;
				float3 worldNormal : TEXCOORD1; 
				SHADOW_COORDS(2)
			};

			v2f vert(a2v v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				o.worldNormal = UnityObjectToWorldNormal(v.normal);

				TRANSFER_SHADOW(o);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				fixed3 worldNormal = normalize(i.worldNormal);

				//对于不同光源使用不同方法计算光的方向
				#ifdef USING_DIRECTIONAL_LIGHT
					fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				#else
					fixed3 lightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
				#endif

				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 halfDir = normalize(lightDir + viewDir);

				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, lightDir));
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(worldNormal, halfDir)), _Gloss);

				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				return fixed4((diffuse + specular) * atten, 1.0);
			}


			ENDCG
		}
	}
	Fallback "Specular"				//当开启阴影后,unity会在其中寻找ShadowCaster Pass
}