extends Resource
class_name WeaponData

# Tipos de armas soportados
enum Type { MELEE_1H, MELEE_2H, BOW, CROSSBOW, GUN, GATLING, MAGIC_STAFF, MAGIC_WAND }
enum AmmoType { NONE, ARROW, BULLET, MANA }

@export_group("Identidad Visual")
@export var name: String = "Arma Nueva"
@export var weapon_scene: PackedScene  # Arrastra aquí tu .tscn o .gltf
@export var anim_idle: String = "Empty"    # Animación al sostenerla
@export var anim_attack: String = "Attack" # Animación al usarla
@export var icon: Texture2D        # Para el inventario (futuro)

@export_group("Mecánicas de Combate")
@export var type: Type = Type.MELEE_1H
@export var damage_mult: float = 1.0     # Se multiplica por tus base_stats
@export var knockback_force: float = 8.0  # Fuerza de retroceso
@export var jump_force: float = 4.0      # Fuerza del salto del retroceso
@export var stamina_cost: float = 10.0
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.5        # Tiempo entre ataques

@export_group("Restricciones")
@export var is_two_handed: bool = false
@export var can_use_prone: bool = false  # ¿Permitido al reptar?

@export_group("Efectos y Rango")
@export var poison_dmg: float = 0.0      # Daño veneno
@export var slow_factor: float = 1.0     # 0.5 = Enemigo 50% lento
@export var projectile_scene: PackedScene # Para arcos/magia/balas
@export var charge_time: float = 0.0     # Para arcos/báculos cargados


@export_group("Combat Timing")
@export var damage_delay: float = 0.4  # Tiempo desde el click hasta que el golpe "conecta"
@export var hitbox_duration: float = 0.1 # Cuánto tiempo se queda activo el daño (la ventana de golpe)
