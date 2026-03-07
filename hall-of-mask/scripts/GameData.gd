extends Node

# ── Personaje seleccionado ─────────────────────────────────────────────────
var selected_character: String = ""

# ── Niveles visitados ──────────────────────────────────────────────────────
var visited_levels: Dictionary = {
	"lobby":   false,
	"level_1": false,
	"level_2": false,
	"level_3": false,
	"level_4": false,
}

# ══════════════════════════════════════════════════════════════════════════
# DIÁLOGOS POR PERSONAJE Y NIVEL
# Acceso: DIALOGS[selected_character][level_id]["entry" | "exit"]
# ══════════════════════════════════════════════════════════════════════════
const DIALOGS: Dictionary = {
	"kael": {
		"lobby": {
			"entry": "Este lugar guarda demasiadas respuestas.\nY yo guardé demasiados silencios.",
		},
		"level_1": {
			"entry": "Ren. Voy por ti. Aunque tenga que romper este lugar.",
			"exit":  "Una máscara… como la de la habitación de Ren.\nSiempre supe que algo estaba mal.",
		},
		"level_2": {
			"entry": "Enemigos arriba. Pasillos estrechos.\nNo todo se resuelve con fuerza.",
			"exit":  "Cayne… conectado con Vayne.\nRen vino aquí buscando esto.",
		},
		"level_3": {
			"entry": "Vayne…\nEsta historia empezó antes que nosotros.",
			"exit":  "Ren no está muerto.\nSolo está perdido.",
		},
		"level_4": {
			"entry": "Demasiados secretos guardados demasiado tiempo.",
			"exit":  "Ren estuvo aquí.\nNo estaba huyendo. Buscaba respuestas.",
		},
	},

	"eli": {
		"lobby": {
			"entry": "¿Este es el Hall? Ren… ¿qué fue lo que encontraste aquí?",
		},
		"level_1": {
			"entry": "Ren. Soy yo. Ya voy.",
			"exit":  "Las máscaras no son malas.\nEl problema es cuando no te la puedes quitar.",
		},
		"level_2": {
			"entry": "Esto no parece una prisión.\nParece un escondite.",
			"exit":  "Dorian sabía.\nY mamá también.",
		},
		"level_3": {
			"entry": "Cayne… Vayne…\nSiempre estuvieron conectados.",
			"exit":  "Ren no necesita saber de dónde viene.\nPero tiene derecho a saberlo.",
		},
		"level_4": {
			"entry": "¿Esto muestra quién soy o quién creo ser?",
			"exit":  "Ren estuvo aquí.\nCreo que estaba tratando de entender quién es.",
		},
	},
}

# ── API pública ────────────────────────────────────────────────────────────

func select_character(char_name: String) -> void:
	selected_character = char_name

func mark_level_visited(level_id: String) -> void:
	if visited_levels.has(level_id):
		visited_levels[level_id] = true

func is_first_visit(level_id: String) -> bool:
	if visited_levels.has(level_id):
		return not visited_levels[level_id]
	return false
