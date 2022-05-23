// NOTE: Pulled this from here: https://github.com/IronWarrior/UnityToonShader/blob/master/Assets/Toon.shader
// The original reddit post is here: https://www.reddit.com/r/Unity3D/comments/afygr0/i_wrote_a_tutorial_for_tooncel_shading_linksource/

// All I did was follow this guide to learn some URP shader basics: https://www.cyanilux.com/tutorials/urp-shader-code/
// then converted the above CG (builtin render pipeline) shader to URP :)

Shader "Custom/ToonHLSL"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Main Texture", 2D) = "white" {}
        _AmbientColor("Ambient Color", Color) = (0.4,0.4,0.4,1)
        _SpecularColor("Specular Color", Color) = (0.9,0.9,0.9,1)
        _Glossiness("Glossiness", Float) = 32
        _RimColor("Rim Color", Color) = (1,1,1,1)
        _RimAmount("Rim Amount", Range(0, 1)) = 0.716
        _RimThreshold("Rim Threshold", Range(0, 1)) = 0.1
    }
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType"     = "Opaque"
        }
        LOD 100

        HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            float4 _Color;
            float4 _AmbientColor;
            float4 _SpecularColor;
            float4 _RimColor;
            float  _Glossiness;
            float  _RimAmount;
            float  _RimThreshold;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct Attributes {
            float4 vertex  : POSITION;
            float4 uv      : TEXCOORD0;
            float3 normal  : NORMAL;
            float4 tangent : TANGENT;
        };

        struct Varyings {
            float4 pos         : SV_POSITION;
            float3 worldNormal : NORMAL;
            float2 uv          : TEXCOORD0;
            float3 viewDir     : TEXCOORD1;
            float4 shadowCoord : TEXCOORD2;
        };

        ENDHLSL

        Pass {
            Tags {
                "LightMode"="UniversalForward"
            }

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            Varyings vert (Attributes i) {
                Varyings o;

                VertexPositionInputs positionInputs = GetVertexPositionInputs(i.vertex.xyz);
                VertexNormalInputs   normalInputs   = GetVertexNormalInputs(i.normal, i.tangent);

                o.pos         = positionInputs.positionCS;
                o.worldNormal = normalInputs.normalWS;
                o.uv          = TRANSFORM_TEX(i.uv, _MainTex);
                o.viewDir     = GetWorldSpaceViewDir(positionInputs.positionWS);
                o.shadowCoord = TransformWorldToShadowCoord(positionInputs.positionWS);

                return o;
            }

            float4 frag (Varyings i) : SV_Target {
                float3 normal  = normalize(i.worldNormal);
                float3 viewDir = normalize(i.viewDir);

                // Lighting below is calculated using Blinn-Phong,
                // with values thresholded to create the "toon" look.
                // https://en.wikipedia.org/wiki/Blinn-Phong_shading_model

                // Calculate illumination from directional light.
                // mainLightDirection is a vector pointing the OPPOSITE
                // direction of the main directional light.
                Light mainLight          = GetMainLight();
                half3 mainLightDirection = mainLight.direction;
                half3 mainLightColor     = mainLight.color;

                float NdotL = dot(mainLightDirection, normal);

                // Samples the shadow map, returning a value in the 0...1 range,
                // where 0 is in the shadow, and 1 is not.
                float shadow = MainLightRealtimeShadow(i.shadowCoord);

                // Partition the intensity into light and dark, smoothly interpolated
                // between the two to avoid a jagged break.
                float lightIntensity = smoothstep(0, 0.01, NdotL * shadow);
                float4 light = lightIntensity * float4(mainLightColor.rgb, 1);

                // Calculate specular reflection.
                float3 halfVector = normalize(mainLightDirection + viewDir);
                float NdotH = dot(normal, halfVector);

                // Multiply _Glossiness by itself to allow artist to use smaller
                // glossiness values in the inspector.
                float specularIntensity = pow(NdotH * lightIntensity, _Glossiness * _Glossiness);
                float specularIntensitySmooth = smoothstep(0.005, 0.01, specularIntensity);
                float4 specular = specularIntensitySmooth * _SpecularColor;

                // Calculate rim lighting.
                float rimDot = 1 - dot(viewDir, normal);

                // We only want rim to appear on the lit side of the surface,
                // so multiply it by NdotL, raised to a power to smoothly blend it.
                float rimIntensity = rimDot * pow(NdotL, _RimThreshold);
                rimIntensity = smoothstep(_RimAmount - 0.01, _RimAmount + 0.01, rimIntensity);
                float4 rim = rimIntensity * _RimColor;

                float4 sample = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                return (light + _AmbientColor + specular + rim) * _Color * sample;
            }

            ENDHLSL
        }

        // Shadow casting support.
        UsePass "Legacy Shaders/VertexLit/SHADOWCASTER"
    }
}