import 'package:material_ui/material_ui.dart';

class FeaturePlaceholderScreen extends StatelessWidget {
  const FeaturePlaceholderScreen({
    required this.title,
    required this.description,
    required this.icon,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: const Color(0xFF28201E),
                child: Icon(
                  icon,
                  size: 30,
                  color: const Color(0xFFFF987B),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF9AA4B2),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              const Chip(
                avatar: Icon(Icons.construction_outlined, size: 16),
                label: Text('Planned milestone'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
