# Shader Graph 创建 PBR 材质 — 完整教学指南

> 基于 Unity Learn 官方教程 *ShaderGraph: PBR Material*  
> 适用于 Unity URP 项目（如你的 Liangzhu 项目）

---

## 一、什么是 PBR？

**PBR（Physically Based Rendering，基于物理的渲染）** 是一种模拟光线与材质交互的渲染方法，核心目标是用一组统一的参数让材质在各种光照条件下表现一致。

### PBR 的两大工作流

| 工作流 | 核心参数 | 适用于 |
|--------|----------|--------|
| **Metallic（金属工作流）** | BaseColor + Metallic + Smoothness | 金属、石头、陶瓷、玉石 |
| **Specular（镜面工作流）** | BaseColor + Specular + Smoothness | 非金属、织物、皮肤 |

你的项目中使用的是 **Metallic 工作流**，这也是 URP Lit Shader 和我们的 `Jade_SSS.shader` 使用的模式。

---

## 二、Shader Graph 中的 PBR Master Node

在 Shader Graph 中，**PBR Master Node** 是最终输出节点，它包含了所有 PBR 输入端口：

![PBR Master Node 示意图](https://docs.unity3d.com/Packages/com.unity.shadergraph@14.0/manual/images/PBRMasterNode.png)

### 各输入端口详解

| 端口 | 类型 | 说明 |
|------|------|------|
| **Vertex Position** | Vector3 | 顶点位置偏移（如波浪效果） |
| **Vertex Normal** | Vector3 | 顶点法线偏移（如法线贴图） |
| **Vertex Tangent** | Vector3 | 顶点切线偏移 |
| **Albedo** | Vector3 | **基础颜色**（漫反射颜色），金属工作流中金属的反射颜色也由此控制 |
| **Normal** | Vector3 | **法线贴图**（Tangent Space），制造凹凸细节 |
| **Emission** | Vector3 | **自发光颜色**，不受光照影响 |
| **Metallic** | float | **金属度**（0=非金属，1=金属） |
| **Smoothness** | float | **光滑度**（0=粗糙，1=镜面），通常从 Roughness 贴图转换而来（Smoothness = 1 - Roughness） |
| **Occlusion** | float | **环境光遮蔽**（AO），模拟缝隙中的阴影 |
| **Alpha** | float | **透明度**（1=不透明，0=全透明） |
| **AlphaClipThreshold** | float | 透明裁切阈值（Alpha Clip） |

---

## 三、在 URP 中创建 Shader Graph PBR 材质 — 分步教学

### 步骤 1：创建 Shader Graph 文件

1. 在 Project 窗口中右键 → `Create` → `Shader Graph` → `URP` → `Lit Shader Graph`
2. 命名为 `Jade_SSS_SG`（或者其他你喜欢的名字）

> **注意**：URP 模板中 `Lit Shader Graph` 默认就是 PBR Master Node。  
> 如果你创建的是 `Blank Shader Graph`，需要手动把 PBR Master Node 拖到图中。

### 步骤 2：创建 Material Properties（材质参数）

在 **Blackboard（黑板）** 面板中点击 `+` 号，添加以下属性：

| 属性名 | 类型 | 默认值 | 用途 |
|--------|------|--------|------|
| `_BaseMap` | Texture2D | white | 基础颜色贴图 |
| `_BaseColor` | Color | (1,1,1,1) | 颜色调色 |
| `_NormalMap` | Texture2D | bump | 法线贴图 |
| `_NormalScale` | Float | 1.0 | 法线强度 |
| `_MetallicMap` | Texture2D | white | 金属度贴图 |
| `_Metallic` | Float (Range 0-1) | 0 | 金属度系数 |
| `_RoughnessMap` | Texture2D | white | 粗糙度贴图 |
| `_Roughness` | Float (Range 0-1) | 0.5 | 粗糙度系数 |
| `_OcclusionMap` | Texture2D | white | AO贴图 |
| `_OcclusionStrength` | Float (Range 0-1) | 1.0 | AO强度 |

**如何添加：**
- 在 Blackboard 中点 `+` → 选择类型
- 按回车输入属性名
- 在右侧 Inspector 可以设置默认值、Range 范围等

### 步骤 3：构建节点图

这是核心部分，按以下顺序连接节点：

```
 ┌─────────────┐     ┌────────────────┐     ┌──────────────┐
 │ Sample Texture │     │ Multiply        │     │ PBR Master   │
 │ _BaseMap       │────▶│ _BaseColor      │────▶│ Albedo       │
 └─────────────┘     └────────────────┘     └──────────────┘
 
 ┌─────────────┐     ┌────────────────┐
 │ Sample Texture │     │ Normal Strength  │     ┌──────────────┐
 │ _NormalMap      │────▶│ (or直接连接)      │────▶│ Normal       │
 └─────────────┘     └────────────────┘     └──────────────┘
 
 ┌─────────────┐     ┌────────────────┐     ┌──────────────┐
 │ Sample Texture │     │ Multiply        │────▶│ Metallic     │
 │ _MetallicMap    │────▶│ _Metallic       │     └──────────────┘
 └─────────────┘     └────────────────┘
 
 ┌─────────────┐     ┌──────────────┐     ┌──────────────┐
 │ Sample Texture │     │ One Minus      │     │              │
 │ _RoughnessMap   │────▶│ (Rough→Smooth)│────▶│ Smoothness   │
 └─────────────┘     └──────────────┘     └──────────────┘
 
 ┌─────────────┐     ┌────────────────┐     ┌──────────────┐
 │ Sample Texture │     │ Lerp           │────▶│ Occlusion    │
 │ _OcclusionMap    │────▶│ (1 → AO * Str)│     └──────────────┘
 └─────────────┘     └────────────────┘
```

### 具体操作：

#### （1）创建 Sample Texture 2D 节点
- 右键 Graph → `Create Node` → 搜索 `Sample Texture 2D`
- 把每个 Texture 属性的引用拖到图中（从 Blackboard 拖属性到 Graph）
- 把属性连接到 Sample Texture 2D 的 Texture 输入端口

#### （2）Albedo（漫反射颜色）
1. `Sample Texture 2D (_BaseMap)` 的 RGBA 输出
2. 连接 `Multiply` 节点
3. `Color (_BaseColor)` 属性连接到 Multiply 的另一个输入
4. Multiply 的输出连接到 PBR Master 的 **Albedo** 端口

#### （3）法线贴图
1. `Sample Texture 2D (_NormalMap)` 
2. 右键创建 `Normal Strength` 节点
3. 传入 `_NormalScale` 控制强度
4. 输出连接 PBR Master 的 **Normal** 端口

> 也可以直接把 Sample Texture 2D 连到 Normal，但强度就无法调节了。

#### （4）金属度
1. `Sample Texture 2D (_MetallicMap)`，连接 R 通道（单通道）
2. 连接 `Multiply` 节点
3. `Float (_Metallic)` 属性连接 Multiply 另一输入
4. 输出连接 PBR Master 的 **Metallic** 端口

#### （5）粗糙度 → 光滑度转换
- PBR Master 的 Smoothness 端口需要的是**光滑度**（Smoothness）
- 你贴图是 **粗糙度**（Roughness）
- 需要一个 `One Minus` 节点转换：`Smoothness = 1 - Roughness`

```
Sample Texture 2D (_RoughnessMap) → Split (R) → One Minus → PBR Master Smoothness
```

#### （6）环境光遮蔽（AO）
```
Sample Texture 2D (_OcclusionMap) → Split (R) → Lerp(1, AO, _OcclusionStrength) → PBR Master Occlusion
```

### 步骤 4：保存并创建材质

1. 点击 Shader Graph 窗口左上角的 **Save Asset** 按钮
2. 在 Project 窗口选中 Shader Graph 文件
3. 右键 → `Create` → `Material`
4. 材质自动使用你的 Shader Graph
5. 把贴图拖入材质属性槽位即可

### 步骤 5：应用到模型

将材质拖到场景中的模型上。

---

## 四、PBR 节点图对比（手写 Shader vs Shader Graph）

| 功能 | 手写 Shader（HLSL） | Shader Graph |
|------|---------------------|--------------|
| Albedo | `_BaseMap * _BaseColor` | Sample2D + Multiply 节点 |
| Normal | `UnpackNormalScale()` | Normal Strength 节点 |
| Metallic | `_MetallicMap.r * _Metallic` | Sample2D + Multiply 节点 |
| Rough→Smooth | `1 - roughness` | One Minus 节点 |
| AO | `lerp(1, occ, _OccStr)` | Lerp 节点 |
| 光照计算 | `UniversalFragmentPBR()` | PBR Master 内置 |
| SSS 背光 | 需要手写 HLSL | 需用 Custom Function 节点 |

---

## 五、对于你的项目：手写 Shader 和 Shader Graph 的选择

你现在已经有了一个手写的 `Jade_SSS.shader`，它包含 **SSS 背光** 这个 Shader Graph PBR Master 节点无法原生支持的功能。

### 如果要复用我们的 SSS 背光到 Shader Graph

你需要使用 **Custom Function Node（自定义函数节点）**：

1. 创建一个 PBR Lit Shader Graph
2. 连接所有标准 PBR 输入（如上文）
3. 添加 `Custom Function` 节点
4. 在 Custom Function 中写入 SSS 背光代码：

```hlsl
void Translucency_float(
    float3 WorldNormal, float3 WorldViewDir,
    float3 LightDirection, float3 Albedo, float3 TranslucencyColor,
    float NormalPerturbation, float Power, float Strength,
    out float3 Emission
)
{
    float3 L = LightDirection;
    float3 N = WorldNormal;
    float3 V = WorldViewDir;
    
    float t = dot(V, -(L + NormalPerturbation * N));
    t = saturate(pow(t, Power)) * Strength;
    
    Emission = t * TranslucencyColor * Albedo;
}
```

然后把输出加到 PBR Master 的 Emission 端口。

---

## 总结

1. **Shader Graph 的 PBR Master Node** 覆盖了所有标准 PBR 参数（Albedo、Normal、Metallic、Smoothness、Occlusion、Emission）
2. 你不需要手写光照计算——PBR Master 自动使用 URP 的光照函数
3. 要扩展功能（如 SSS 背光），使用 **Custom Function Node**
4. 对于你的玉石项目，在 Shader Graph 中搭建标准 PBR + Custom Function SSS 是可行的

Sources:
- [ShaderGraph: PBR Material - Unity Learn](https://learn.unity.com/tutorial/shadergraph-pbr-material)
- [Unity Shader Graph Documentation](https://docs.unity3d.com/Packages/com.unity.shadergraph@14.0/manual/index.html)
- [llamacademy/urp-pbr-shader (GitHub)](https://github.com/llamacademy/urp-pbr-shader)
