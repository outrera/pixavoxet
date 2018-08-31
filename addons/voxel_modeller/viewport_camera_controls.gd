tool
extends ViewportContainer

var Voxel = preload("res://voxel.tscn")

var zooming_in = false
var zooming_out = false
var rotating = false
var panning = false
onready var camera = $Viewport/Camera
onready var temp_box = $Viewport/TempBox
onready var cursor = $Viewport/Cursor
onready var gridmap = $Viewport/GridMap
onready var matrix = get_node("Viewport/GridMap/Matrix")
var altmode = false
var toolmode = "box"
var temp_voxels = []
var changed = false
var drag_box = null
var drag_start = false
var drag_end = false
var thread = Thread.new()
var wait = 0

func _ready():
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
	PhysicsServer.set_active(true)

func zoom(delta):
	camera.size += delta
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

func delete():
	for p in temp_voxels:
		if(gridmap.get_cell_item(p[0],p[1],p[2]) != -1):
			gridmap.set_cell_item(p[0],p[1],p[2],-1)
	temp_voxels = []

func add():
	for p in temp_voxels:
		if(gridmap.get_cell_item(p[0],p[1],p[2]) == -1):
			gridmap.set_cell_item(p[0],p[1],p[2],p[3])
	temp_voxels = []

func _input(ev):
	if(ev is InputEventKey && ev.scancode == KEY_ALT && ev.is_pressed()):
		altmode = true
	if(ev is InputEventKey && ev.scancode == KEY_ALT && !ev.is_pressed()):
		altmode = false

func _process(delta):
	camera = $Viewport/Camera
	temp_box = $Viewport/TempBox
	cursor = $Viewport/Cursor
	gridmap = $Viewport/GridMap
	matrix = get_node("Viewport/GridMap/Matrix")
	if(wait == 10):
		wait = 0
		if(changed):
			if(!altmode):
				delete()
			else:
				add()
			temp_voxels = []
		if(drag_box && !drag_end):
			if(changed):
				if(!altmode):
					place_drag_box(true)
				else:
					delete_drag_box(true)
				changed = false
				$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
		if(drag_end):
			if(!altmode):
				#delete()
				place_drag_box(false)
			else:
				#add()
				delete_drag_box(false)
			$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
			temp_voxels = []
			drag_box = null
			drag_end = false
			gridmap.set_octant_size(16)
			gridmap.make_baked_meshes()
			var meshes = gridmap.get_bake_meshes()
			for child in $Viewport/GridMap/Collision.get_children():
				$Viewport/GridMap/Collision.remove_child(child)
				child.free()
			var transform = null
			for mesh in meshes:
				if(typeof(mesh) != TYPE_TRANSFORM):
					var col = CollisionShape.new()
#					col.shape = mesh.create_convex_shape()
					col.shape = mesh.create_trimesh_shape()
					$Viewport/GridMap/Collision.add_child(col)
			gridmap.set_octant_size(8)

	wait += 1
	var mouse_pos = get_node("Viewport").get_mouse_position()
	var box = matrix.box
	var size = matrix.box.size
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	var from = ray_origin
	var to = ray_origin + ray_direction * 1000000.0
	var state = camera.get_world().direct_space_state
	var hit = state.intersect_ray(from,to)
	if(!hit.empty()):
		var p = hit.position + (hit.normal.round() * .5)
		p = p.floor()
		p += Vector3(.5,.5,.5)
		if(cursor.translation != p):
			cursor.translation = p
			$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE
		if(drag_start && drag_box == null):
			if(!altmode):
				p = hit.position + (hit.normal.round() * .5)
			else:
				p = hit.position - (hit.normal.round() * .5)
			p = p.floor()
			p.x = min(size.x-1,p.x)
			p.x = max(0,p.x)
			p.y = min(size.y-1,p.y)
			p.y = max(0,p.y)
			p.z = min(size.z-1,p.z)
			p.z = max(0,p.z)
			drag_box = [p,p]
			changed = true
		if(drag_start):
			p = hit.position + (hit.normal.round() * .5)
			p = p.floor()
			p.x = min(size.x-1,p.x)
			p.x = max(0,p.x)
			p.y = min(size.y-1,p.y)
			p.y = max(0,p.y)
			p.z = min(size.z-1,p.z)
			p.z = max(0,p.z)
			if(drag_box[1] != p):
				drag_box[1] = p
				changed = true

func pan(ev):
	var t = camera.transform.orthonormalized()
	t = t.translated(Vector3(1,0,0) * -ev.relative.x * .05)
	t = t.translated(Vector3(0,1,0) * ev.relative.y * .05)
	camera.transform = t
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

func rotate(ev):
	var cam_c = camera
	var y = cam_c.transform.basis.y.y
	var trans = cam_c.translation
	if(abs(ev.relative.y) > abs(ev.relative.x)):
		var t = cam_c.global_transform.orthonormalized()
		t = t.rotated(-t.basis.x,-ev.relative.y * .005)
		if(t.basis.y.y > 0):
			cam_c.global_transform = t
		else:
			t = cam_c.global_transform.orthonormalized()
			t = t.rotated(-Vector3(0,1,0),ev.relative.y * .005)
			cam_c.transform = t
	else:
		var t = cam_c.transform.orthonormalized()
		t = t.rotated(-Vector3(0,1,0),ev.relative.x * .005)
		cam_c.transform = t
	$Viewport.render_target_update_mode = Viewport.UPDATE_ONCE

func gui_input(ev):
	if(ev is InputEventMouseButton && ev.button_index == BUTTON_WHEEL_UP):
		zoom(-1)
	if(ev is InputEventMouseButton && ev.button_index == BUTTON_WHEEL_DOWN):
		zoom(1)
	if(ev is InputEventMouseButton && ev.button_index == BUTTON_RIGHT && ev.pressed):
		rotating = true
	if(ev is InputEventMouseButton && ev.button_index == BUTTON_RIGHT && !ev.pressed):
		rotating = false
	if(ev is InputEventMouseButton && ev.button_index == BUTTON_MIDDLE && ev.pressed):
		panning = true
	if(ev is InputEventMouseButton && ev.button_index == BUTTON_MIDDLE && !ev.pressed):
		panning = false
	if(ev is InputEventMouseMotion && rotating && !ev.is_echo()):
		rotate(ev)
	if(ev is InputEventMouseMotion && panning && !ev.is_echo()):
		pan(ev)
	if(toolmode == "box"):
		if(ev is InputEventMouseButton && ev.button_index == 1 && ev.pressed && !ev.is_echo()):
			drag_start = true
			drag_end = false
		if(ev is InputEventMouseButton && ev.button_index == 1 && !ev.pressed && !ev.is_echo()):
			drag_start = false
			drag_end = true

func in_box(p):
	var min_x = min(drag_box[0].x,drag_box[1].x)
	var min_y = min(drag_box[0].y,drag_box[1].y)
	var min_z = min(drag_box[0].z,drag_box[1].z)
	var max_x = max(drag_box[0].x,drag_box[1].x)
	var max_y = max(drag_box[0].y,drag_box[1].y)
	var max_z = max(drag_box[0].z,drag_box[1].z)
	if(p.x < min_x || p.x > max_x || p.y < min_y || p.y > max_y || p.z < min_z || p.z > max_z):
		return false
	return true

func get_area(pos):
	var min_x = min(drag_box[0].x,pos.x)
	var min_y = min(drag_box[0].y,pos.y)
	var min_z = min(drag_box[0].z,pos.z)
	var max_x = max(drag_box[0].x,pos.x)
	var max_y = max(drag_box[0].y,pos.y)
	var max_z = max(drag_box[0].z,pos.z)

	var area = (max_x - min_x) * (max_y - min_y) * (max_z - min_z)
	return area

func delete_drag_box(temp):
	var min_x = min(drag_box[0].x,drag_box[1].x)
	var min_y = min(drag_box[0].y,drag_box[1].y)
	var min_z = min(drag_box[0].z,drag_box[1].z)
	var max_x = max(drag_box[0].x,drag_box[1].x)
	var max_y = max(drag_box[0].y,drag_box[1].y)
	var max_z = max(drag_box[0].z,drag_box[1].z)
	var voxels = []
	for x in range(min_x, max_x+1):
		for y in range(min_y, max_y+1):
			for z in range(min_z, max_z+1):
				var i = gridmap.get_cell_item(x,y,z)
				if(i != -1):
					gridmap.set_cell_item(x,y,z,-1)
					if(temp):
						temp_voxels.append([x,y,z,i])

func place_drag_box(temp):
	var color = get_node("Panel/VBoxContainer/ColorPicker").get_selected_material()
	var index = get_node("Panel/VBoxContainer/ColorPicker").selected_index
	if(!temp):
		print(index)
	var min_x = min(drag_box[0].x,drag_box[1].x)
	var min_y = min(drag_box[0].y,drag_box[1].y)
	var min_z = min(drag_box[0].z,drag_box[1].z)
	var max_x = max(drag_box[0].x,drag_box[1].x)
	var max_y = max(drag_box[0].y,drag_box[1].y)
	var max_z = max(drag_box[0].z,drag_box[1].z)
	for x in range(min_x, max_x+1):
		for y in range(min_y, max_y+1):
			for z in range(min_z, max_z+1):
				if(gridmap.get_cell_item(x,y,z) == -1):
					gridmap.theme.get_item_mesh(index).material = color
					gridmap.set_cell_item(x,y,z,index)
					if(temp):
						temp_voxels.append([x,y,z,index])