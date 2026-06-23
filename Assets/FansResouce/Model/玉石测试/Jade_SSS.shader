Shader "Liangzhu/PBR/JadeSSS"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Color Map", 2D) = "white" {}
        [MainColor] _BaseColor("Base Color", Color) = (0.55, 0.85, 0.65, 1)

        [Normal] _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalScale("Normal Scale", Float) = 1.0

        _MetallicMap("Metallic Map", 2D) = "white" {}
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.0

        _RoughnessMap("Roughness Map", 2D) = "white" {}
        _Roughness("Roughness", Range(0.0, 1.0)) = 0.15

        _OcclusionMap("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Range(0.0, 1.0)) = 0.5

        [HDR] _EmissionMap("Emission Map", 2D) = "black" {}
        [HDR] _EmissionColor("Emission Color", Color) = (0, 0, 0, 0)

        // ========== SSS Backlight Parameters ==========
        [Space(20)]
        [Header(Subsurface Scattering Translucency)]
        _TranslucencyStrength("Translucency Strength (S)", Range(0.0, 2.0)) = 0.8
        _TranslucencyPower("Translucency Power (p)", Range(0.5, 8.0)) = 3.0
        _NormalPerturbation("Normal Perturbation (a)", Range(0.0, 1.5)) = 0.6
        [HDR] _TranslucencyColor("Translucency Color", Color) = (0.3, 0.7, 0.5, 1)

        // ========== Standard params required by LitInput.hlsl ==========
        [HideInInspector] _WorkflowMode("WorkflowMode", Float) = 1.0
        [HideInInspector] _SpecColor("Specular", Color) = (0.2, 0.2, 0.2)
        [HideInInspector] _Smoothness("Smoothness", Float) = 0.85
        [HideInInspector] _BumpScale("Scale", Float) = 1.0
        [HideInInspector] _BumpMap("Normal Map", 2D) = "bump" {}
        [HideInInspector] _ParallaxMap("Height Map", 2D) = "black" {}
        [HideInInspector] _Parallax("Scale", Range(0.005, 0.08)) = 0.005
        [HideInInspector] _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _MetallicGlossMap("Metallic Gloss", 2D) = "white" {}   // required by LitGUI
        [HideInInspector] _SpecGlossMap("Spec Gloss", 2D) = "white" {}
        [HideInInspector] _SmoothnessTextureChannel("Smoothness Texture Channel", Float) = 0
        [HideInInspector] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [HideInInspector] _EnvironmentReflections("Environment Reflections", Float) = 1.0
        [HideInInspector] _ClearCoat("Clear Coat", Float) = 0.0
        [HideInInspector] _ClearCoatMap("Clear Coat Map", 2D) = "white" {}
        [HideInInspector] _DetailMask("Detail Mask", 2D) = "white" {}
        [HideInInspector] _DetailAlbedoMapScale("Detail Albedo Scale", Float) = 1.0
        [HideInInspector] _DetailAlbedoMap("Detail Albedo", 2D) = "white" {}
        [HideInInspector] _DetailNormalMapScale("Detail Normal Scale", Float) = 1.0
        [HideInInspector] _DetailNormalMap("Detail Normal", 2D) = "bump" {}
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 2
        [ToggleUI] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("__src", Float) = 1.0
        [HideInInspector] _DstBlend("__dst", Float) = 0.0
        [HideInInspector] _SrcBlendAlpha("__srcA", Float) = 1.0
        [HideInInspector] _DstBlendAlpha("__dstA", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 1.0
        [HideInInspector] _BlendModePreserveSpecular("_BlendModePreserveSpecular", Float) = 1.0
        [HideInInspector] _AlphaToMask("__alphaToMask", Float) = 0.0
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (1, 1, 1, 1)
        [HideInInspector] _GlossMapScale("Smoothness", Float) = 0.0
        [HideInInspector] _Glossiness("Smoothness", Float) = 0.0
        [HideInInspector] _GlossyReflections("EnvironmentReflections", Float) = 0.0
        [HideInInspector][NoScaleOffset] unity_Lightmaps("unity_Lightmaps", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_LightmapsInd("unity_LightmapsInd", 2DArray) = "" {}
        [HideInInspector][NoScaleOffset] unity_ShadowMasks("unity_ShadowMasks", 2DArray) = "" {}
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
            "IgnoreProjector" = "True"
        }
        LOD 300

        // -----------------------------------------------------------
        // Pass 1: Forward Lit -- CUSTOM with SSS translucency
        // -----------------------------------------------------------
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend [_SrcBlend] [_DstBlend], [_SrcBlendAlpha] [_DstBlendAlpha]
            ZWrite [_ZWrite]
            Cull [_Cull]
            AlphaToMask [_AlphaToMask]

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            // Material Keywords
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            #pragma shader_feature_local_fragment _SURFACE_TYPE_TRANSPARENT
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local_fragment _OCCLUSIONMAP
            #pragma shader_feature_local_fragment _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF
            #pragma shader_feature_local_fragment _SPECULAR_SETUP

            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _LIGHT_LAYERS
            #pragma multi_compile _ _FORWARD_PLUS

            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY

            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma instancing_options renderinglayer

            // URP's LitInput.hlsl provides all texture declarations & CBUFFER
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ========== Custom SSS uniforms (beyond LitInput) ==========
            CBUFFER_START(UnityPerMaterialExtended)
            half _TranslucencyStrength;
            half _TranslucencyPower;
            half _NormalPerturbation;
            half4 _TranslucencyColor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
                float3 normalOS     : NORMAL;
                float4 tangentOS    : TANGENT;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 normalWS     : TEXCOORD2;
                float4 tangentWS    : TEXCOORD3;
                float4 shadowCoord  : TEXCOORD5;
                float4 positionCS   : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.uv = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;
                output.normalWS = normalInput.normalWS;
                output.tangentWS = float4(normalInput.tangentWS, input.tangentOS.w);
                output.shadowCoord = GetShadowCoord(vertexInput);
                return output;
            }

            void InitializeInputData(Varyings input, SurfaceData surfaceData, out InputData inputData)
            {
                inputData = (InputData)0;

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                #if defined(_NORMALMAP)
                    half3 tangentWS = normalize(input.tangentWS.xyz);
                    half3 bitangentWS = normalize(cross(input.normalWS, tangentWS) * input.tangentWS.w);
                    inputData.tangentToWorld = half3x3(tangentWS, bitangentWS, input.normalWS);
                    inputData.normalWS = TransformTangentToWorld(surfaceData.normalTS, inputData.tangentToWorld);
                #else
                    inputData.normalWS = normalize(input.normalWS);
                #endif

                inputData.positionWS = input.positionWS;
                inputData.viewDirectionWS = viewDirWS;
                inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                inputData.fogCoord = ComputeFogFactor(input.positionCS.z);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);

                #if defined(_MAIN_LIGHT_SHADOWS) && !defined(_RECEIVE_SHADOWS_OFF)
                    inputData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // ---- Surface Data via URP standard function ----
                SurfaceData surfaceData;
                InitializeStandardLitSurfaceData(input.uv, surfaceData);

                // ---- Input Data ----
                InputData inputData;
                InitializeInputData(input, surfaceData, inputData);

                // ---- URP PBR ----
                half4 color = UniversalFragmentPBR(inputData, surfaceData);

                // ============================================================
                // SSS Translucency Backlight
                // Formula: saturate(pow(V * -(L + a * N), p)) * S
                //   L: light direction, N: normal, V: view direction
                //   a: normal perturbation (diffusion spread)
                //   p: power falloff (concentration)
                //   S: overall strength
                // ============================================================
                Light mainLight = GetMainLight(inputData.shadowCoord);
                float3 L = mainLight.direction;
                float3 N = inputData.normalWS;
                float3 V = inputData.viewDirectionWS;

                float translucency = dot(V, -(L + _NormalPerturbation * N));
                translucency = saturate(pow(translucency, _TranslucencyPower));
                translucency *= _TranslucencyStrength;

                float atten = mainLight.shadowAttenuation * mainLight.distanceAttenuation;
                translucency *= atten;

                color.rgb += translucency * mainLight.color * _TranslucencyColor.rgb * surfaceData.albedo;

                // ---- Additional lights ----
                #if defined(_ADDITIONAL_LIGHTS)
                uint count = GetAdditionalLightsCount();
                for (uint i = 0; i < count; i++)
                {
                    Light addLight = GetAdditionalLight(i, input.positionWS, inputData.shadowCoord);

                    float translucencyAdd = dot(V, -(addLight.direction + _NormalPerturbation * N));
                    translucencyAdd = saturate(pow(translucencyAdd, _TranslucencyPower));
                    translucencyAdd *= _TranslucencyStrength;
                    translucencyAdd *= addLight.shadowAttenuation * addLight.distanceAttenuation;

                    color.rgb += translucencyAdd * addLight.color * _TranslucencyColor.rgb * surfaceData.albedo;
                }
                #endif

                color.rgb = MixFog(color.rgb, inputData.fogCoord);
                return color;
            }
            ENDHLSL
        }

        // -----------------------------------------------------------
        // Pass 2: ShadowCaster -- reuse URP built-in
        // -----------------------------------------------------------
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        // -----------------------------------------------------------
        // Pass 3: DepthOnly -- reuse URP built-in
        // -----------------------------------------------------------
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // -----------------------------------------------------------
        // Pass 4: DepthNormals -- reuse URP built-in
        // -----------------------------------------------------------
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ LOD_FADE_CROSSFADE
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        // -----------------------------------------------------------
        // Pass 5: Meta (lightmapping) -- reuse URP built-in
        // -----------------------------------------------------------
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }
            Cull Off

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaLit
            #pragma shader_feature_local_fragment _SPECULAR_SETUP
            #pragma shader_feature_local_fragment _EMISSION
            #pragma shader_feature_local_fragment _METALLICSPECGLOSSMAP
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature EDITOR_VISUALIZATION
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitMetaPass.hlsl"
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "UnityEditor.ShaderGUI"
}
