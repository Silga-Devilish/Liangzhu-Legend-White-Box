using UnityEngine;

/// <summary>
/// 固定俯视角相机 —— 带死区追踪（巴别塔圣歌风格）
///
/// 逻辑：
/// 1. 相机固定在俯拍角度，永不旋转
/// 2. 死区中心 = 屏幕正中央对准的地面点（而非锚点）
/// 3. 玩家在死区内走动时，相机不动
/// 4. 玩家走出死区边界 → 锚点向玩家方向滑动 → 相机跟上 → 屏幕中心重新追上玩家
/// 5. 相机平滑 Lerp 跟随锚点，跟到位后再次停住
///
/// 安装步骤（不改动原有代码）：
/// - 禁掉 Main Camera 上的 CinemachineBrain 组件
/// - 禁掉或删除 PlayerFollowCamera 预制体实例
/// - 将此脚本挂到 Main Camera 上，绑定 Player 并调参
/// </summary>
[RequireComponent(typeof(Camera))]
public class FixedDeadZoneCamera : MonoBehaviour
{
    // ────────── 初始化模式 ──────────
    public enum InitMode
    {
        [InspectorName("按参数设置")]
        FromParameters,     // 用 height / offset / rotationAngles 初始化

        [InspectorName("保留场景位置")]
        UseSceneTransform,  // 保持相机在场景中手动摆放的位置
    }

    [Header("初始化")]
    [Tooltip("FromParameters = 用下方参数覆盖相机初始位置\n" +
             "UseSceneTransform = 保持相机在场景中的现有位置不动")]
    public InitMode initMode = InitMode.FromParameters;

    [Header("绑定")]
    [Tooltip("玩家角色根结点的 Transform")]
    public Transform player;

    [Header("相机姿态")]
    [Tooltip("相机架设高度（Y 轴距离地面锚点的距离）")]
    public float height = 25f;

    [Tooltip("相机相对地面锚点的水平偏移（世界坐标轴）\n" +
             "例: (5, 0, -3) = 锚点右侧 5 单位、后侧 3 单位")]
    public Vector3 offset = Vector3.zero;

    [Tooltip("相机旋转角度，默认 (90, 0, 0) 垂直下俯")]
    public Vector3 rotationAngles = new Vector3(90f, 0f, 0f);

    [Header("死区参数")]
    [Tooltip("玩家在屏幕中心地面点周围多少单位内走动时相机不动")]
    public float deadZoneRadius = 6f;

    [Tooltip("死区中心沿相机朝向的微调偏移量\n" +
             "负数 = 往相机方向拉，正数 = 远离相机方向推\n" +
             "用于微调死区中心在画面中的位置")]
    public float deadZoneCenterBias = 0f;

    [Tooltip("相机向目标位置缓动跟上的速度")]
    public float followSpeed = 3f;

    [Tooltip("锚点滑动的速度（应快于 followSpeed，产生镜头滞后感）")]
    public float anchorSpeed = 6f;

    // ——— 运行时状态 ———
    private Vector3 _anchor;                // 地面锚点（决定相机位置的参考点）
    private Vector3 _cameraTargetPosition;  // 相机目标位置
    private Vector3 _runtimeOffset;         // 运行时实际使用的偏移
    private float   _runtimeHeight;         // 运行时实际使用的高度

    // 缓存：每次 LateUpdate 计算的屏幕中心地面点
    private Vector3 _screenCenterGround;

    private void Start()
    {
        if (player == null)
        {
            Debug.LogError("FixedDeadZoneCamera: player 未绑定！");
            enabled = false;
            return;
        }

        switch (initMode)
        {
            case InitMode.FromParameters:
                InitFromParameters();
                break;

            case InitMode.UseSceneTransform:
                InitFromSceneTransform();
                break;
        }
    }

    private void LateUpdate()
    {
        // ── 1. 计算当前屏幕正中央对准的地面点 ──
        _screenCenterGround = ComputeScreenCenterGround();

        Vector3 playerFlat = Flatten(player.position);

        float distance = Vector3.Distance(playerFlat, _screenCenterGround);

        // ── 2. 死区判定：用屏幕中心而非锚点 ──
        if (distance > deadZoneRadius)
        {
            // 玩家走出了死区 → 锚点向玩家方向推
            Vector3 direction = (playerFlat - _screenCenterGround).normalized;
            float overshoot = distance - deadZoneRadius;

            Vector3 newAnchor = _anchor + direction * overshoot;

            _anchor = Vector3.Lerp(
                _anchor,
                newAnchor,
                anchorSpeed * Time.deltaTime
            );
        }

        // ── 3. 计算相机目标位置（始终相对锚点） ──
        _cameraTargetPosition = _anchor
                              + _runtimeOffset
                              + Vector3.up * _runtimeHeight;

        // ── 4. 相机平滑跟随 ──
        transform.position = Vector3.Lerp(
            transform.position,
            _cameraTargetPosition,
            followSpeed * Time.deltaTime
        );

        // ── 5. 保持固定旋转 ──
        transform.eulerAngles = rotationAngles;
    }

    // ════════════════════════════════════════
    //  屏幕中心地面点（核心方法）
    // ════════════════════════════════════════

    /// <summary>
    /// 计算死区中心地面点。
    /// 以屏幕正中央为基准，沿相机朝向微调 deadZoneCenterBias 距离。
    /// 无论相机是否有 offset 或角度，这就是"画面中心在哪里"。
    /// </summary>
    private Vector3 ComputeScreenCenterGround()
    {
        Plane groundPlane = new Plane(Vector3.up, 0f);
        Ray centerRay = new Ray(transform.position, transform.forward);

        if (groundPlane.Raycast(centerRay, out float enter))
        {
            Vector3 hitPoint = centerRay.GetPoint(enter);

            // 沿地面上的相机 forward 方向投影做微调
            Vector3 forwardFlat = Flatten(transform.forward).normalized;
            return hitPoint + forwardFlat * deadZoneCenterBias;
        }

        // 安全回退（相机几乎水平看时用投影）
        return Flatten(transform.position);
    }

    // ════════════════════════════════════════
    //  初始化逻辑
    // ════════════════════════════════════════

    private void InitFromParameters()
    {
        _runtimeHeight = height;
        _runtimeOffset = offset;

        _anchor = Flatten(player.position);

        Vector3 startPos = _anchor + _runtimeOffset + Vector3.up * _runtimeHeight;
        transform.position = startPos;
        transform.eulerAngles = rotationAngles;

        _cameraTargetPosition = transform.position;
    }

    private void InitFromSceneTransform()
    {
        _anchor = Flatten(player.position);

        Vector3 rel = transform.position - _anchor;
        _runtimeOffset = Flatten(rel);
        _runtimeHeight = transform.position.y;

        _cameraTargetPosition = transform.position;
    }

    // ════════════════════════════════════════
    //  工具方法
    // ════════════════════════════════════════

    private static Vector3 Flatten(Vector3 v)
    {
        v.y = 0f;
        return v;
    }

    // ─── Editor 辅助可视化 ───
    private void OnDrawGizmosSelected()
    {
        if (player == null) return;

        // 运行时用实际的屏幕中心，编辑时用相机投影
        Vector3 deadCenter = Application.isPlaying
            ? _screenCenterGround
            : Flatten(transform.position) + Flatten(transform.forward).normalized * deadZoneCenterBias;

        // 死区（绿色）
        Gizmos.color = new Color(0f, 1f, 0f, 0.2f);
        Gizmos.DrawWireSphere(deadCenter, deadZoneRadius);

        // 玩家到死区中心的连线（黄色）
        Gizmos.color = Color.yellow;
        Gizmos.DrawLine(Flatten(player.position), deadCenter);

        // 锚点到相机位置的示意（青色）
        Gizmos.color = Color.cyan;
        Vector3 anchorPos = Application.isPlaying
            ? _anchor
            : deadCenter;

        Vector3 camTarget = anchorPos + offset + Vector3.up * height;
        Gizmos.DrawLine(anchorPos, camTarget);
        Gizmos.DrawWireSphere(camTarget, 0.3f);
    }
}
