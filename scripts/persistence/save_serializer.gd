class_name SaveSerializer
extends RefCounted


static func parse_save_data(raw_text: String) -> Variant:
	return JSON.parse_string(raw_text)


static func serialize_save_data(value: Variant, indentation: String = "\t") -> String:
	return JSON.stringify(value, indentation)
