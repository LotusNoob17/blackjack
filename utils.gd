extends Node

func http_build_query(data: Dictionary) -> String:
	var query = []
	for key in data.keys():
		query.append("%s=%s" % [key.uri_encode(), str(data[key]).uri_encode()])
	return "&".join(query)
