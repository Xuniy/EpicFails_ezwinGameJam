extends Node

## État de session partagé entre les scènes : type d'appareil choisi au titre
## (pour le tutoriel) et fin de partie (pour ne déclencher l'écran de fin qu'une fois).

const DEVICE_XBOX := "xbox"
const DEVICE_KEYBOARD_MOUSE := "clavier_souris"

var input_device: String = DEVICE_KEYBOARD_MOUSE
var game_over: bool = false
