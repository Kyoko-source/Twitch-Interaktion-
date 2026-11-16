class_name ElfPlayer
extends CharacterBody3D
## The elf in first person: walk (WASD, Shift runs), look (mouse), interact (E / left click),
## drop what you hold (F), tools in the hotbar (1–4, wheel). Your own arms are rigged and grip.

signal interact(action: String)
signal drop_requested
signal stepped(outside: bool)

const SPEED := 3.6
const RUN := 1.65
const REACH := 2.6

var camera: Camera3D
var ray: RayCast3D
var arms: Node3D
var arm_l: Node3D
var arm_r: Node3D
var bones := {}          # arm -> {name: bone index}
var skeletons := {}
var held: Node3D         # item shown in the hands (dough, tool)
var sensitivity := 0.0022
var active := false
var tool := 0            # 0 hand, 1 rolling pin, 2 star cutter, 3 tray
var anim := {}           # action -> 1..0
var bob := 0.0
var step_clock := 0.0
var look_target: Dictionary = {}
var auto_path: Array = []
var auto_then := ""
var outside_fn: Callable

func build(arm_scene: PackedScene) -> void:
	var shape := CapsuleShape3D.new(); shape.radius = 0.3; shape.height = 1.7
	var col := CollisionShape3D.new(); col.shape = shape; col.position.y = 0.85; add_child(col)
	camera = Camera3D.new(); camera.fov = 72; camera.near = 0.03; camera.far = 120; camera.position.y = 1.6; add_child(camera)
	camera.current = true
	ray = RayCast3D.new(); ray.target_position = Vector3(0, 0, -REACH - 0.6); ray.collision_mask = 2; ray.collide_with_areas = true; ray.collide_with_bodies = false; camera.add_child(ray)
	arms = Node3D.new(); camera.add_child(arms)
	arm_r = _arm(arm_scene, 1.0); arm_l = _arm(arm_scene, -1.0)

func _arm(scene: PackedScene, side: float) -> Node3D:
	var a := scene.instantiate() as Node3D
	a.scale = Vector3(side * 0.85, 0.85, 0.85)
	arms.add_child(a)
	var sk := a.find_children("*", "Skeleton3D", true, false)
	if sk.size():
		var s: Skeleton3D = sk[0]
		skeletons[a] = s
		var map := {}
		for i in s.get_bone_count(): map[s.get_bone_name(i)] = i
		bones[a] = map
	for m in a.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(m as MeshInstance3D).layers = 1
	return a

func capture() -> void:
	active = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func release() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * sensitivity
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.35, 1.25)
		auto_path.clear()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not get_parent().paused_ui: capture()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			use()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			tool = (tool + 3) % 4
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			tool = (tool + 1) % 4
	elif event.is_action_pressed("interact"):
		use()
	elif event.is_action_pressed("drop"):
		drop_requested.emit()
	else:
		for i in 4:
			if event.is_action_pressed("tool_%d" % (i + 1)): tool = i

func use() -> void:
	if look_target.has("action") and look_target.near:
		interact.emit(look_target.action)
	elif look_target.has("action"):
		go_to(look_target.action)

# walk automatically (hotbar buttons, touch, space bar): through the door if needed
func go_to_point(points: Array, then: String) -> void:
	auto_path = points; auto_then = then

func go_to(action: String) -> void:
	go_to_point(get_parent().route_for(action, global_position), action)

func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	var input := Input.get_vector("left", "right", "forward", "back")
	if input.length() > 0.05:
		auto_path.clear()
		dir = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
		var sp := SPEED * (RUN if Input.is_action_pressed("run") else 1.0)
		velocity.x = dir.x * sp; velocity.z = dir.z * sp
	elif auto_path.size():
		var p: Dictionary = auto_path[0]
		var to := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
		if to.length() < 0.2:
			auto_path.pop_front()
			if auto_path.is_empty():
				if p.has("yaw"):
					rotation.y = p.yaw
					camera.rotation.x = -0.5
				velocity = Vector3.ZERO
				var then := auto_then; auto_then = ""
				if then != "": interact.emit(then)
		else:
			var want := atan2(-to.x, -to.z)
			rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 8.0))
			camera.rotation.x = lerpf(camera.rotation.x, -0.35, minf(1.0, delta * 4.0))
			dir = to.normalized()
			velocity.x = dir.x * 4.2; velocity.z = dir.z * 4.2
	else:
		velocity.x = move_toward(velocity.x, 0, 30 * delta); velocity.z = move_toward(velocity.z, 0, 30 * delta)
	if not is_on_floor(): velocity.y -= 18 * delta
	else: velocity.y = -0.1
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.5
	if moving:
		bob += delta * 10.0
		step_clock += delta * Vector2(velocity.x, velocity.z).length()
		if step_clock > 1.45:
			step_clock = 0.0
			stepped.emit(outside_fn.call(global_position) if outside_fn.is_valid() else false)
	camera.position.y = 1.6 + (sin(bob) * 0.025 if moving else 0.0)
	# what is under the crosshair
	look_target = {}
	if ray.is_colliding():
		var c = ray.get_collider()
		var dist := camera.global_position.distance_to(ray.get_collision_point())
		if c and c.has_meta("action"):
			look_target = {"action": c.get_meta("action"), "near": dist <= REACH, "dist": dist}

# ---------------------------------------------------------------- hands
func animate(delta: float, t: float, state: Dictionary) -> void:
	for k in anim.keys(): anim[k] = maxf(0.0, anim[k] - delta * 2.4)
	var e := func(k: String) -> float: return sin(PI * clampf(1.0 - anim.get(k, 0.0), 0, 1)) if anim.get(k, 0.0) > 0 else 0.0
	var take: float = e.call("take")
	var roll: float = maxf(e.call("roll"), maxf(e.call("rolled"), e.call("crank")))
	var cut: float = maxf(e.call("cut"), e.call("press"))
	var load: float = maxf(e.call("load"), e.call("portion"))
	var lp := Vector3(-0.2, -0.27, -0.5)
	var rp := Vector3(0.2, -0.27, -0.5)
	var rot_l := -0.18
	var rot_r := -0.18
	if take > 0:
		lp += Vector3(0.06, -0.08, -0.22) * take; rp += Vector3(-0.06, -0.08, -0.22) * take; rot_l += take * 0.6; rot_r += take * 0.6
	if roll > 0:
		var sw := sin(t * 16.0) * 0.07
		lp += Vector3(0.06, -0.05, -0.18 + sw) * roll; rp += Vector3(-0.06, -0.05, -0.18 + sw) * roll; rot_l += roll * 0.5; rot_r += roll * 0.5
	if cut > 0:
		rp += Vector3(-0.08, -0.1 * cut, -0.2) * cut; rot_r += cut * 0.7
	if load > 0:
		lp += Vector3(0.05, 0.05, -0.25) * load; rp += Vector3(-0.05, 0.05, -0.25) * load
	var walk := sin(bob) * 0.012
	arm_l.position = lp + Vector3(0, walk, 0); arm_r.position = rp - Vector3(0, walk, 0)
	arm_l.rotation = Vector3(rot_l, -0.12, 0); arm_r.rotation = Vector3(rot_r, 0.12, 0)
	var holding: bool = state.get("holding", false)
	var g := 0.18
	var th := 0.15
	if holding or tool > 0:
		g = 0.62; th = 0.55
	if take > 0: g = 0.1 + (1.0 - take) * 0.5
	if roll > 0: g = 0.95; th = 0.85
	_grip(arm_l, g, th)
	_grip(arm_r, maxf(g, 1.05 if cut > 0 else 0.0), th)

func _grip(arm: Node3D, curl: float, thumb: float) -> void:
	if not skeletons.has(arm): return
	var s: Skeleton3D = skeletons[arm]
	var map: Dictionary = bones[arm]
	for f in ["index", "middle", "ring", "little"]:
		for j in [1, 2, 3]:
			var key := "%s%d" % [f, j]
			if not map.has(key): continue
			var i: int = map[key]
			var rest := s.get_bone_rest(i).basis.get_rotation_quaternion()
			s.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, -curl * (1.1 if j == 1 else (1.3 if j == 2 else 0.9))))
	for j in [1, 2, 3]:
		var key := "thumb%d" % j
		if not map.has(key): continue
		var i: int = map[key]
		var rest := s.get_bone_rest(i).basis.get_rotation_quaternion()
		s.set_bone_pose_rotation(i, rest * Quaternion(Vector3.RIGHT, -thumb * (0.5 if j == 1 else 0.8)))
