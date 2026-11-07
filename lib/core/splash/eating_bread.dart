import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Fondo crema de la espera (mismo tono cálido de la app).
const splashCream = Color(0xFFFDFBF7);
const splashCrust = Color(0xFF4A2C11);

const splashLottieAsset = 'assets/splash/spreading_butter.json';

/// Pantalla de carga al arrancar: pan untando mantequilla (Lottie).
class EatingBreadSplash extends StatelessWidget {
  const EatingBreadSplash({super.key, this.message = 'Preparando la ruta…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: splashCream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EatingBread(size: 200),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: splashCrust,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animación de pan (también la usa AuthGate).
class EatingBread extends StatelessWidget {
  const EatingBread({super.key, this.size = 160});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        splashLottieAsset,
        fit: BoxFit.contain,
        repeat: true,
        frameRate: FrameRate.max,
      ),
    );
  }
}
