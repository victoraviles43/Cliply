import Foundation

struct EmojiEntry: Identifiable {
    let symbol: String
    let name: String
    let category: String
    var id: String { symbol }
}

enum EmojiCatalog {
    static let categories = ["Todos", "Caras", "Gestos", "Amor", "Animales", "Comida", "Viajes", "Objetos"]

    static let all: [EmojiEntry] = [
        entries("Caras", "😀:sonrisa|😃:feliz|😄:alegría|😁:sonriente|😆:risa|😅:nervioso|🤣:carcajada|😂:llorar de risa|🙂:sonrisa leve|🙃:al revés|😉:guiño|😊:sonrojado|😇:ángel|🥰:enamorado|😍:ojos de corazón|🤩:estrellas|😘:beso|😗:besar|😋:sabroso|😛:lengua|😜:guiño lengua|🤪:locura|😎:genial|🤓:estudioso|🧐:monóculo|🤔:pensando|🤫:silencio|🤗:abrazo|😏:picardía|😌:alivio|😴:dormido|😷:mascarilla|🤒:enfermo|🤯:mente explotada|🥳:fiesta|😕:confundido|🙁:triste|☹️:desanimado|😢:llorar|😭:llanto|😤:frustrado|😠:enojado|😡:furioso|🤬:maldecir|😱:grito|😨:miedo|🥺:súplica|😬:incómodo"),
        entries("Gestos", "👍:pulgar arriba|👎:pulgar abajo|👌:perfecto|✌️:victoria|🤞:dedos cruzados|🤟:te quiero|🤘:rock|👋:saludo|🤚:mano levantada|🖐️:mano abierta|✋:alto|🫶:manos corazón|👏:aplausos|🙌:celebración|🤝:apretón de manos|🙏:gracias|💪:fuerza|👀:ojos|👆:arriba|👇:abajo|👉:derecha|👈:izquierda|☝️:uno|✍️:escribir|🤦:vergüenza|🤷:no sé"),
        entries("Amor", "❤️:corazón rojo|🧡:corazón naranja|💛:corazón amarillo|💚:corazón verde|💙:corazón azul|💜:corazón morado|🖤:corazón negro|🤍:corazón blanco|💖:corazón brillante|💗:corazón creciente|💓:latido|💕:dos corazones|💞:corazones girando|💘:corazón flecha|💝:regalo corazón|💔:corazón roto|❤️‍🔥:corazón en llamas|💯:cien puntos|✨:brillo|🌟:estrella|⭐:estrella amarilla|🔥:fuego|🎉:confeti|🎊:celebración|🎈:globo"),
        entries("Animales", "🐶:perro|🐱:gato|🐭:ratón|🐹:hámster|🐰:conejo|🦊:zorro|🐻:oso|🐼:panda|🐨:koala|🐯:tigre|🦁:león|🐮:vaca|🐷:cerdo|🐸:rana|🐵:mono|🐔:gallina|🐧:pingüino|🐦:pájaro|🦄:unicornio|🐝:abeja|🦋:mariposa|🐢:tortuga|🐬:delfín|🐙:pulpo"),
        entries("Comida", "🍎:manzana|🍐:pera|🍊:naranja|🍋:limón|🍌:plátano|🍉:sandía|🍇:uvas|🍓:fresa|🫐:arándano|🍒:cerezas|🍑:durazno|🥭:mango|🍍:piña|🥑:aguacate|🥦:brócoli|🥕:zanahoria|🌽:maíz|🍞:pan|🥐:croissant|🥨:pretzel|🧀:queso|🍕:pizza|🍔:hamburguesa|🍟:papas fritas|🌮:taco|🌯:burrito|🍣:sushi|🍜:ramen|🍩:dona|🍪:galleta|🎂:pastel|☕:café|🍵:té|🥤:bebida|🍺:cerveza"),
        entries("Viajes", "🚗:auto|🚕:taxi|🚌:autobús|🚎:trolebús|🏎️:carreras|🚓:policía|🚑:ambulancia|🚒:bomberos|🚲:bicicleta|🛴:patinete|🚆:tren|🚇:metro|✈️:avión|🚀:cohete|🛸:ovni|🚁:helicóptero|⛵:velero|🚢:barco|🗺️:mapa|🧭:brújula|🏖️:playa|🏔️:montaña|🏕️:campamento|🏙️:ciudad|🏠:casa|🌍:mundo|🌎:américa|🌙:luna|☀️:sol|🌈:arcoíris"),
        entries("Objetos", "📱:teléfono|💻:computadora|⌨️:teclado|🖥️:monitor|🖨️:impresora|📷:cámara|🎥:video|🎧:audífonos|🎮:videojuego|💡:idea|🔦:linterna|🔋:batería|📚:libros|📖:libro|📝:nota|✏️:lápiz|📎:clip|📌:chincheta|📍:ubicación|🔒:candado|🔑:llave|🛠️:herramientas|⚙️:ajustes|🔔:campana|⏰:alarma|⌚:reloj|📅:calendario|💰:dinero|💳:tarjeta|🎁:regalo|🏆:trofeo|✅:correcto|❌:incorrecto|⚠️:advertencia|❓:pregunta")
    ].flatMap { $0 }

    private static func entries(_ category: String, _ values: String) -> [EmojiEntry] {
        values.split(separator: "|").compactMap { pair in
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return EmojiEntry(symbol: String(parts[0]), name: String(parts[1]), category: category)
        }
    }
}
