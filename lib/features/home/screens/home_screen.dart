import 'package:flutter/material.dart';

import 'package:my_app/core/database/tables/user_model.dart';
import 'package:my_app/core/database/tables/medicines_model.dart';
import 'package:my_app/core/database/tables/db.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserModel? _user;
  List<MedicineModel> _medicines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = await DBHelper.instance.getLatestUser();
    final medicines = await DBHelper.instance.getMedicines();
    setState(() {
      _user = user;
      _medicines = medicines;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text(
              'Your Medicines',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_medicines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('No medicines added yet.')),
              )
            else
              ..._medicines.map((m) => _MedicineCard(medicine: m)),
          ],
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine});
  final MedicineModel medicine;

  @override
  Widget build(BuildContext context) {
    final color = medicine.isActive
        ? Theme.of(context).colorScheme.primary
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: CustomPaint(
            painter: _StethoscopeCrossPainter(color: color),
          ),
        ),
        title: Text(medicine.name),
        subtitle: Text(
          '${medicine.form} • ${medicine.doseUnit}'
              '${medicine.note != null ? '\n${medicine.note}' : ''}',
        ),
        isThreeLine: medicine.note != null,
        trailing: medicine.isActive
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.pause_circle_outline, color: Colors.grey),
      ),
    );
  }
}

class _StethoscopeCrossPainter extends CustomPainter {
  _StethoscopeCrossPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final loopCenter = Offset(w * 0.40, h * 0.40);
    final loopRadius = w * 0.30;
    canvas.drawCircle(loopCenter, loopRadius, strokePaint);

    final path = Path()
      ..moveTo(loopCenter.dx - loopRadius * 0.05, loopCenter.dy + loopRadius)
      ..cubicTo(
        w * 0.30, h * 0.80,
        w * 0.55, h * 0.92,
        w * 0.80, h * 0.85,
      )
      ..cubicTo(
        w * 0.95, h * 0.80,
        w * 0.95, h * 0.65,
        w * 0.85, h * 0.62,
      );
    canvas.drawPath(path, strokePaint);

    canvas.drawCircle(Offset(w * 0.85, h * 0.62), w * 0.045, fillPaint);
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.62),
      w * 0.045,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.02,
    );

    final crossSize = loopRadius * 0.85;
    final crossThickness = crossSize * 0.34;
    final rrect1 = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: loopCenter,
        width: crossThickness,
        height: crossSize,
      ),
      Radius.circular(crossThickness * 0.25),
    );
    final rrect2 = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: loopCenter,
        width: crossSize,
        height: crossThickness,
      ),
      Radius.circular(crossThickness * 0.25),
    );
    canvas.drawRRect(rrect1, fillPaint);
    canvas.drawRRect(rrect2, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _StethoscopeCrossPainter oldDelegate) =>
      oldDelegate.color != color;
}