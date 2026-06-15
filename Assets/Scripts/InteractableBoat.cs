using UnityEngine;
using StarterAssets;

/// <summary>
/// 划船交互系统。
/// 玩家靠近船按 E 上船 → 禁用第三人称控制，船读取 WASD 移动 → 按 E 下船恢复控制。
/// 船只能在标记为 Water 的区域移动，离开水面自动停下。
///
/// 完整配置说明见脚本尾部注释。
/// </summary>
public class InteractableBoat : MonoBehaviour
{
    [Header("站位")]
    [Tooltip("玩家在船上的相对位置（相对于船的中心点）")]
    public Vector3 mountOffset = new Vector3(0f, 0.6f, 0f);

    [Header("移动参数")]
    [Tooltip("船移动速度")]
    public float moveSpeed = 5f;
    [Tooltip("船旋转速度")]
    public float rotationSpeed = 8f;

    [Header("水域限制")]
    [Tooltip("勾选后船只能在 Water 水体上移动")]
    public bool restrictToWater = true;
    [Tooltip("检测水体的探测器半径（船中心周围多远检测 Water 碰撞体）")]
    public float waterCheckRadius = 1f;
    [Tooltip("检测水体的层级，默认设为 Water 层")]
    public LayerMask waterLayer = 1 << 4;  // 默认 Unity Layer 4 = Water

    [Header("交互")]
    [Tooltip("玩家靠近船多少单位内可按 E 上船")]
    public float interactRange = 3f;
    [Tooltip("下船时玩家相对于船的偏移（世界坐标方向）")]
    public Vector3 dismountOffset = new Vector3(0f, 0f, 2.5f);

    [Header("调试")]
    public bool showDebugInfo = true;

    // ─── 运行时状态 ───
    private bool _isMounted;
    private Transform _player;
    private ThirdPersonController _playerController;
    private StarterAssetsInputs _playerInputs;
    private CharacterController _playerCharController;
    private Collider _playerCollider;
    private Animator _playerAnimator;
    private FixedDeadZoneCamera _camera;

    // 静态锁：防止玩家同时上多艘船
    private static bool _anyoneMounted;

    private void Start()
    {
        GameObject playerGo = GameObject.FindGameObjectWithTag("Player");
        if (playerGo == null)
        {
            Debug.LogError("InteractableBoat: 场景中找不到 Tag 为 'Player' 的对象！");
            enabled = false;
            return;
        }

        _player = playerGo.transform;
        _playerController = _player.GetComponent<ThirdPersonController>();
        _playerInputs = _player.GetComponent<StarterAssetsInputs>();
        _playerCharController = _player.GetComponent<CharacterController>();
        _playerCollider = _player.GetComponent<Collider>();
        _playerAnimator = _player.GetComponent<Animator>();

        // 找到相机脚本
        _camera = FindAnyObjectByType<FixedDeadZoneCamera>();
    }

    private void Update()
    {
        if (_isMounted)
        {
            if (Input.GetKeyDown(KeyCode.E))
                Dismount();
            else
                HandleBoatMovement();
        }
        else
        {
            if (!_anyoneMounted
                && Input.GetKeyDown(KeyCode.E)
                && IsPlayerInRange()
                && AmIClosestBoat())
                Mount();
        }

        if (showDebugInfo && !_isMounted && IsPlayerInRange() && !_anyoneMounted)
        {
            Debug.Log("🛶 按 E 上船");
        }
    }

    private void LateUpdate()
    {
        if (_isMounted && _player != null)
        {
            _player.position = transform.position
                             + transform.TransformDirection(mountOffset);
        }
    }

    // ════════════════════════════════════════
    //  上船 / 下船
    // ════════════════════════════════════════

    public void Mount()
    {
        if (_player == null || _anyoneMounted) return;

        if (_playerController) _playerController.enabled = false;
        if (_playerInputs) _playerInputs.enabled = false;
        if (_playerCharController) _playerCharController.enabled = false;
        if (_playerCollider) _playerCollider.enabled = false;
        if (_playerAnimator) _playerAnimator.speed = 0f;

        _player.position = transform.position
                         + transform.TransformDirection(mountOffset);
        _player.SetParent(null);

        _isMounted = true;
        _anyoneMounted = true;

        // 切换相机为船上模式
        if (_camera != null) _camera.SetBoatMode(true);

        Debug.Log("🛶 上船了！WASD 划船，按 E 下船");
    }

    public void Dismount()
    {
        if (_player == null) return;

        Vector3 flatPos = transform.position + dismountOffset;
        flatPos.y = GetGroundHeight(flatPos);
        if (_playerCharController) _playerCharController.enabled = false;

        _player.position = flatPos;
        _player.rotation = Quaternion.identity;

        // 等一帧让 Transform 刷新再恢复组件，避免 CC 穿模
        StartCoroutine(DelayedRestore());

        _isMounted = false;
        _anyoneMounted = false;

        // 切换相机为陆地模式
        if (_camera != null) _camera.SetBoatMode(false);

        Debug.Log("🦶 下船了");
    }

    private System.Collections.IEnumerator DelayedRestore()
    {
        yield return null;

        if (_playerController) _playerController.enabled = true;
        if (_playerInputs) _playerInputs.enabled = true;
        if (_playerCharController) _playerCharController.enabled = true;
        if (_playerCollider) _playerCollider.enabled = true;
        if (_playerAnimator) _playerAnimator.speed = 1f;
    }

    private float GetGroundHeight(Vector3 position)
    {
        float maxDist = 50f;
        if (Physics.Raycast(position + Vector3.up * 10f, Vector3.down, out RaycastHit hit, maxDist))
        {
            float charHalfHeight = _playerCharController != null
                ? _playerCharController.height * 0.5f
                : 0.9f;
            return hit.point.y + charHalfHeight;
        }
        return position.y;
    }

    // ════════════════════════════════════════
    //  船移动 + 水域检测
    // ════════════════════════════════════════

    private void HandleBoatMovement()
    {
        Vector2 input = Vector2.zero;

        if (Input.GetKey(KeyCode.W) || Input.GetKey(KeyCode.UpArrow))    input.y = 1f;
        if (Input.GetKey(KeyCode.S) || Input.GetKey(KeyCode.DownArrow))  input.y = -1f;
        if (Input.GetKey(KeyCode.A) || Input.GetKey(KeyCode.LeftArrow))  input.x = -1f;
        if (Input.GetKey(KeyCode.D) || Input.GetKey(KeyCode.RightArrow)) input.x = 1f;

        Vector3 moveDir = new Vector3(input.x, 0f, input.y).normalized;

        if (moveDir.magnitude > 0.01f)
        {
            // ── 计算下一步位置 ──
            Vector3 nextPos = transform.position + moveDir * (moveSpeed * Time.deltaTime);

            // ── 水域限制：如果启用了且目标位置不在水中 → 不动 ──
            if (restrictToWater && !IsInWater(nextPos))
            {
                if (showDebugInfo)
                    Debug.Log("💧 到岸了，船不能继续前进");
                return;
            }

            // 平滑转向
            Quaternion targetRot = Quaternion.LookRotation(moveDir);
            transform.rotation = Quaternion.Slerp(
                transform.rotation, targetRot, rotationSpeed * Time.deltaTime
            );

            transform.position = nextPos;
        }
    }

    /// <summary>
    /// 检测某个位置是否在水体上。
    /// 在目标位置发射一个球形检测，看是否能碰到 Water 层级的碰撞体。
    /// </summary>
    private bool IsInWater(Vector3 position)
    {
        Collider[] hits = Physics.OverlapSphere(position, waterCheckRadius, waterLayer);
        return hits.Length > 0;
    }

    // ════════════════════════════════════════
    //  辅助判定
    // ════════════════════════════════════════

    private bool IsPlayerInRange()
    {
        if (_player == null) return false;

        Vector3 selfFlat  = Flat(transform.position);
        Vector3 playerFlat = Flat(_player.position);

        return Vector3.Distance(selfFlat, playerFlat) <= interactRange;
    }

    private bool AmIClosestBoat()
    {
        InteractableBoat[] allBoats = FindObjectsByType<InteractableBoat>(
            FindObjectsSortMode.None
        );

        float myDist = Vector3.Distance(Flat(transform.position), Flat(_player.position));

        foreach (var boat in allBoats)
        {
            if (boat == this || boat == null) continue;

            float d = Vector3.Distance(Flat(boat.transform.position), Flat(_player.position));
            if (d < myDist) return false;
        }

        return true;
    }

    private static Vector3 Flat(Vector3 v)
    {
        v.y = 0f;
        return v;
    }

    // ─── Editor 辅助 ───
    private void OnDrawGizmosSelected()
    {
        Gizmos.color = new Color(0f, 0.5f, 1f, 0.15f);
        Gizmos.DrawWireSphere(transform.position, interactRange);

        Gizmos.color = Color.cyan;
        Vector3 mountWorld = transform.position + transform.TransformDirection(mountOffset);
        Gizmos.DrawWireSphere(mountWorld, 0.3f);
        Gizmos.DrawLine(transform.position, mountWorld);

        Gizmos.color = Color.green;
        Vector3 dismountWorld = transform.position + dismountOffset;
        Gizmos.DrawWireSphere(dismountWorld, 0.3f);

        // 水体检测范围
        if (restrictToWater)
        {
            Gizmos.color = new Color(0f, 0.4f, 1f, 0.3f);
            Gizmos.DrawWireSphere(transform.position, waterCheckRadius);
        }
    }

    // ═══════════════════════════════════════════════════════════════
    //                         配 置 指 南
    // ═══════════════════════════════════════════════════════════════
    //
    //  【1. 确保玩家设置正确】
    //       玩家的根 GameObject 的 Tag 设为 "Player"
    //       玩家的根上需要有以下组件（Starter Assets 默认就有）：
    //         - ThirdPersonController
    //         - StarterAssetsInputs
    //         - CharacterController
    //         - Collider (CapsuleCollider)
    //         - Animator
    //
    //  【2. 准备水域】
    //       在场景中添加一个水面（Plane / Quad / 自定义水面模型）
    //       ⚠️ 关键步骤：给水面（或其子物体）添加 Collider（BoxCollider 最省），勾选 Is Trigger
    //       ⚠️ 关键步骤：把该 Collider 所在的 GameObject 的 Layer 设为 "Water"
    //         （如果工程没有 Water 层，去 Edit → Project Settings → Tags and Layers 添加）
    //       如果水面很大，可以用多个 Box Collider 拼接覆盖水域范围。
    //
    //  【3. 给船挂脚本】
    //       选中船的 GameObject → Add Component → InteractableBoat
    //
    //  【4. 调参数】
    //       参数 | 建议初值 | 说明
    //       ─────┼─────────┼─────
    //       mountOffset    | (0, 0.6, 0)  | 玩家站在船面上方多高，看模型调 Y
    //       moveSpeed      | 5            | 船移动速度
    //       rotationSpeed  | 8            | 船转向平滑度
    //       restrictToWater| ✅ 勾选       | 船只能在水上移动
    //       waterCheckRadius| 1           | 船中心检测水体的半径
    //       waterLayer     | Water (4)    | 水体的 Unity Layer 编号
    //       interactRange  | 3            | 靠近多远按 E 可上船
    //       dismountOffset | (0, 0, 2.5)  | 下船时跳到船旁边什么位置
    //
    //  【5. 检查船的 Collider】
    //       确保船身上有 Collider（Box Collider 或 Mesh Collider），
    //       用于玩家靠近时的物理检测（不用设 Trigger）。
    //
    //  【6. 测试】
    //       靠近船 → 控制台显示 "🛶 按 E 上船"
    //       按 E → 上船，WASD 划船
    //       船靠近岸边的水体边界 → 自动停下，无法上岸
    //       按 E → 下船，恢复正常行走
    //
    //  【7. 常见问题 - 船无法检测到水】
    //       a) 确认水面的 Layer 正确设为 Water（数字 4）
    //       b) 确认 waterLayer 参数选的是 Water
    //       c) 确认水面 Collider 勾了 Is Trigger
    //       d) 在 Scene 视图中选中船，看看 Gizmo 小圆是否与水体重叠
    //       e) 如果 waterCheckRadius 太小（如 0.1），增大到 1~2
    //
    // ═══════════════════════════════════════════════════════════════
}
