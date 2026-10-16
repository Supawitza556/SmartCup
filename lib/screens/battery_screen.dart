import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/theme.dart';
import '../core/utils.dart';

class BatteryScreen extends StatefulWidget {
  final double battery;

  const BatteryScreen({super.key, required this.battery});

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  late double _battery;
  bool _charging = false;
  String _cableType = 'USB Type-C';
  double _capacity = 2500; // mAh
  double _voltage = 3.95;  // V
  int _batteryHealth = 98; // %
  String _selectedLanguage = 'th'; // 🌟 ตัวแปรภาษา

  StreamSubscription<DatabaseEvent>? _subscription;

  // 🌟 พจนานุกรมแปลหน้าแบตเตอรี่
  final Map<String, Map<String, String>> _batTexts = {
    'th': {
      'title': 'สถานะแบตเตอรี่',
      'charging': 'กำลังชาร์จไฟ',
      'remaining': 'แบตเตอรี่คงเหลือ',
      'cable': 'กำลังเชื่อมต่อสายชาร์จ',
      'available_time': 'ใช้งานได้อีกประมาณ',
      'hours': 'ชม.',
      'warn_low': 'แบตเตอรี่ใกล้หมด กรุณาชาร์จ SmartCup เพื่อการบันทึกข้อมูลที่ต่อเนื่อง',
      'hw_info': 'ข้อมูลฮาร์ดแวร์แบตเตอรี่',
      'voltage': 'แรงดันไฟฟ้า (Voltage)',
      'voltage_sub': 'ช่วงทำงานปกติ 3.3V – 4.2V',
      'capacity': 'ความจุเซลล์แบตเตอรี่',
      'capacity_sub': 'Li-ion Battery',
      'health': 'สุขภาพแบตเตอรี่ (Health)',
      'health_sub': 'สถานะเซลล์สมบูรณ์',
      'port': 'พอร์ตชาร์จ',
      'port_sub': 'รองรับไฟชาร์จ 5V / 1A',
      'tip_prefix': 'เคล็ดลับ: ',
      'tip_desc': 'ไม่ควรปล่อยให้แบตเตอรี่หมดเกลี้ยง (0%) บ่อยครั้ง เพื่อยืดอายุการใช้งานของเซลล์แบตเตอรี่ในแก้วน้ำ',
    },
    'en': {
      'title': 'Battery Status',
      'charging': 'Charging',
      'remaining': 'Battery Remaining',
      'cable': 'Connected to charger',
      'available_time': 'Estimated time remaining',
      'hours': 'hrs.',
      'warn_low': 'Low battery. Please charge your SmartCup to continue logging data.',
      'hw_info': 'Hardware Information',
      'voltage': 'Voltage',
      'voltage_sub': 'Normal range: 3.3V – 4.2V',
      'capacity': 'Battery Capacity',
      'capacity_sub': 'Li-ion Battery',
      'health': 'Battery Health',
      'health_sub': 'Healthy Cell Status',
      'port': 'Charging Port',
      'port_sub': 'Supports 5V / 1A',
      'tip_prefix': 'Tip: ',
      'tip_desc': 'Avoid draining the battery completely (0%) frequently to prolong the battery lifespan.',
    }
  };

  String _t(String key) {
    return _batTexts[_selectedLanguage]?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _battery = widget.battery;
    _listenFirebase();
  }

  void _listenFirebase() {
    if (!isFirebaseReady()) return;

    try {
      _subscription = smartCupRef().onValue.listen((event) {
        final data = event.snapshot.value;
        if (data == null) return;

        Map<dynamic, dynamic> mapData;
        try {
          mapData = Map<dynamic, dynamic>.from(data as dynamic);
        } catch (_) { return; }

        String lang = _selectedLanguage;
        if (mapData['profile'] != null) {
          try {
            final profile = Map<dynamic, dynamic>.from(mapData['profile'] as dynamic);
            lang = profile['language']?.toString() ?? _selectedLanguage;
          } catch (_) {}
        }

        if (!mounted) return;

        setState(() {
          _selectedLanguage = lang;
          _battery = double.tryParse('${mapData['battery_percent'] ?? _battery}') ?? _battery;
          _charging = mapData['charging'] == true || mapData['is_charging'] == true;
          _cableType = '${mapData['cable_type'] ?? _cableType}';
          _capacity = double.tryParse('${mapData['battery_capacity'] ?? _capacity}') ?? _capacity;
          _voltage = double.tryParse('${mapData['battery_voltage'] ?? _voltage}') ?? _voltage;
          _batteryHealth = int.tryParse('${mapData['battery_health'] ?? _batteryHealth}') ?? _batteryHealth;
        });
      });
    } catch (e) {
      debugPrint('Battery listener error: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimatedHours = ((_battery / 100) * 18).clamp(0.0, 48.0);

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEEF2F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
        title: Text(
          _t('title'),
          style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                        blurRadius: 25,
                        offset: const Offset(0, 12),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _charging ? Icons.bolt : Icons.battery_charging_full_rounded,
                        color: _charging ? Colors.amberAccent : Colors.white,
                        size: 54, 
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_battery.toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _charging ? _t('charging') : _t('remaining'),
                        style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 35),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _charging
                                  ? '${_t('cable')} ($_cableType)'
                                  : '${_t('available_time')} ${estimatedHours.toStringAsFixed(1)} ${_t('hours')}',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                if (_battery <= 20 && !_charging)
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7E6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFD591), width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: Color(0xFFFFD591), shape: BoxShape.circle),
                          child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFD46B08), size: 18),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _t('warn_low'),
                            style: const TextStyle(
                              color: Color(0xFFAD4E00),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                Text(
                  _t('hw_info'),
                  style: const TextStyle(
                    color: Color(0xFF1A237E),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                _specTile(
                  icon: Icons.electrical_services_rounded,
                  title: _t('voltage'),
                  value: '${_voltage.toStringAsFixed(2)} V',
                  sub: _t('voltage_sub'),
                ),
                _specTile(
                  icon: Icons.battery_saver_rounded,
                  title: _t('capacity'),
                  value: '${_capacity.toInt()} mAh',
                  sub: _t('capacity_sub'),
                ),
                _specTile(
                  icon: Icons.health_and_safety_outlined,
                  title: _t('health'),
                  value: '$_batteryHealth%',
                  sub: _t('health_sub'),
                ),
                _specTile(
                  icon: Icons.power_outlined,
                  title: _t('port'),
                  value: _cableType,
                  sub: _t('port_sub'),
                ),
                const SizedBox(height: 16),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: const Color(0xFF3949AB).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.lightbulb_outline, color: Colors.orange, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: textGrey, fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, fontFamily: 'Arial'),
                            children: [
                              TextSpan(text: _t('tip_prefix'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: _t('tip_desc')),
                            ]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _specTile({
    required IconData icon,
    required String title,
    required String value,
    required String sub,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF3949AB).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EAF6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF3949AB), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF1A237E),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(sub, style: const TextStyle(color: textGrey, fontSize: 12, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A237E),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}