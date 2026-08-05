class_name CppGdextensionTemplate
extends RefCounted
## Overlays a Godot 4 GDExtension (C++) scaffold onto a playable GDScript starter.


static func overlay(files: Array, genre_id: String, description: String) -> Array:
	var out: Array = files.duplicate(true)
	var by_path: Dictionary = {}
	for f in out:
		if typeof(f) == TYPE_DICTIONARY:
			by_path[str(f.get("path", ""))] = f
	var family: String = family_for(genre_id)
	var brief: String = description.strip_edges().left(400)
	if brief.is_empty():
		brief = "Playable %s game" % genre_id
	_upsert(out, by_path, "src/register_types.h", _register_h())
	_upsert(out, by_path, "src/register_types.cpp", _register_cpp())
	_upsert(out, by_path, "src/game_app.h", _app_h())
	_upsert(out, by_path, "src/game_app.cpp", _app_cpp(genre_id, brief))
	_upsert(out, by_path, "src/game_player.h", _player_h(family))
	_upsert(out, by_path, "src/game_player.cpp", _player_cpp(family, genre_id))
	_upsert(out, by_path, "src/game_world.h", _world_h(family))
	_upsert(out, by_path, "src/game_world.cpp", _world_cpp(family, genre_id))
	_upsert(out, by_path, "src/game_enemy.h", _enemy_h(family))
	_upsert(out, by_path, "src/game_enemy.cpp", _enemy_cpp(family))
	_upsert(out, by_path, "bin/game.gdextension", _gdextension_file())
	_upsert(out, by_path, "bin/.gitkeep", "")
	_upsert(out, by_path, "SConstruct", _sconstruct())
	_upsert(out, by_path, "CMakeLists.txt", _cmake())
	_upsert(out, by_path, "build_cpp.ps1", _build_ps1())
	_upsert(out, by_path, "build_cpp.sh", _build_sh())
	_upsert(out, by_path, "godot-cpp/.gdignore", "")
	_upsert(out, by_path, ".gitignore", _project_gitignore(by_path))
	_upsert(out, by_path, "scripts/cpp_bridge.gd", _bridge_gd())
	_upsert(out, by_path, "scenes/main_cpp.tscn", _main_cpp_scene(family, genre_id))
	_upsert(out, by_path, "docs/CPP_BUILD.md", _build_doc(genre_id, family))
	_upsert(out, by_path, "README_CPP.md", _readme_cpp(genre_id))
	if by_path.has("project.godot"):
		by_path["project.godot"]["content"] = _patch_project_godot(str(by_path["project.godot"].get("content", "")))
	return out


static func ensure_project_autoload(pg: String) -> String:
	return _patch_project_godot(pg)


static func family_for(genre_id: String) -> String:
	match genre_id:
		"fps", "tps", "open_world", "voxel":
			return "3d"
		"simulation":
			return "sim"
		_:
			return "2d"


static func expected_paths() -> PackedStringArray:
	return PackedStringArray([
		"src/register_types.cpp",
		"src/game_player.cpp",
		"src/game_world.cpp",
		"src/game_app.cpp",
		"bin/game.gdextension",
		"SConstruct",
		"CMakeLists.txt",
		"build_cpp.ps1",
		"scripts/cpp_bridge.gd",
		"docs/CPP_BUILD.md",
	])


static func _upsert(out: Array, by_path: Dictionary, path: String, content: String) -> void:
	if by_path.has(path):
		by_path[path]["content"] = content
	else:
		var f: Dictionary = {"path": path, "content": content}
		out.append(f)
		by_path[path] = f


static func _patch_project_godot(pg: String) -> String:
	var text: String = pg
	if not text.contains("CppBridge="):
		if text.contains("[autoload]"):
			text = text.replace("[autoload]", "[autoload]\nCppBridge=\"*res://scripts/cpp_bridge.gd\"")
		else:
			text += "\n[autoload]\nCppBridge=\"*res://scripts/cpp_bridge.gd\"\n"
	return text


static func _project_gitignore(by_path: Dictionary) -> String:
	var prev: String = ""
	if by_path.has(".gitignore"):
		prev = str(by_path[".gitignore"].get("content", ""))
	var extra: String = """
# GDExtension build
godot-cpp/
.sconsign.dblite
.sconf_temp/
__pycache__/
bin/*.dll
bin/*.so
bin/*.dylib
bin/*.lib
bin/*.exp
bin/*.pdb
bin/*.ilk
*.obj
*.o
"""
	if prev.contains("godot-cpp/"):
		return prev
	return (prev.strip_edges() + "\n" + extra).strip_edges() + "\n"


static func _register_h() -> String:
	return """#ifndef GAME_REGISTER_TYPES_H
#define GAME_REGISTER_TYPES_H

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void initialize_game_module(ModuleInitializationLevel p_level);
void uninitialize_game_module(ModuleInitializationLevel p_level);

#endif
"""


static func _register_cpp() -> String:
	return """#include "register_types.h"

#include "game_app.h"
#include "game_enemy.h"
#include "game_player.h"
#include "game_world.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_game_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	ClassDB::register_class<GameApp>();
	ClassDB::register_class<GamePlayer>();
	ClassDB::register_class<GameWorld>();
	ClassDB::register_class<GameEnemy>();
}

void uninitialize_game_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
}

extern "C" {
GDExtensionBool GDE_EXPORT game_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_game_module);
	init_obj.register_terminator(uninitialize_game_module);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
"""


static func _app_h() -> String:
	return """#ifndef GAME_APP_H
#define GAME_APP_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class GameApp : public Node {
	GDCLASS(GameApp, Node)

private:
	String genre_id;
	String brief;

protected:
	static void _bind_methods();

public:
	GameApp();
	~GameApp();

	void _ready() override;
	void set_genre_id(const String &p_genre);
	String get_genre_id() const;
	void set_brief(const String &p_brief);
	String get_brief() const;
	String get_status() const;
	bool is_native() const;
};

}

#endif
"""


static func _app_cpp(genre_id: String, brief: String) -> String:
	var g: String = genre_id.c_escape()
	var b: String = brief.c_escape()
	return """#include "game_app.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameApp::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_genre_id", "genre_id"), &GameApp::set_genre_id);
	ClassDB::bind_method(D_METHOD("get_genre_id"), &GameApp::get_genre_id);
	ClassDB::bind_method(D_METHOD("set_brief", "brief"), &GameApp::set_brief);
	ClassDB::bind_method(D_METHOD("get_brief"), &GameApp::get_brief);
	ClassDB::bind_method(D_METHOD("get_status"), &GameApp::get_status);
	ClassDB::bind_method(D_METHOD("is_native"), &GameApp::is_native);
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "genre_id"), "set_genre_id", "get_genre_id");
	ADD_PROPERTY(PropertyInfo(Variant::STRING, "brief"), "set_brief", "get_brief");
}

GameApp::GameApp() {
	genre_id = "{G}";
	brief = "{B}";
}

GameApp::~GameApp() {}

void GameApp::_ready() {
	UtilityFunctions::print("[GameApp] Native C++ GDExtension ready — genre=", genre_id);
}

void GameApp::set_genre_id(const String &p_genre) { genre_id = p_genre; }
String GameApp::get_genre_id() const { return genre_id; }
void GameApp::set_brief(const String &p_brief) { brief = p_brief; }
String GameApp::get_brief() const { return brief; }

String GameApp::get_status() const {
	return String("C++ GDExtension active (") + genre_id + ")";
}

bool GameApp::is_native() const { return true; }
""".replace("{G}", g).replace("{B}", b)


static func _player_h(family: String) -> String:
	if family == "3d":
		return """#ifndef GAME_PLAYER_H
#define GAME_PLAYER_H

#include <godot_cpp/classes/camera3d.hpp>
#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/input_event.hpp>
#include <godot_cpp/classes/ray_cast3d.hpp>

namespace godot {

class GamePlayer : public CharacterBody3D {
	GDCLASS(GamePlayer, CharacterBody3D)

private:
	float speed = 7.0f;
	float pitch = 0.0f;
	float bob_t = 0.0f;
	Camera3D *cam = nullptr;
	RayCast3D *ray = nullptr;

protected:
	static void _bind_methods();

public:
	GamePlayer();
	~GamePlayer();

	void _ready() override;
	void _unhandled_input(const Ref<InputEvent> &event) override;
	void _physics_process(double delta) override;
	void fire();
	void set_speed(float p_speed);
	float get_speed() const;
};

}

#endif
"""
	if family == "sim":
		return """#ifndef GAME_PLAYER_H
#define GAME_PLAYER_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class GamePlayer : public Node {
	GDCLASS(GamePlayer, Node)

protected:
	static void _bind_methods();

public:
	GamePlayer();
	~GamePlayer();
	void _ready() override;
};

}

#endif
"""
	return """#ifndef GAME_PLAYER_H
#define GAME_PLAYER_H

#include <godot_cpp/classes/character_body2d.hpp>
#include <godot_cpp/classes/input_event.hpp>

namespace godot {

class GamePlayer : public CharacterBody2D {
	GDCLASS(GamePlayer, CharacterBody2D)

private:
	float speed = 260.0f;
	float jump_velocity = -420.0f;
	float gravity = 1100.0f;
	float facing = 1.0f;
	bool use_jump = true;

protected:
	static void _bind_methods();

public:
	GamePlayer();
	~GamePlayer();

	void _ready() override;
	void _physics_process(double delta) override;
	void set_speed(float p_speed);
	float get_speed() const;
	void set_use_jump(bool p_jump);
	bool get_use_jump() const;
};

}

#endif
"""


static func _player_cpp(family: String, genre_id: String) -> String:
	if family == "3d":
		return """#include "game_player.h"

#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/input_event_mouse_button.hpp>
#include <godot_cpp/classes/input_event_mouse_motion.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/capsule_mesh.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GamePlayer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("fire"), &GamePlayer::fire);
	ClassDB::bind_method(D_METHOD("set_speed", "speed"), &GamePlayer::set_speed);
	ClassDB::bind_method(D_METHOD("get_speed"), &GamePlayer::get_speed);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed"), "set_speed", "get_speed");
}

GamePlayer::GamePlayer() {}
GamePlayer::~GamePlayer() {}

void GamePlayer::_ready() {
	add_to_group("player");
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	cam = Object::cast_to<Camera3D>(get_node_or_null(NodePath("Camera3D")));
	if (cam == nullptr) {
		cam = memnew(Camera3D);
		cam->set_name("Camera3D");
		cam->set_position(Vector3(0.0f, 0.55f, 0.0f));
		cam->set_current(true);
		add_child(cam);
	}
	ray = Object::cast_to<RayCast3D>(get_node_or_null(NodePath("Camera3D/RayCast3D")));
	if (ray == nullptr && cam != nullptr) {
		ray = memnew(RayCast3D);
		ray->set_name("RayCast3D");
		ray->set_target_position(Vector3(0.0f, 0.0f, -48.0f));
		cam->add_child(ray);
	}
	if (get_node_or_null(NodePath("CollisionShape3D")) == nullptr) {
		CollisionShape3D *cs = memnew(CollisionShape3D);
		Ref<CapsuleShape3D> shape;
		shape.instantiate();
		shape->set_radius(0.35f);
		shape->set_height(1.6f);
		cs->set_shape(shape);
		add_child(cs);
	}
	Input::get_singleton()->set_mouse_mode(Input::MOUSE_MODE_CAPTURED);
	UtilityFunctions::print("[GamePlayer] C++ 3D controller ready");
}

void GamePlayer::_unhandled_input(const Ref<InputEvent> &event) {
	Ref<InputEventMouseMotion> motion = event;
	if (motion.is_valid() && Input::get_singleton()->get_mouse_mode() == Input::MOUSE_MODE_CAPTURED) {
		rotate_y(-motion->get_relative().x * 0.0025f);
		pitch = Math::clamp(pitch - motion->get_relative().y * 0.0025f, Math::deg_to_rad(-85.0f), Math::deg_to_rad(85.0f));
		if (cam) {
			cam->set_rotation(Vector3(pitch, 0.0f, 0.0f));
		}
	}
	if (event->is_action_pressed("ui_cancel")) {
		Input *in = Input::get_singleton();
		in->set_mouse_mode(in->get_mouse_mode() == Input::MOUSE_MODE_CAPTURED ? Input::MOUSE_MODE_VISIBLE : Input::MOUSE_MODE_CAPTURED);
	}
	Ref<InputEventMouseButton> button = event;
	if (button.is_valid() && button->is_pressed() && button->get_button_index() == MOUSE_BUTTON_LEFT) {
		fire();
	}
}

void GamePlayer::_physics_process(double delta) {
	Input *in = Input::get_singleton();
	Vector2 i = in->get_vector("ui_left", "ui_right", "ui_up", "ui_down");
	Vector3 dir = (get_transform().basis.xform(Vector3(i.x, 0.0f, i.y))).normalized();
	Vector3 vel = get_velocity();
	vel.x = dir.x * speed;
	vel.z = dir.z * speed;
	if (!is_on_floor()) {
		vel.y -= 20.0f * float(delta);
	} else if (in->is_action_just_pressed("ui_accept")) {
		vel.y = 7.0f;
	} else {
		vel.y = 0.0f;
	}
	if (cam) {
		if (dir.length() > 0.1f && is_on_floor()) {
			bob_t += float(delta) * 10.0f;
			cam->set_position(Vector3(Math::cos(bob_t * 0.5f) * 0.02f, 0.55f + Math::sin(bob_t) * 0.045f, 0.0f));
		} else {
			cam->set_position(cam->get_position().lerp(Vector3(0.0f, 0.55f, 0.0f), float(delta) * 8.0f));
		}
	}
	set_velocity(vel);
	move_and_slide();
}

void GamePlayer::fire() {
	if (ray == nullptr) {
		return;
	}
	ray->force_raycast_update();
	if (!ray->is_colliding()) {
		return;
	}
	Object *col = ray->get_collider();
	if (col && col->has_method("take_damage")) {
		col->call("take_damage", 34);
	}
}

void GamePlayer::set_speed(float p_speed) { speed = p_speed; }
float GamePlayer::get_speed() const { return speed; }
"""
	if family == "sim":
		return """#include "game_player.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GamePlayer::_bind_methods() {}

GamePlayer::GamePlayer() {}
GamePlayer::~GamePlayer() {}

void GamePlayer::_ready() {
	UtilityFunctions::print("[GamePlayer] C++ simulation helper ready");
}
"""
	var jump_flag: String = "false" if genre_id in ["space_shooter", "racing", "arena"] else "true"
	return """#include "game_player.h"

#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/input.hpp>
#include <godot_cpp/classes/rectangle_shape2d.hpp>
#include <godot_cpp/classes/polygon2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GamePlayer::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_speed", "speed"), &GamePlayer::set_speed);
	ClassDB::bind_method(D_METHOD("get_speed"), &GamePlayer::get_speed);
	ClassDB::bind_method(D_METHOD("set_use_jump", "use_jump"), &GamePlayer::set_use_jump);
	ClassDB::bind_method(D_METHOD("get_use_jump"), &GamePlayer::get_use_jump);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed"), "set_speed", "get_speed");
	ADD_PROPERTY(PropertyInfo(Variant::BOOL, "use_jump"), "set_use_jump", "get_use_jump");
}

GamePlayer::GamePlayer() {
	use_jump = {JUMP};
}

GamePlayer::~GamePlayer() {}

void GamePlayer::_ready() {
	add_to_group("player");
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	if (get_node_or_null(NodePath("CollisionShape2D")) == nullptr) {
		CollisionShape2D *cs = memnew(CollisionShape2D);
		Ref<RectangleShape2D> shape;
		shape.instantiate();
		shape->set_size(Vector2(24, 32));
		cs->set_shape(shape);
		add_child(cs);
	}
	if (get_node_or_null(NodePath("BodyPoly")) == nullptr) {
		Polygon2D *poly = memnew(Polygon2D);
		poly->set_name("BodyPoly");
		poly->set_color(Color(0.95f, 0.55f, 0.25f));
		PackedVector2Array pts;
		pts.push_back(Vector2(-12, -16));
		pts.push_back(Vector2(12, -16));
		pts.push_back(Vector2(12, 16));
		pts.push_back(Vector2(-12, 16));
		poly->set_polygon(pts);
		add_child(poly);
	}
	UtilityFunctions::print("[GamePlayer] C++ 2D controller ready");
}

void GamePlayer::_physics_process(double delta) {
	Input *in = Input::get_singleton();
	Vector2 i = in->get_vector("ui_left", "ui_right", "ui_up", "ui_down");
	Vector2 vel = get_velocity();
	if (use_jump) {
		vel.x = i.x * speed;
		if (!is_on_floor()) {
			vel.y += gravity * float(delta);
		} else if (in->is_action_just_pressed("ui_accept") || in->is_action_just_pressed("ui_up")) {
			vel.y = jump_velocity;
		}
		if (i.x != 0.0f) {
			facing = i.x > 0.0f ? 1.0f : -1.0f;
		}
	} else {
		vel = i * speed;
	}
	set_velocity(vel);
	move_and_slide();
}

void GamePlayer::set_speed(float p_speed) { speed = p_speed; }
float GamePlayer::get_speed() const { return speed; }
void GamePlayer::set_use_jump(bool p_jump) { use_jump = p_jump; }
bool GamePlayer::get_use_jump() const { return use_jump; }
""".replace("{JUMP}", jump_flag)


static func _world_h(family: String) -> String:
	if family == "3d":
		return """#ifndef GAME_WORLD_H
#define GAME_WORLD_H

#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/label.hpp>

namespace godot {

class GameWorld : public Node3D {
	GDCLASS(GameWorld, Node3D)

private:
	int kills = 0;
	Label *hud = nullptr;

protected:
	static void _bind_methods();

public:
	GameWorld();
	~GameWorld();
	void _ready() override;
	void add_kill();
	int get_kills() const;
};

}

#endif
"""
	if family == "sim":
		return """#ifndef GAME_WORLD_H
#define GAME_WORLD_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class GameWorld : public Node {
	GDCLASS(GameWorld, Node)

private:
	int ore = 0;
	int energy = 0;
	double tick = 0.0;

protected:
	static void _bind_methods();

public:
	GameWorld();
	~GameWorld();
	void _ready() override;
	void _process(double delta) override;
	int get_ore() const;
	int get_energy() const;
};

}

#endif
"""
	return """#ifndef GAME_WORLD_H
#define GAME_WORLD_H

#include <godot_cpp/classes/node2d.hpp>
#include <godot_cpp/classes/label.hpp>

namespace godot {

class GameWorld : public Node2D {
	GDCLASS(GameWorld, Node2D)

private:
	int score = 0;
	double spawn_t = 0.0;
	Label *hud = nullptr;

protected:
	static void _bind_methods();

public:
	GameWorld();
	~GameWorld();
	void _ready() override;
	void _process(double delta) override;
	void add_score(int amount);
	int get_score() const;
};

}

#endif
"""


static func _world_cpp(family: String, genre_id: String) -> String:
	if family == "3d":
		return """#include "game_world.h"
#include "game_enemy.h"

#include <godot_cpp/classes/box_mesh.hpp>
#include <godot_cpp/classes/box_shape3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/directional_light3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>
#include <godot_cpp/classes/static_body3d.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/texture2d.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("add_kill"), &GameWorld::add_kill);
	ClassDB::bind_method(D_METHOD("get_kills"), &GameWorld::get_kills);
}

GameWorld::GameWorld() {}
GameWorld::~GameWorld() {}

static void add_box(Node3D *parent, Vector3 pos, Vector3 size, Color color, Ref<Texture2D> tex) {
	StaticBody3D *body = memnew(StaticBody3D);
	body->set_position(pos);
	MeshInstance3D *mi = memnew(MeshInstance3D);
	Ref<BoxMesh> mesh;
	mesh.instantiate();
	mesh->set_size(size);
	mi->set_mesh(mesh);
	Ref<StandardMaterial3D> mat;
	mat.instantiate();
	mat->set_albedo_color(color);
	if (tex.is_valid()) {
		mat->set_albedo_texture(tex);
		mat->set_uv1_scale(Vector3(2, 2, 2));
	}
	mi->set_material_override(mat);
	body->add_child(mi);
	CollisionShape3D *cs = memnew(CollisionShape3D);
	Ref<BoxShape3D> shape;
	shape.instantiate();
	shape->set_size(size);
	cs->set_shape(shape);
	body->add_child(cs);
	parent->add_child(body);
}

void GameWorld::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	hud = Object::cast_to<Label>(get_node_or_null(NodePath("UI/HUD")));
	Ref<Texture2D> wall;
	if (ResourceLoader::get_singleton()->exists("res://assets/wall.png")) {
		wall = ResourceLoader::get_singleton()->load("res://assets/wall.png");
	}
	add_box(this, Vector3(0, -0.5f, 0), Vector3(40, 1, 40), Color(0.12f, 0.10f, 0.09f), wall);
	add_box(this, Vector3(0, 1.5f, -14), Vector3(28, 3, 1), Color(0.55f, 0.28f, 0.2f), wall);
	add_box(this, Vector3(0, 1.5f, 14), Vector3(28, 3, 1), Color(0.55f, 0.28f, 0.2f), wall);
	add_box(this, Vector3(-14, 1.5f, 0), Vector3(1, 3, 28), Color(0.55f, 0.28f, 0.2f), wall);
	add_box(this, Vector3(14, 1.5f, 0), Vector3(1, 3, 28), Color(0.55f, 0.28f, 0.2f), wall);
	if (get_node_or_null(NodePath("DirectionalLight3D")) == nullptr) {
		DirectionalLight3D *light = memnew(DirectionalLight3D);
		light->set_name("DirectionalLight3D");
		light->set_shadow(true);
		add_child(light);
	}
	PackedVector3Array spots;
	spots.push_back(Vector3(6, 1, -6));
	spots.push_back(Vector3(-6, 1, 6));
	spots.push_back(Vector3(8, 1, 2));
	for (int i = 0; i < spots.size(); i++) {
		GameEnemy *e = memnew(GameEnemy);
		e->set_position(spots[i]);
		add_child(e);
	}
	if (hud) {
		hud->set_text("C++ WORLD | WASD · Mouse · LMB · Esc");
	}
	UtilityFunctions::print("[GameWorld] C++ 3D world ready");
}

void GameWorld::add_kill() {
	kills += 1;
	if (hud) {
		hud->set_text(String("C++ WORLD | Kills ") + String::num_int64(kills) + " | WASD · Mouse · LMB");
	}
}

int GameWorld::get_kills() const { return kills; }
"""
	if family == "sim":
		return """#include "game_world.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_ore"), &GameWorld::get_ore);
	ClassDB::bind_method(D_METHOD("get_energy"), &GameWorld::get_energy);
}

GameWorld::GameWorld() {}
GameWorld::~GameWorld() {}

void GameWorld::_ready() {
	UtilityFunctions::print("[GameWorld] C++ simulation loop ready");
}

void GameWorld::_process(double delta) {
	tick += delta;
	if (tick >= 1.0) {
		tick = 0.0;
		ore += 2;
		energy += 1;
	}
}

int GameWorld::get_ore() const { return ore; }
int GameWorld::get_energy() const { return energy; }
"""
	return """#include "game_world.h"
#include "game_enemy.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GameWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("add_score", "amount"), &GameWorld::add_score);
	ClassDB::bind_method(D_METHOD("get_score"), &GameWorld::get_score);
}

GameWorld::GameWorld() {}
GameWorld::~GameWorld() {}

void GameWorld::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	hud = Object::cast_to<Label>(get_node_or_null(NodePath("UI/HUD")));
	if (hud) {
		hud->set_text(String("C++ WORLD | genre {G} | WASD"));
	}
	UtilityFunctions::print("[GameWorld] C++ 2D world ready");
}

void GameWorld::_process(double delta) {
	spawn_t -= delta;
	if (spawn_t > 0.0) {
		return;
	}
	spawn_t = 1.4;
	GameEnemy *e = memnew(GameEnemy);
	e->set_position(Vector2(float(UtilityFunctions::randf_range(80.0, 1200.0)), float(UtilityFunctions::randf_range(80.0, 640.0))));
	add_child(e);
}

void GameWorld::add_score(int amount) {
	score += amount;
	if (hud) {
		hud->set_text(String("C++ WORLD | Score ") + String::num_int64(score));
	}
}

int GameWorld::get_score() const { return score; }
""".replace("{G}", genre_id)


static func _enemy_h(family: String) -> String:
	if family == "3d":
		return """#ifndef GAME_ENEMY_H
#define GAME_ENEMY_H

#include <godot_cpp/classes/character_body3d.hpp>
#include <godot_cpp/classes/mesh_instance3d.hpp>

namespace godot {

class GameEnemy : public CharacterBody3D {
	GDCLASS(GameEnemy, CharacterBody3D)

private:
	int hp = 100;
	MeshInstance3D *mesh = nullptr;

protected:
	static void _bind_methods();

public:
	GameEnemy();
	~GameEnemy();
	void _ready() override;
	void _physics_process(double delta) override;
	void take_damage(int amount);
	int get_hp() const;
};

}

#endif
"""
	if family == "sim":
		return """#ifndef GAME_ENEMY_H
#define GAME_ENEMY_H

#include <godot_cpp/classes/node.hpp>

namespace godot {

class GameEnemy : public Node {
	GDCLASS(GameEnemy, Node)

protected:
	static void _bind_methods();

public:
	GameEnemy();
	~GameEnemy();
};

}

#endif
"""
	return """#ifndef GAME_ENEMY_H
#define GAME_ENEMY_H

#include <godot_cpp/classes/character_body2d.hpp>

namespace godot {

class GameEnemy : public CharacterBody2D {
	GDCLASS(GameEnemy, CharacterBody2D)

private:
	int hp = 3;

protected:
	static void _bind_methods();

public:
	GameEnemy();
	~GameEnemy();
	void _ready() override;
	void _physics_process(double delta) override;
	void take_damage(int amount);
	int get_hp() const;
};

}

#endif
"""


static func _enemy_cpp(family: String) -> String:
	if family == "3d":
		return """#include "game_enemy.h"

#include <godot_cpp/classes/capsule_mesh.hpp>
#include <godot_cpp/classes/capsule_shape3d.hpp>
#include <godot_cpp/classes/collision_shape3d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/classes/standard_material3d.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GameEnemy::_bind_methods() {
	ClassDB::bind_method(D_METHOD("take_damage", "amount"), &GameEnemy::take_damage);
	ClassDB::bind_method(D_METHOD("get_hp"), &GameEnemy::get_hp);
}

GameEnemy::GameEnemy() {}
GameEnemy::~GameEnemy() {}

void GameEnemy::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	CollisionShape3D *cs = memnew(CollisionShape3D);
	Ref<CapsuleShape3D> shape;
	shape.instantiate();
	shape->set_radius(0.4f);
	shape->set_height(1.6f);
	cs->set_shape(shape);
	add_child(cs);
	mesh = memnew(MeshInstance3D);
	Ref<CapsuleMesh> cap;
	cap.instantiate();
	cap->set_radius(0.4f);
	cap->set_height(1.6f);
	mesh->set_mesh(cap);
	Ref<StandardMaterial3D> mat;
	mat.instantiate();
	mat->set_albedo_color(Color(0.55f, 0.12f, 0.1f));
	mesh->set_material_override(mat);
	add_child(mesh);
}

void GameEnemy::_physics_process(double delta) {
	(void)delta;
	SceneTree *tree = get_tree();
	if (tree == nullptr) {
		return;
	}
	TypedArray<Node> players = tree->get_nodes_in_group("player");
	if (players.is_empty()) {
		return;
	}
	Node3D *p = Object::cast_to<Node3D>(players[0]);
	if (p == nullptr) {
		return;
	}
	Vector3 to = p->get_global_position() - get_global_position();
	to.y = 0.0f;
	if (to.length() > 0.5f) {
		set_velocity(to.normalized() * 2.8f);
		move_and_slide();
	}
}

void GameEnemy::take_damage(int amount) {
	hp -= amount;
	if (hp > 0) {
		return;
	}
	Node *parent = get_parent();
	if (parent && parent->has_method("add_kill")) {
		parent->call("add_kill");
	}
	queue_free();
}

int GameEnemy::get_hp() const { return hp; }
"""
	if family == "sim":
		return """#include "game_enemy.h"

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GameEnemy::_bind_methods() {}

GameEnemy::GameEnemy() {}
GameEnemy::~GameEnemy() {}
"""
	return """#include "game_enemy.h"

#include <godot_cpp/classes/collision_shape2d.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/polygon2d.hpp>
#include <godot_cpp/classes/rectangle_shape2d.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

void GameEnemy::_bind_methods() {
	ClassDB::bind_method(D_METHOD("take_damage", "amount"), &GameEnemy::take_damage);
	ClassDB::bind_method(D_METHOD("get_hp"), &GameEnemy::get_hp);
}

GameEnemy::GameEnemy() {}
GameEnemy::~GameEnemy() {}

void GameEnemy::_ready() {
	if (Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	CollisionShape2D *cs = memnew(CollisionShape2D);
	Ref<RectangleShape2D> shape;
	shape.instantiate();
	shape->set_size(Vector2(28, 28));
	cs->set_shape(shape);
	add_child(cs);
	Polygon2D *poly = memnew(Polygon2D);
	poly->set_color(Color(0.9f, 0.25f, 0.3f));
	PackedVector2Array pts;
	pts.push_back(Vector2(-14, -14));
	pts.push_back(Vector2(14, -14));
	pts.push_back(Vector2(14, 14));
	pts.push_back(Vector2(-14, 14));
	poly->set_polygon(pts);
	add_child(poly);
}

void GameEnemy::_physics_process(double delta) {
	(void)delta;
	SceneTree *tree = get_tree();
	if (tree == nullptr) {
		return;
	}
	TypedArray<Node> players = tree->get_nodes_in_group("player");
	if (players.is_empty()) {
		return;
	}
	Node2D *p = Object::cast_to<Node2D>(players[0]);
	if (p == nullptr) {
		return;
	}
	Vector2 to = p->get_global_position() - get_global_position();
	if (to.length() > 8.0f) {
		set_velocity(to.normalized() * 90.0f);
		move_and_slide();
	}
}

void GameEnemy::take_damage(int amount) {
	hp -= amount;
	if (hp <= 0) {
		Node *parent = get_parent();
		if (parent && parent->has_method("add_score")) {
			parent->call("add_score", 1);
		}
		queue_free();
	}
}

int GameEnemy::get_hp() const { return hp; }
"""


static func _gdextension_file() -> String:
	return """[configuration]
entry_symbol = "game_library_init"
compatibility_minimum = "4.2"
reloadable = true

[libraries]
macos.debug = "res://bin/libgame.macos.template_debug.framework"
macos.release = "res://bin/libgame.macos.template_release.framework"
windows.debug.x86_64 = "res://bin/libgame.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://bin/libgame.windows.template_release.x86_64.dll"
linux.debug.x86_64 = "res://bin/libgame.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://bin/libgame.linux.template_release.x86_64.so"
android.debug.arm64 = "res://bin/libgame.android.template_debug.arm64.so"
android.release.arm64 = "res://bin/libgame.android.template_release.arm64.so"
"""


static func _sconstruct() -> String:
	return '''#!/usr/bin/env python
import os

env = SConscript("godot-cpp/SConstruct")
env.Append(CPPPATH=["src/"])
sources = Glob("src/*.cpp")

if env["platform"] == "macos":
    library = env.SharedLibrary(
        "bin/libgame.{}.{}.framework/libgame.{}.{}".format(
            env["platform"], env["target"], env["platform"], env["target"]
        ),
        source=sources,
    )
else:
    library = env.SharedLibrary(
        "bin/libgame{}{}".format(env["suffix"], env["SHLIBSUFFIX"]),
        source=sources,
    )

Default(library)
'''


static func _cmake() -> String:
	return """cmake_minimum_required(VERSION 3.16)
project(game_gdextension LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
	godot-cpp
	GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
	GIT_TAG godot-4.4-stable
)
FetchContent_MakeAvailable(godot-cpp)

add_library(game SHARED
	src/register_types.cpp
	src/game_app.cpp
	src/game_player.cpp
	src/game_world.cpp
	src/game_enemy.cpp
)
target_include_directories(game PRIVATE src)
if (TARGET godot::cpp)
	target_link_libraries(game PRIVATE godot::cpp)
elseif (TARGET godot-cpp)
	target_link_libraries(game PRIVATE godot-cpp)
endif()

set_target_properties(game PROPERTIES
	OUTPUT_NAME "libgame"
	RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
	LIBRARY_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
)
"""


static func _build_ps1() -> String:
	return """param(
	[string]$GodotCppTag = "godot-4.4-stable"
)
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Find-Python {
	foreach ($c in @("python", "py", "python3")) {
		$cmd = Get-Command $c -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	throw "Python 3 not found. Install Python and ensure it is on PATH."
}

$Python = Find-Python
Write-Host "Using Python: $Python"

& $Python -m pip install --user scons | Out-Host

if (-not (Test-Path (Join-Path $Root "godot-cpp/.git"))) {
	if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
		throw "Git not found. Install Git to clone godot-cpp, or copy godot-cpp into this folder."
	}
	Write-Host "Cloning godot-cpp ($GodotCppTag)..."
	git clone --depth 1 --branch $GodotCppTag https://github.com/godotengine/godot-cpp.git
	New-Item -ItemType File -Path (Join-Path $Root "godot-cpp/.gdignore") -Force | Out-Null
}

$vcvars = ""
$vswhere = "${env:ProgramFiles(x86)}\\Microsoft Visual Studio\\Installer\\vswhere.exe"
if (Test-Path $vswhere) {
	$vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
	if ($vs) {
		$vcvars = Join-Path $vs "VC\\Auxiliary\\Build\\vcvars64.bat"
	}
}

Write-Host "Building GDExtension (template_debug)..."
if ($vcvars -and (Test-Path $vcvars)) {
	cmd.exe /c "`"$vcvars`" && `"$Python`" -m SCons target=template_debug debug_symbols=no -j4"
} else {
	& $Python -m SCons target=template_debug debug_symbols=no -j4
}

Write-Host "Done. Restart the game / Godot editor to load bin/*.dll"
Write-Host "Optional: set project.godot run/main_scene to res://scenes/main_cpp.tscn to run native C++ nodes."
"""


static func _build_sh() -> String:
	return """#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
TAG="${1:-godot-4.4-stable}"

if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
else echo "Python 3 required"; exit 1; fi

"$PY" -m pip install --user scons
if [ ! -d godot-cpp/.git ]; then
	git clone --depth 1 --branch "$TAG" https://github.com/godotengine/godot-cpp.git
	: > godot-cpp/.gdignore
fi
"$PY" -m SCons target=template_debug debug_symbols=no -j4
echo "Done. Restart Godot to load bin/*.so (or macOS framework)."
echo "Optional: point main_scene at res://scenes/main_cpp.tscn"
"""


static func _bridge_gd() -> String:
	return """extends Node
## Loads native GameApp when the GDExtension is built; otherwise keeps GDScript gameplay.

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	var hud := Label.new()
	hud.name = "CppStatusHud"
	hud.position = Vector2(10, 690)
	hud.add_theme_font_size_override("font_size", 13)
	layer.add_child(hud)
	add_child(layer)
	if ClassDB.class_exists("GameApp"):
		var app: Node = ClassDB.instantiate("GameApp") as Node
		if app:
			app.name = "GameApp"
			add_child(app)
		hud.text = "C++ GDExtension ON — native classes loaded (GamePlayer / GameWorld / GameApp)"
		hud.add_theme_color_override("font_color", Color(0.24, 0.86, 0.59))
	else:
		hud.text = "C++ GDExtension not built — playing GDScript fallback. See docs/CPP_BUILD.md"
		hud.add_theme_color_override("font_color", Color(0.96, 0.64, 0.28))
"""


static func _main_cpp_scene(family: String, genre_id: String) -> String:
	if family == "3d":
		return """[gd_scene format=3]
[sub_resource type="CapsuleShape3D" id="cap"]
radius = 0.35
height = 1.6
[node name="World" type="GameWorld"]
[node name="Player" type="GamePlayer" parent="." groups=["player"]]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, 8)
[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
shape = SubResource("cap")
[node name="Camera3D" type="Camera3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.55, 0)
current = true
fov = 80.0
[node name="RayCast3D" type="RayCast3D" parent="Player/Camera3D"]
target_position = Vector3(0, 0, -45)
[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.8, -0.4, 0.4, 0, 0.7, 0.7, -0.5, -0.55, 0.65, 0, 10, 0)
shadow_enabled = true
[node name="UI" type="CanvasLayer" parent="."]
[node name="HUD" type="Label" parent="UI"]
offset_right = 1100.0
offset_bottom = 40.0
theme_override_font_sizes/font_size = 18
text = "C++ FPS | WASD · Mouse · LMB · Esc"
"""
	if family == "sim":
		return """[gd_scene format=3]
[node name="Sim" type="GameWorld"]
[node name="Helper" type="GamePlayer" parent="."]
[node name="UI" type="CanvasLayer" parent="."]
[node name="HUD" type="Label" parent="UI"]
offset_right = 900.0
offset_bottom = 40.0
text = "C++ SIM"
"""
	return """[gd_scene format=3]
[node name="World" type="GameWorld"]
[node name="Player" type="GamePlayer" parent="." groups=["player"]]
position = Vector2(640, 360)
[node name="UI" type="CanvasLayer" parent="."]
[node name="HUD" type="Label" parent="UI"]
offset_right = 900.0
offset_bottom = 40.0
text = "C++ GAME | WASD"
""".replace("C++ GAME", "C++ %s" % genre_id.to_upper())


static func _build_doc(genre_id: String, family: String) -> String:
	return """# Build the C++ GDExtension

This project is a **Godot 4 + C++ (GDExtension)** game. `src/` is the intended implementation.
**Run Game works immediately** via the GDScript fallback in `scripts/` + `scenes/main.tscn`.

Genre: `%s` · C++ family: `%s`

## Requirements

- Godot 4.2+ (4.7 works; extension `compatibility_minimum` is 4.2)
- Python 3 + `pip install scons`
- Git (to clone [godot-cpp](https://github.com/godotengine/godot-cpp))
- A C++ compiler:
  - Windows: Visual Studio 2022 Build Tools (MSVC) — recommended
  - Or LLVM clang / MinGW
  - macOS: Xcode command-line tools
  - Linux: `g++` / `clang++`

## One-command build

Windows (PowerShell):

```powershell
.\\build_cpp.ps1
```

macOS / Linux:

```bash
chmod +x build_cpp.sh
./build_cpp.sh
```

First build clones `godot-cpp` and compiles bindings — often **5–15 minutes**. Later rebuilds of `src/` are faster.

## CMake alternative

```bash
cmake -S . -B build
cmake --build build --config Debug
```

Copy/rename the produced library into `bin/` to match `bin/game.gdextension`.

## After a successful build

1. Restart **Run Game** / reopen in Godot so `bin/libgame.*.dll` (or `.so`) loads.
2. Status HUD should say **C++ GDExtension ON**.
3. Optional: set `run/main_scene` in `project.godot` to `res://scenes/main_cpp.tscn` to run native `GamePlayer` / `GameWorld` nodes.

## Modify flow

Studio **Create again** updates `src/*.cpp` / `src/*.h` plus the GDScript fallback. Rebuild after C++ edits.

## Legal

Style recreations only. CC0 / original art. No commercial ROMs, WADs, or ripped assets.
""" % [genre_id, family]


static func _readme_cpp(genre_id: String) -> String:
	return """# C++ / GDExtension

Primary gameplay code lives in `src/` (godot-cpp classes: `GameApp`, `GamePlayer`, `GameWorld`, `GameEnemy`).

- Play now: **Run Game** uses GDScript in `scripts/` (fallback).
- Intended runtime: build with `build_cpp.ps1` / `build_cpp.sh`, then optionally `scenes/main_cpp.tscn`.
- Genre template: `%s`

See `docs/CPP_BUILD.md`.
""" % genre_id
