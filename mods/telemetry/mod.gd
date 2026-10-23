extends Node
## Telemetry recorder: writes every physics step of the player's car to one log per session,
## user://telemetry/<date>_<track>_<session>_<driver>.ttlog. Line 1 is a JSON header (session info, start time and
## the telemetry data version), then one JSON object per lap and line:
##   {"lap":2,"time":19.089,"invalid":false,"front_wing":50,"rear_wing":50,"sector_times":[...],"samples":[[...],...]}
## Samples are arrays of the values _sample returns. Which value is which is defined by the data version;
## analysis.html has the list of values for every version.
## Only completed laps are saved: a lap's samples are kept in memory and written together with its result
## once the lap counter moves on to the next lap.
##
## Rewinds and all analysis are handled in analysis.html (next to this file). The log is flushed after
## every lap line, so a lap shows up in the page once it's done and the folder is read again.

const RECORD_ROOT := "user://telemetry"
const DATA_VERSION := "1.0"
var _track: Track
var _file: FileAccess
var _samples: Array[Array] = []  # samples of the lap in progress
var _recording := false


func _ready() -> void:
	#Create the telemetry folder
	DirAccess.make_dir_absolute(RECORD_ROOT)

	#Connect to the node_added signal
	get_tree().node_added.connect(_on_node_added)

	# Time-trial lap restart signal: Clear all collected samples
	TimeAttackManager.restarted.connect(_samples.clear)

func _on_node_added(node: Node) -> void:
	#We only care about the Track node for telemetry data
	if not node is Track:
		return
	
	#Bind to the track initialization signal
	node.initialized.connect(_on_track_initialized.bind(node))

	#Bind to node exit signal to close the telemetry file when a session ends
	node.tree_exiting.connect(_on_track_exiting.bind(node))

func _on_track_initialized(track: Track) -> void:
	#Review finding:  Quick sims and previews can contain the player's car but aren't driven
	if track.player == null or track.params.simulate or track.params.is_preview:
		return

	_samples.clear()
	_recording = false
	_track = track

	#Bind to the physics step signal
	track.player.step_processed.connect(_on_player_step)

	#Bind to the lap signal
	track.player.lap_completed.connect(_on_lap_completed)

	#lap_started is called only when the car passes the start line for the first time in time trial or races
	track.player.lap_started.connect(_start_recording)

func _start_recording() -> void:
	_samples.clear()
	_recording = true
	

func _on_lap_completed(lap: Lap) -> void:
	if lap == null or _samples.is_empty():
		return

	if _file == null and not _open_file():
		return
		
	# sort_keys = false keeps this key order, so the samples come last
	_file.store_line(JSON.stringify({
		lap = _track.player.laps.size(),
		time = _num(lap.time, 0.00001),
		invalid = lap.invalid,
		front_wing = roundi(_track.player.setup.front_wing * 100),
		rear_wing = roundi(_track.player.setup.rear_wing * 100),
		sector_times = lap.sector_times.values().map(_num.bind(0.00001)),
		samples = _samples,
		}, "", false))
	_file.flush()
	_samples.clear()


func _on_player_step(_delta: float) -> void:
	#Only record if we are over the start line and the player has not finished the race yet
	if not _recording or _track.player.is_finished:
		return
	
	_samples.append(_sample(_track.player))

# Only the track being recorded ends the log; an old one can leave after the next has started
func _on_track_exiting(track: Track) -> void:
	if track == _track:
		_close_file_if_exists()

func _exit_tree() -> void:
	_close_file_if_exists()
	
# The log is created with the first completed lap, so sessions without one leave no file
func _open_file() -> bool:
	var car := _track.player
	var profile: TrackProfile = _track.params.profile
	var started := Time.get_datetime_string_from_system()  # 2026-10-14T17:22:35, local time
	var session_data:= {
		track = profile.track_name if profile else "",
		session = Session.Type.find_key(_track.params.session.type),
		driver = SteamService.username if SteamService.username else car.driver.full_name if car.driver else "",
		started = started,
		track_length_m = Track.pixels_to_meters(_track.surface.total_length),
		game_version = ProjectSettings.get_setting("application/config/version"),
		telemetry_version = DATA_VERSION
	}
	var timestamp := started.replace("T", "_").replace(":", "-")
	var path := RECORD_ROOT.path_join(("%s_%s_%s_%s" % [timestamp, session_data.track, session_data.session, session_data.driver]).validate_filename() + ".ttlog")
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("[Telemetry] could not write %s (error %d), recording stopped" % [path, FileAccess.get_open_error()])
		_recording = false
		return false
	_file.store_line(JSON.stringify(session_data))
	return true
	

func _close_file_if_exists() -> void:
	if _file == null:
		return
	_file.close()
	_file = null

func _sample(car: Car) -> Array:
	var pu := car.power_unit
	var pos := car.model_positioner.global_position
	# Telemetry data version 0.10, one value per name in the comments.
	# _num rounds each value to its resolution and turns NaN/inf into null
	return [
		# Time into the lap, the clock the lap and sector times are taken from
		_num(car.current_lap.time, 0.00001),  # time
		_num(Track.pixels_to_meters(car.lap_progress), 0.01),  # distance_m, into the lap
		roundi(_driver_input("accelerate", 1.0) * 100),  # throttle_raw
		roundi(_driver_input("brake", 1.0) * 100),  # brake_raw
		roundi(_driver_input("accelerate", Options.throttle_input_exponent) * 100) ,  # throttle_after_sensitivity
		roundi(_driver_input("brake", Options.brake_input_exponent) * 100),  # brake_after_sensitivity
		roundi(car.player_controller._driver_throttle * 100),  # throttle_after_damping
		roundi(car.player_controller._driver_brake * 100),  # brake_after_damping
		roundi(car.inputs.throttle * 100),  # throttle
		roundi(car.inputs.brake * 100),  # brake
		int(car.anti_lock_brakes.is_engaged),  # abs_active
		int(car.traction_control.is_engaged),  # tc_active
		roundi(Track.pps_to_kph(car.speed)),  # speed_kph
		_num(rad_to_deg(car.slip_angle), 0.01),  # slip_angle_deg
		roundi(car.wheel_spin * 100),  # wheel_spin
		roundi(car.traction * 100),  # traction
		roundi(car.control * 100),  # control
		_num(car.grip, 0.01),  # grip
		_num(car.relative_offset, 0.01),  # lateral_offset
		_num(pos.x, 0.00001),  # x
		_num(pos.z, 0.00001),  # z
		pu.current_gear + 1,  # gear
		roundi(pu.rpm),  # rpm
	]

# A float rounded to a multiple of step (step 1 gives an int, written without ".0");
# NaN and inf aren't valid JSON, so they become null
func _num(value: float, step: float) -> Variant:
	if not is_finite(value):
		return null
	return roundi(value) if step == 1.0 else snappedf(value, step)

# Same actions and sensitivity curve PlayerCar uses; a digital press counts as full travel
func _driver_input(action: String, exponent: float) -> float:
	var analog := pow(Input.get_action_strength(action + "_analog"), exponent)
	return analog if analog > 0.0 or not Input.is_action_pressed(action) else 1.0
