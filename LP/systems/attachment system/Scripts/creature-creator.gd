@tool
extends Node2D
class_name CreatureCreator

#Socket snap line
@export var snap_distance = 8.0
@export var show_line_distance = 25.0
@export var far_color = Color.RED
@export var close_color = Color.GREEN

# Dependencies
@onready var creature_root: Skeleton2D = $CreatureRoot
@export var m_tracker : mouse_tracker

#Arrays
var entities : Array[EntityPart]
var sockets : Array[AttachmentSocket]
var lines : Array[Line2D]


#We have to connect to the signal from this end
#So we inject the gui, and connect to its spawn signal
func inject_attachment_gui(gui : AttachmentGui):
	if not gui:
		push_error("gui is null in creature creator!")
		return
	if not gui.spawn_entity.is_connected(new_entity_in_scene):
		gui.spawn_entity.connect(new_entity_in_scene)
	if not gui.spawn_socket.is_connected(new_socket_in_scene):
		gui.spawn_socket.connect(new_socket_in_scene)
	

func new_entity_in_scene(entity : EntityPart):
	if not entity:
		push_error("Entity is null!")
		return
	add_entity_to_skeleton(entity)
	entities.push_back(entity)
	entity.tree_exited.connect(remove_entity.bind(entity))
	entity.tree_entered.connect(recall_entity.bind(entity))
	entity.inject_creature_creator(self)


func new_socket_in_scene(socket : AttachmentSocket):
	if not socket:
		push_error("socket is null!")
		return
	sockets.push_back(socket)
	socket.tree_exited.connect(remove_socket.bind(socket))
	if creature_root.get_modification_stack().modification_count != sockets.size():
		print("Not correct amount of stacks for amount of sockets!")
	#var newstack = SkeletonModification2DCCDIK.new()
	#creature_root.get_modification_stack().add_modification(newstack)


func add_entity_to_skeleton(entity : EntityPart):
	#Turn of the IK, and set pose, this is because the IK will go bananas if IK is active
	var stack : SkeletonModificationStack2D = creature_root.get_modification_stack()
	stack.enabled = false
	print("Please reset skeleton rest pose before enabling stack")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	entities = []
	sockets = []
	lines = []
	if not m_tracker:
		push_error("mouse tracker is null!")
		return
	m_tracker.stopped_dragging.connect(drop_entity)
	find_old_parts()


func find_old_parts():
	var root = get_tree().root
	# Call a recursive function to search for the parts
	search_for_parts(root)
	print("Found entities: " + str(entities.size()))
	print("Found sockets: " + str(sockets.size()))


func search_for_parts(node: Node) -> void:
	# Add parts and sockets
	if node is EntityPart:
		new_entity_in_scene(node)
	elif node is AttachmentSocket:
		new_socket_in_scene(node)
	# Recursively check all the children of this node
	for child in node.get_children():
		search_for_parts(child)


func clear_old_lines():
	if lines.size() > 0:
		for line in lines:
			line.queue_free()
		lines.clear()
		
		
#Update position of all entitites and sockets and draw lines between them
func _process(delta: float) -> void:
	clear_old_lines()
	if entities.size() > 0 and sockets.size() > 0:
		for entity in entities:
			if entity.recently_moved == false:
				continue
			var closest_socket : AttachmentSocket = null
			var closest_dist = INF
			for socket in sockets:
				var dist = entity.global_position.distance_to(socket.global_position)
				if dist < closest_dist:
					closest_dist = dist
					closest_socket = socket
					
			# Draw a line between socket and limb
			if closest_socket and closest_dist < show_line_distance:
				var line = Line2D.new()
				line.default_color = far_color
				var normalized_dist = clamp((closest_dist - 0.0) / (show_line_distance - 0.0), 0.0, 1.0)  # Normalize distance to a 0-1 range
				line.width = lerp(2.5, 0.1, normalized_dist)
				if closest_dist < snap_distance:
					entity.closest_socket = closest_socket
					line.default_color = close_color
					line.width = 3.0
				line.add_point(entity.global_position)
				line.add_point(closest_socket.global_position)
				line.begin_cap_mode = Line2D.LINE_CAP_ROUND
				line.end_cap_mode = Line2D.LINE_CAP_ROUND
				add_child(line)
				lines.push_back(line)


func remove_entity(entity : EntityPart):
	print("User removed an entity: " + entity.name)
	entities.erase(entity)
	
func recall_entity(entity : EntityPart):
	print("Part returned, reparented to: " + str(entity.get_parent()))
	entities.push_back(entity)

func remove_socket(socket : AttachmentSocket):
	print("User removed an entity: " + socket.name)
	sockets.erase(socket)


func drop_entity():
	for entity in entities:
		if entity.recently_moved:
			# Find closest socket if none is remembered
			var target_socket = entity.closest_socket
			if not target_socket:
				target_socket = find_closest_socket(target_socket, entity)
			try_snap(target_socket, entity)
			entity.recently_moved = false


func find_closest_socket(closest_socket, entity) -> AttachmentSocket:
	for socket in sockets:
		if entity.global_position.distance_to(socket.global_position) < snap_distance:
			closest_socket = socket
			print("null socket, snapping to closest")
	return closest_socket

func try_snap(target_socket, entity):
	# Snap to target socket if within range
	if target_socket and entity.global_position.distance_to(target_socket.global_position) < snap_distance:
		entity.snap_to_socket(target_socket)
		print("snapping to remembered socket" if entity.closest_socket else "snapping to closest socket")
		# Clear closest socket for future use
	entity.closest_socket = null
