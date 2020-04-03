extends KinematicBody

# Set NodePath to our Path node that contains the curve we follow. 
export (NodePath) var follow_path = null
var fp_node : Path = null
var curve : Curve3D = null
var curve_offset = 0.0
var curve_length = 0.0

var move_speed = 2.0

# for falling/jumping
export var gravity = 9.8
var half_height = 0.7
var fall_velocity = 0.0
var can_jump = false
export var jump_velocity = 5.0

func get_distance_to_ground():
	var distance = 100.0
	for raycast in $Raycasts.get_children():
		if raycast.is_colliding():
			var collision = raycast.get_collision_point()
			var col_dist = (collision - raycast.global_transform.origin).length()
			if col_dist < distance:
				distance = col_dist
	
	return distance

func _ready():
	# determine our characters half height
	half_height = $Gimble/Body.mesh.radius + $Gimble/Body.mesh.mid_height * 0.5
	
	# get some info about our path
	fp_node = get_node(follow_path)
	if fp_node is Path:
		curve = fp_node.curve
		if curve:
			# get the total length of our curve
			curve_length = curve.get_baked_length()

func _physics_process(delta):
	##############################################
	# Handle movement along our curve
	if curve:
		var was_position = global_transform.origin
		var new_offset = curve_offset
		
		# our offset relates to how far along the curve we've traveled
		if Input.is_action_pressed("ui_right"):
			new_offset = clamp(new_offset + delta * move_speed, 0.0, curve_length)
		if Input.is_action_pressed("ui_left"):
			new_offset = clamp(new_offset - delta * move_speed, 0.0, curve_length)
		
		# get the position at this offset 
		var target_position = fp_node.global_transform.xform(curve.interpolate_baked(new_offset))
		
		# calculate our movement vector needed to get there
		var movement = target_position - was_position
		
		# but ignore vertical movement.
		movement.y = 0.0
		
		# can we move?
		if !test_move(global_transform, movement):
			# then move
			move_and_collide(movement)
			
			# remember our new offset
			curve_offset = new_offset
		
			# find out how far we actually moved
			var actual_movement = global_transform.origin - was_position
			actual_movement.y = 0.0
			if actual_movement.length() > 0.0:
				# if we moved any distance, use that to determine our orientation
				$Gimble.look_at(global_transform.origin + actual_movement.normalized(), Vector3.UP)
	
	##############################################
	# Handle jumping and falling
	
	# handle jump
	if can_jump and Input.is_action_pressed("ui_select"):
		fall_velocity -= jump_velocity
	
	# calculate how far we're falling
	fall_velocity += delta * gravity
	var fall_distance = fall_velocity * delta
	
	# how far from the ground are we?
	var distance_to_ground = get_distance_to_ground() - half_height
	
	# will we hit the ground?
	if fall_distance > distance_to_ground:
		fall_velocity = 0
		transform.origin.y -= distance_to_ground
		#
		# we can only jump when we're on the ground
		can_jump = true
	else:
		transform.origin.y -= fall_distance
		can_jump = false
