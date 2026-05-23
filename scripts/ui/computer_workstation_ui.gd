class_name ComputerWorkstationUI
extends Control

@onready var tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var email_list: ItemList = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailContent/EmailListColumn/EmailList
@onready var email_sender_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailContent/EmailDetailsColumn/SenderLabel
@onready var email_subject_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailContent/EmailDetailsColumn/SubjectLabel
@onready var email_body_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailContent/EmailDetailsColumn/BodyLabel
@onready var email_attachment_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailContent/EmailDetailsColumn/AttachmentLabel
@onready var download_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailButtons/DownloadButton
@onready var email_status_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/EmailTab/EmailStatusLabel
@onready var mounted_drives_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingContent/ProjectDetailsColumn/MountedDrivesLabel
@onready var project_list: ItemList = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingContent/ProjectListColumn/ProjectList
@onready var project_name_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingContent/ProjectDetailsColumn/ProjectNameLabel
@onready var project_description_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingContent/ProjectDetailsColumn/ProjectDescriptionLabel
@onready var project_requirements_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingContent/ProjectDetailsColumn/ProjectRequirementsLabel
@onready var storage_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingContent/ProjectDetailsColumn/StorageLabel
@onready var code_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingButtons/CodeButton
@onready var mount_drive_option: OptionButton = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingButtons/MountDriveOption
@onready var mount_drive_button: Button = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingButtons/MountDriveButton
@onready var coding_status_label: Label = $Panel/MarginContainer/VBoxContainer/TabContainer/CodingTab/CodingStatusLabel
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/Buttons/CloseButton

var station: ProgrammingComponent
var player: PlayerCharacter
var _selected_email_index := -1
var _selected_project_id := ""


func _ready() -> void:
	visible = false
	email_list.item_selected.connect(_on_email_selected)
	download_button.pressed.connect(_on_download_pressed)
	project_list.item_selected.connect(_on_project_selected)
	code_button.pressed.connect(_on_code_pressed)
	mount_drive_button.pressed.connect(_on_mount_drive_pressed)
	close_button.pressed.connect(close_ui)


func open_for_station(target_station: ProgrammingComponent, target_player: PlayerCharacter) -> void:
	if target_station == null:
		return

	station = target_station
	player = target_player
	_selected_email_index = -1
	_selected_project_id = ""
	visible = true

	if InventoryManager != null:
		InventoryManager.set_inventory_open(true)

	_refresh_all()


func close_ui() -> void:
	visible = false
	_selected_email_index = -1
	_selected_project_id = ""
	coding_status_label.text = ""
	email_status_label.text = ""
	if station != null and station.has_method("notify_ui_closed"):
		station.notify_ui_closed()
	station = null
	player = null
	if InventoryManager != null:
		InventoryManager.set_inventory_open(false)


func is_open() -> bool:
	return visible


func is_open_for_station(target_station: ProgrammingComponent) -> bool:
	return visible and station == target_station


func _refresh_all() -> void:
	_refresh_email_list()
	_refresh_email_details()
	_refresh_project_list()
	_refresh_project_details()
	_refresh_mount_drive_options()
	_refresh_storage_summary()
	_refresh_mounted_drives()


func _refresh_email_list() -> void:
	email_list.clear()
	if station == null:
		return

	var messages := station.get_email_messages()
	for i in range(messages.size()):
		var message_variant: Variant = messages[i]
		if not (message_variant is Dictionary):
			continue
		var message: Dictionary = message_variant as Dictionary
		var sender := str(message.get("sender", "Unknown"))
		var subject := str(message.get("subject", "Data package"))
		var downloaded := bool(message.get("downloaded", false))
		var suffix := " (downloaded)" if downloaded else ""
		email_list.add_item("%s · %s%s" % [sender, subject, suffix])

	if email_list.item_count > 0:
		email_list.select(0)
		_selected_email_index = 0
	else:
		_selected_email_index = -1


func _refresh_email_details() -> void:
	email_sender_label.text = "Sender: --"
	email_subject_label.text = "Subject: --"
	email_body_label.text = ""
	email_attachment_label.text = "Attachment: --"
	download_button.disabled = true

	if station == null or _selected_email_index < 0:
		return

	var messages := station.get_email_messages()
	if _selected_email_index >= messages.size():
		return

	var message_variant: Variant = messages[_selected_email_index]
	if not (message_variant is Dictionary):
		return

	var message: Dictionary = message_variant as Dictionary
	var attachment_variant: Variant = message.get("attachment", {})
	var attachment: Dictionary = attachment_variant as Dictionary if attachment_variant is Dictionary else {}
	var data_type := str(attachment.get("data_type", "unknown"))
	var amount :Variant= max(int(attachment.get("amount", 0)), 0)

	email_sender_label.text = "Sender: %s" % str(message.get("sender", "Unknown"))
	email_subject_label.text = "Subject: %s" % str(message.get("subject", "Data package"))
	email_body_label.text = str(message.get("body", ""))
	email_attachment_label.text = "Attachment: %s x%d" % [data_type.replace("_", " "), amount]
	download_button.disabled = bool(message.get("downloaded", false))


func _refresh_project_list() -> void:
	project_list.clear()
	if station == null:
		return

	for project_variant in station.get_coding_projects():
		if not (project_variant is Dictionary):
			continue
		var project: Dictionary = project_variant as Dictionary
		var project_id := str(project.get("id", ""))
		if project_id.is_empty():
			continue
		var project_name := str(project.get("display_name", project_id))
		project_list.add_item(project_name)
		project_list.set_item_metadata(project_list.item_count - 1, project_id)

	if project_list.item_count > 0:
		project_list.select(0)
		var selected_meta: Variant = project_list.get_item_metadata(0)
		_selected_project_id = str(selected_meta)
	else:
		_selected_project_id = ""


func _refresh_project_details() -> void:
	project_name_label.text = "Select a coding project"
	project_description_label.text = ""
	project_requirements_label.text = "Requirements: --"
	code_button.disabled = true

	if station == null or _selected_project_id.is_empty():
		return

	var project := station.get_project_by_id(_selected_project_id)
	if project.is_empty():
		return

	project_name_label.text = str(project.get("display_name", _selected_project_id))
	project_description_label.text = str(project.get("description", ""))
	project_requirements_label.text = station.format_project_requirements(project)

	var can_code_result := station.can_code_project(_selected_project_id)
	code_button.disabled = not bool(can_code_result.get("ok", false))


func _refresh_storage_summary() -> void:
	storage_label.text = "PC Data: --"
	if station == null:
		return

	var data_store := station.get_pc_data()
	var small_data := int(data_store.get("small_data", 0))
	var big_data := int(data_store.get("big_data", 0))
	var special_data := int(data_store.get("special_data", 0))
	storage_label.text = "PC Data · Small: %d · Big: %d · Special: %d" % [small_data, big_data, special_data]


func _refresh_mounted_drives() -> void:
	mounted_drives_label.text = "Mounted hard drives: none"
	if station == null:
		return

	var drives := station.get_mounted_hard_drives()
	if drives.is_empty():
		return

	var labels: Array[String] = []
	for drive_variant in drives:
		labels.append(str(drive_variant).replace("_", " "))
	mounted_drives_label.text = "Mounted hard drives: %s" % ", ".join(labels)


func _refresh_mount_drive_options() -> void:
	mount_drive_option.clear()
	mount_drive_button.disabled = true
	if station == null:
		return

	for item_id in station.get_mountable_drive_item_ids():
		mount_drive_option.add_item(str(item_id).replace("_", " "))
		mount_drive_option.set_item_metadata(mount_drive_option.item_count - 1, item_id)

	mount_drive_button.disabled = mount_drive_option.item_count == 0


func _on_email_selected(index: int) -> void:
	_selected_email_index = index
	_refresh_email_details()


func _on_download_pressed() -> void:
	if station == null or _selected_email_index < 0:
		return

	var result := station.download_email_attachment(_selected_email_index)
	email_status_label.text = str(result.get("message", ""))
	_refresh_email_list()
	if _selected_email_index >= 0 and _selected_email_index < email_list.item_count:
		email_list.select(_selected_email_index)
	_refresh_email_details()
	_refresh_storage_summary()
	_refresh_project_details()


func _on_project_selected(index: int) -> void:
	var project_id_variant: Variant = project_list.get_item_metadata(index)
	_selected_project_id = str(project_id_variant)
	_refresh_project_details()


func _on_code_pressed() -> void:
	if station == null or _selected_project_id.is_empty():
		return

	var result := station.code_project(_selected_project_id, player)
	coding_status_label.text = str(result.get("message", ""))
	_refresh_storage_summary()
	_refresh_project_details()


func _on_mount_drive_pressed() -> void:
	if station == null or mount_drive_option.item_count == 0:
		return

	var selected := mount_drive_option.selected
	if selected < 0:
		selected = 0
	var item_id_variant: Variant = mount_drive_option.get_item_metadata(selected)
	var item_id := str(item_id_variant)
	if item_id.is_empty():
		return

	var result := station.mount_hard_drive(item_id)
	coding_status_label.text = str(result.get("message", ""))
	_refresh_mount_drive_options()
	_refresh_mounted_drives()
	_refresh_storage_summary()
	_refresh_project_details()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
