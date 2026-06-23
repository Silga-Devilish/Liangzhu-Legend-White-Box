// ===============================================================
// JadeSSS_Translucency.hlsl
// SSS 次表面散射背光 — 自定义函数，供 Shader Graph 调用
// 公式: saturate(pow(V * -(L + a * N), p)) * S
// ===============================================================

// Shader Graph 中 Type 选 Float, Precision 选 Half
// 所有输入端口都和 Custom Function Node 的 Inputs 一一对应
void JadeSSS_Translucency_float(
    float3 WorldNormal,      // 世界空间法线
    float3 WorldViewDir,     // 世界空间视线方向
    float3 LightDirection,   // 主光源方向（指向光源）
    float3 Albedo,           // 漫反射颜色
    float3 TranslucencyColor,// 透射颜色
    float NormalPerturbation,// a — 法线扰动（扩散程度）
    float Power,             // p — 集中指数
    float Strength,          // S — 整体强度
    float Attenuation,       // 光源衰减（shadow * distance）
    float3 LightColor,       // 光源颜色
    out float3 EmissionOut   // 输出到 Emission 端口
)
{
    float3 L = LightDirection;
    float3 N = normalize(WorldNormal);
    float3 V = normalize(WorldViewDir);

    // 核心公式: V * -(L + a * N)
    float translucency = dot(V, -(L + NormalPerturbation * N));

    // saturate + pow + strength
    translucency = saturate(pow(translucency, Power));
    translucency *= Strength;
    translucency *= Attenuation;

    // 最终背光贡献
    EmissionOut = translucency * LightColor * TranslucencyColor * Albedo;
}

// 如果要用 half 精度（性能更好），用这个版本：
void JadeSSS_Translucency_half(
    half3 WorldNormal,
    half3 WorldViewDir,
    half3 LightDirection,
    half3 Albedo,
    half3 TranslucencyColor,
    half NormalPerturbation,
    half Power,
    half Strength,
    half Attenuation,
    half3 LightColor,
    out half3 EmissionOut
)
{
    half3 L = LightDirection;
    half3 N = normalize(WorldNormal);
    half3 V = normalize(WorldViewDir);

    half translucency = dot(V, -(L + NormalPerturbation * N));
    translucency = saturate(pow(translucency, Power));
    translucency *= Strength;
    translucency *= Attenuation;

    EmissionOut = translucency * LightColor * TranslucencyColor * Albedo;
}
