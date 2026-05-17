import 'package:flutter/material.dart';

class UnderConstructionPage extends StatelessWidget {
  const UnderConstructionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo de Android
              Container(
                decoration: BoxDecoration(
                  color: Colors.blueGrey,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(24),
                child: const Icon(
                  Icons.construction,
                  size: 80,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 32),

              // Nombre de la app con logo de Android
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.green.shade400,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: const Text(
                      '🤖',
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Luia',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Título principal
              const Text(
                'En Construcción',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                ),
              ),

              const SizedBox(height: 16),

              // Subtítulo / mensaje
              Text(
                'Estamos trabajando duro para traerte algo increíble.\n¡Vuelve pronto!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 48),

              // Indicador de progreso opcional
              SizedBox(
                width: 100,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.blueGrey,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}