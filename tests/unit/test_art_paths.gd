extends GutTest
## scenes/art_paths.gd -- content-id -> art resource resolution.


func test_shadow_material_returns_a_shader_material() -> void:
	var m := ArtPaths.shadow_material()
	assert_not_null(m)
	assert_true(m is ShaderMaterial)


func test_shadow_material_is_the_same_shared_instance() -> void:
	assert_same(ArtPaths.shadow_material(), ArtPaths.shadow_material())
