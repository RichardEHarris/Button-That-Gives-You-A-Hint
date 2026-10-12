extends Control
@onready var the_hint_button: Button = %TheHintButton
@onready var output_label: Label = %Output

func _ready():
	get_window().min_size = Vector2(1050,500)
	get_window().title += " (%s)" % ProjectSettings.get_setting("application/config/version")

	the_hint_button.button_down.connect(grant_hint)

	#Archipelago.load_console(self, false)
	load_connection()
	#Archipelago.connected.connect(on_connect)
	#Archipelago.disconnected.connect(on_disconnect)
	#Archipelago.connectionrefused.connect(on_connect_reject)
	#Archipelago.printjson.connect(on_printjson)
	#on_disconnect()
	#settings_tab.load_settings()

var _prog_locs: Array[NetworkItem] = []
var _non_prog_locs: Array[NetworkItem] = []
func refresh_hint_count() -> void:
	if Archipelago.is_not_connected():
		return
	_prog_locs.clear()
	_non_prog_locs.clear()

	var locs := Archipelago.conn._scout_cache.keys()
	for hint in Archipelago.conn.hints:
		locs.erase(hint.item.loc_id)
	var q := 0
	while q < locs.size():
		if Archipelago.conn.slot_locations[locs[q]]:
			locs.pop_at(q)
		else: q += 1
	for loc in locs:
		var itm: NetworkItem = Archipelago.conn._scout_cache[loc]
		if itm.is_prog():
			_prog_locs.append(itm)
		else: _non_prog_locs.append(itm)

func grant_hint() -> void:
	var weights: Array[int] = [90,10,0]

	if _prog_locs.is_empty():
		weights[0] = 0
	if _non_prog_locs.is_empty():
		weights[1] = 0;
	if weights[0] == 0 and weights[1] == 0:
		output_label.text = "No Locations Available To Hint"
		#await PopupManager.popup_dlg("No hints left to earn, though!", "Correct!", false)
		return
	var max_weight: int = weights.reduce(func(acc, val):
		return acc + val, 0)
	var picked: int = randi_range(0, max_weight-1)
	var itm: NetworkItem
	if picked < weights[0]:
		itm = _prog_locs.pick_random()
	else:
		itm = _non_prog_locs.pick_random()
	Archipelago.conn.scout(itm.loc_id, 1, Callable())
	Archipelago.conn.on_hint_update.connect(display_hint.bind(itm.loc_id), CONNECT_ONE_SHOT | CONNECT_REFERENCE_COUNTED)
func display_hint(hints: Array[NetworkHint], loc: int) -> void:
	for hint in hints:
		if hint.item.loc_id == loc:
			var s: String = hint.as_plain_string()
			output_label.text = s
			#await PopupManager.popup_dlg(s, "Correct!", false)
			return
static func load_connection():
	var conn_info_file: FileAccess = FileAccess.open("user://ap/connection.dat", FileAccess.READ)
	if not conn_info_file: return
	var ip = conn_info_file.get_line()
	var port = conn_info_file.get_line()
	var slot = conn_info_file.get_line()
	Archipelago.creds.update(ip, port, slot, "")
	conn_info_file.close()
static func save_connection(creds: APCredentials):
	DirAccess.make_dir_recursive_absolute("user://ap/")
	var conn_info_file: FileAccess = FileAccess.open("user://ap/connection.dat", FileAccess.WRITE)
	if not conn_info_file: return
	conn_info_file.store_line(creds.ip)
	conn_info_file.store_line(creds.port)
	conn_info_file.store_line(creds.slot)
	conn_info_file.close()
