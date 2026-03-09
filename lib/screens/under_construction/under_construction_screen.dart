import 'package:flutter/material.dart';

class UnderConstructionPage extends StatelessWidget {
  const UnderConstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold proporciona la estructura básica de la página
    return Scaffold(
      backgroundColor: Colors.white, // Fondo limpio
      // Center asegura que todo el bloque de contenido esté en medio de la pantalla
      body: Center(
        // Padding para que el contenido no toque los bordes en pantallas pequeñas
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          // Column organiza los elementos (imagen, texto) verticalmente
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centra verticalmente dentro de la columna
            crossAxisAlignment: CrossAxisAlignment.center, // Centra horizontalmente
            children: [
              // 1. LA IMAGEN CENTRAL
              // Asegúrate de que la ruta coincida exactamente con la de tu pubspec.yaml
              Image.asset(
                'assets/images/construction_image.png', // <--- CAMBIA ESTO por el nombre real de tu archivo
                width: 300, // Ajusta el tamaño según necesites
                fit: BoxFit.contain, // Asegura que la imagen se vea completa sin deformarse
              ),

              // Espacio entre la imagen y el texto
              const SizedBox(height: 40),

              // 2. TÍTULO PRINCIPAL
              const Text(
                'Página Bajo Construcción',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              // Espacio pequeño
              const SizedBox(height: 16),

              // 3. SUBTÍTULO / MENSAJE
              Text(
                'Estamos trabajando duro para traerte algo increíble. ¡Vuelve pronto!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5, // Altura de línea para mejor lectura
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}