import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import 'battery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _currentDisplayWeight = 0; 
  double _lastStableWeight = 0; 
  double _pendingWeight = -1;   
  Timer? _debounceTimer;          

  double _todayTotal = 0;    
  double _dailyTarget = 2400; 
  double _battery = 100;
  String _userName = 'สมชาย';
  String _selectedLanguage = 'th'; // 🌟 ตัวแปรที่ซิงค์กับหน้าโปรไฟล์ผ่าน Firebase

  double _lastDrinkAmount = 0; 
  String _lastDrinkSubtitle = 'ยังไม่มีประวัติ';

  String _currentDrinkType = 'น้ำเปล่า'; // เก็บค่าภาษาไทยเพื่ออ้างอิงในระบบ
  String _lastDrinkTime = '08:00';
  String _sinceLastDrink = '0h 0m';

  int _streakDays = 0;
  bool _isInitialLoad = true;
  String _lastLoadedDateKey = "";
  
  StreamSubscription<DatabaseEvent>? _subscription;

  final List<String> _drinkTypes = [
    'น้ำเปล่า',
    'น้ำผลไม้',
    'กาแฟ/ชา',
    'นม',
    'ชานมไข่มุก',
    'อื่น ๆ',
  ];

  // 🌟 พจนานุกรมแปลภาษาหน้าแรก
  final Map<String, Map<String, String>> _homeTexts = {
    'th': {
      'greeting': 'สวัสดี, ',
      'progress': 'ความคืบหน้า: ',
      'from_goal': 'จากเป้าหมาย ',
      'water_in_cup': 'น้ำในแก้วตอนนี้: ',
      'miss_target': 'ยังขาดอีก ',
      'miss_target_hint': ' ml ถึงเป้าหมาย\nลองแบ่งจิบเรื่อยๆ ดูนะ!',
      'last_drink': 'ดื่มล่าสุด',
      'streak': 'ต่อเนื่อง',
      'days': ' วัน',
      'keep_it_up': 'เก่งมาก!',
      'select_drink': 'เลือกเครื่องดื่มในแก้ว',
      'reset_title': 'ตั้งค่าระบบใหม่',
      'reset_subtitle': 'รีเซ็ตยอดสะสมกรณีที่ข้อมูลผิดพลาด',
      'reset_button': 'รีเซ็ตข้อมูลน้ำวันนี้',
      'today': 'วันนี้ • ',
      'yesterday': 'เมื่อวาน • ',
      'no_history': 'ยังไม่มีประวัติ',
      'reset_success': 'รีเซ็ตข้อมูลปริมาณน้ำวันนี้แล้ว',
      'water': 'น้ำเปล่า',
      'juice': 'น้ำผลไม้',
      'coffee_tea': 'กาแฟ/ชา',
      'milk': 'นม',
      'boba': 'ชานมไข่มุก',
      'other': 'อื่น ๆ',
    },
    'en': {
      'greeting': 'Hello, ',
      'progress': 'Progress: ',
      'from_goal': 'Goal: ',
      'water_in_cup': 'Current water in cup: ',
      'miss_target': '',
      'miss_target_hint': ' ml remaining to reach goal\nKeep taking small sips!',
      'last_drink': 'Last Drink',
      'streak': 'Streak',
      'days': ' days',
      'keep_it_up': 'Great job!',
      'select_drink': 'Select drink in cup',
      'reset_title': 'System Settings',
      'reset_subtitle': 'Reset today\'s intake if data is incorrect',
      'reset_button': 'Reset today\'s data',
      'today': 'Today • ',
      'yesterday': 'Yesterday • ',
      'no_history': 'No history yet',
      'reset_success': 'Today\'s water intake reset successfully',
      'water': 'Water',
      'juice': 'Juice',
      'coffee_tea': 'Coffee/Tea',
      'milk': 'Milk',
      'boba': 'Boba Tea',
      'other': 'Others',
    }
  };

  String _t(String key) {
    return _homeTexts[_selectedLanguage]?[key] ?? key;
  }

  // แปลงประเภทเครื่องดื่มให้สอดคล้องกับภาษา
  String _translateDrinkType(String thaiKey) {
    if (_selectedLanguage == 'th') return thaiKey;
    switch (thaiKey) {
      case 'น้ำเปล่า': return _t('water');
      case 'น้ำผลไม้': return _t('juice');
      case 'กาแฟ/ชา': return _t('coffee_tea');
      case 'นม': return _t('milk');
      case 'ชานมไข่มุก': return _t('boba');
      case 'อื่น ๆ': return _t('other');
      default: return thaiKey;
    }
  }

  @override
  void initState() {
    super.initState();
    _lastLoadedDateKey = _getCurrentDateKey(); 
    _listenFirebase();
  }

  String _getCurrentDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _cleanOldHistoryLogs(Map<dynamic, dynamic> historyLogsMap) async {
    final DateTime today = DateTime.now();
    final DateTime cutoffDate = today.subtract(const Duration(days: 15));
    final String cutoffDateString = "${cutoffDate.year}-${cutoffDate.month.toString().padLeft(2, '0')}-${cutoffDate.day.toString().padLeft(2, '0')}";

    Map<String, dynamic> updates = {};
    bool hasOldData = false;

    historyLogsMap.forEach((key, value) {
      String dateKey = key.toString();
      if (dateKey.compareTo(cutoffDateString) < 0) {
        updates['history_logs/$dateKey'] = null;
        hasOldData = true;
      }
    });

    if (hasOldData) {
      try {
        await smartCupRef().update(updates);
      } catch (e) {
        debugPrint('Error cleaning old history: $e');
      }
    }
  }

  void _calculateLatestDrink(Map<dynamic, dynamic> mapData) {
    double foundAmount = 0;
    String foundTime = '';
    int maxTimestamp = -1;
    DateTime? foundDateTime;

    if (mapData['history_logs'] != null && mapData['history_logs'] is Map) {
      final historyMap = Map<dynamic, dynamic>.from(mapData['history_logs'] as dynamic);

      historyMap.forEach((dateKey, dateVal) {
        if (dateVal is Map && dateVal['logs'] != null && dateVal['logs'] is Map) {
          final logsMap = Map<dynamic, dynamic>.from(dateVal['logs'] as dynamic);
          final DateTime? parsedDate = DateTime.tryParse(dateKey.toString());

          logsMap.forEach((logId, logVal) {
            if (logVal is Map) {
              int ts = int.tryParse('${logVal['timestamp'] ?? logId}') ?? 0;
              if (ts > maxTimestamp) {
                maxTimestamp = ts;
                foundAmount = double.tryParse('${logVal['amount']}') ?? 0;
                foundTime = logVal['time']?.toString() ?? '';

                if (ts > 0) {
                  foundDateTime = DateTime.fromMillisecondsSinceEpoch(ts);
                } else if (parsedDate != null && foundTime.isNotEmpty) {
                  try {
                    final parts = foundTime.split(':');
                    if (parts.length >= 2) {
                      foundDateTime = DateTime(
                        parsedDate.year,
                        parsedDate.month,
                        parsedDate.day,
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                      );
                    }
                  } catch (_) {}
                }
              }
            }
          });
        }
      });
    }

    if (foundDateTime == null && mapData['last_drink_timestamp'] != null) {
      int ts = int.tryParse('${mapData['last_drink_timestamp']}') ?? 0;
      if (ts > 0) {
        foundDateTime = DateTime.fromMillisecondsSinceEpoch(ts);
        foundAmount = double.tryParse('${mapData['last_drink_amount']}') ?? foundAmount;
        foundTime = mapData['last_drink_time']?.toString() ?? foundTime;
      }
    }

    if (foundDateTime != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final drinkDay = DateTime(foundDateTime!.year, foundDateTime!.month, foundDateTime!.day);
      final diffDays = today.difference(drinkDay).inDays;

      if (diffDays == 0) {
        _lastDrinkSubtitle = '${_t('today')}$foundTime';
      } else if (diffDays == 1) {
        _lastDrinkSubtitle = '${_t('yesterday')}$foundTime';
      } else {
        _lastDrinkSubtitle = '${foundDateTime!.day}/${foundDateTime!.month} • $foundTime';
      }
    } else if (foundTime.isNotEmpty) {
      _lastDrinkSubtitle = foundTime;
    } else {
      _lastDrinkSubtitle = _t('no_history');
    }

    _lastDrinkAmount = foundAmount;
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

        double rawWeight = double.tryParse('${mapData['weight']}') ?? 0;
        
        double newDailyTarget = 2400;
        String newName = _userName;
        String newLang = _selectedLanguage;

        // 🌟 ดึงภาษาและโปรไฟล์จาก Firebase แบบ Realtime
        if (mapData['profile'] != null) {
          try {
            final profileMap = Map<dynamic, dynamic>.from(mapData['profile'] as dynamic);
            newDailyTarget = double.tryParse('${profileMap['daily_target']}') ?? 2400;
            newName = profileMap['name']?.toString() ?? _userName;
            newLang = profileMap['language']?.toString() ?? _selectedLanguage;
          } catch (_) {}
        }
        
        String currentDateKey = _getCurrentDateKey();
        
        if (_lastLoadedDateKey != currentDateKey) {
           if (mapData['history_logs'] != null) {
              Map<dynamic, dynamic> historyMap = Map<dynamic, dynamic>.from(mapData['history_logs']);
              if (historyMap[_lastLoadedDateKey] != null) {
                  double yesterdayTotal = double.tryParse('${historyMap[_lastLoadedDateKey]['daily_total']}') ?? 0;
                  if (yesterdayTotal < newDailyTarget) {
                      smartCupRef().update({'streak_days': 0});
                  }
              } else {
                  smartCupRef().update({'streak_days': 0});
              }
           } else {
              smartCupRef().update({'streak_days': 0});
           }

           _todayTotal = 0;
           _lastLoadedDateKey = currentDateKey;
           
           smartCupRef().update({
              'last_stable_weight': rawWeight < 20 ? 0 : rawWeight,
           });
        }

        double fbTodayTotal = 0;
        if (mapData['history_logs'] != null) {
            Map<dynamic, dynamic> historyMap = Map<dynamic, dynamic>.from(mapData['history_logs']);
            if (historyMap[currentDateKey] != null) {
                fbTodayTotal = double.tryParse('${historyMap[currentDateKey]['daily_total']}') ?? 0;
            }
            _cleanOldHistoryLogs(historyMap);
        }

        _calculateLatestDrink(mapData);

        double fbLastStable = double.tryParse('${mapData['last_stable_weight']}') ?? 0;

        if (_isInitialLoad) {
          _todayTotal = fbTodayTotal;

          if (rawWeight >= 20 && fbLastStable >= 20 && rawWeight < fbLastStable) {
            double missedDiff = fbLastStable - rawWeight;
            if (missedDiff >= 15) { 
              double prevTotal = _todayTotal;
              _todayTotal += missedDiff;
              final int nowMs = DateTime.now().millisecondsSinceEpoch;
              final String nowTime = formatTOD(TimeOfDay.now());

              Map<String, Object> updates = {
                'last_stable_weight': rawWeight,
                'last_drink_amount': missedDiff, 
                'last_drink_time': nowTime,
                'last_drink_timestamp': nowMs,
                'history_logs/$currentDateKey/daily_total': _todayTotal,
                'history_logs/$currentDateKey/logs/$nowMs': {
                  'time': nowTime,
                  'amount': missedDiff,
                  'type': _currentDrinkType,
                  'timestamp': nowMs,
                }
              };

              if (prevTotal < newDailyTarget && _todayTotal >= newDailyTarget) {
                 int currentStreak = int.tryParse('${mapData['streak_days']}') ?? 0;
                 updates['streak_days'] = currentStreak + 1;
              }

              smartCupRef().update(updates);
              fbLastStable = rawWeight;
              _lastDrinkAmount = missedDiff;
              _lastDrinkSubtitle = '${_t('today')}$nowTime';
            }
          }
          else if (fbLastStable == 0 && rawWeight >= 20) {
             smartCupRef().update({'last_stable_weight': rawWeight});
             fbLastStable = rawWeight;
          }

          _lastStableWeight = fbLastStable; 
          _pendingWeight = rawWeight;
          
          setState(() {
            _userName = newName;
            _selectedLanguage = newLang;
            _currentDisplayWeight = rawWeight < 20 ? 0 : rawWeight;
            _isInitialLoad = false;
          });
        } 
        else {
          setState(() {
            if (_lastLoadedDateKey == currentDateKey) {
              _todayTotal = fbTodayTotal;
            }
            _userName = newName;
            _selectedLanguage = newLang; // 🌟 อัปเดตภาษาจาก Firebase อัตโนมัติ
            _dailyTarget = newDailyTarget;
            _battery = double.tryParse('${mapData['battery_percent']}') ?? _battery;
            _currentDrinkType = mapData['current_drink_type']?.toString() ?? _currentDrinkType;
            
            if (!_drinkTypes.contains(_currentDrinkType)) {
               _currentDrinkType = 'น้ำเปล่า';
            }

            _lastDrinkTime = mapData['last_drink_time']?.toString() ?? _lastDrinkTime;
            _sinceLastDrink = mapData['since_last_drink']?.toString() ?? _sinceLastDrink;
            _streakDays = int.tryParse('${mapData['streak_days']}') ?? _streakDays;
          });

          if ((rawWeight - _pendingWeight).abs() > 15) {
            _pendingWeight = rawWeight; 
            _debounceTimer?.cancel();   
            
            _debounceTimer = Timer(const Duration(seconds: 5), () {
              if (!mounted) return;

              double finalWeight = _pendingWeight;

              setState(() {
                _currentDisplayWeight = finalWeight < 20 ? 0 : finalWeight;
              });

              if (finalWeight >= 20) {
                if (_lastStableWeight >= 20 && finalWeight < _lastStableWeight) {
                  double diff = _lastStableWeight - finalWeight;
                  
                  if (diff >= 15) { 
                    double prevTotal = _todayTotal;
                    double updatedTotal = _todayTotal + diff;
                    final int nowMs = DateTime.now().millisecondsSinceEpoch;
                    final String nowTime = formatTOD(TimeOfDay.now());

                    Map<String, Object> updates = {
                      'last_stable_weight': finalWeight,
                      'last_drink_amount': diff, 
                      'last_drink_time': nowTime,
                      'last_drink_timestamp': nowMs,
                      'history_logs/$currentDateKey/daily_total': updatedTotal, 
                      'history_logs/$currentDateKey/logs/$nowMs': {            
                        'time': nowTime,
                        'amount': diff,
                        'type': _currentDrinkType,
                        'timestamp': nowMs,
                      }
                    };

                    if (prevTotal < newDailyTarget && updatedTotal >= newDailyTarget) {
                       int currentStreak = int.tryParse('${mapData['streak_days']}') ?? 0;
                       updates['streak_days'] = currentStreak + 1;
                    }

                    smartCupRef().update(updates);
                    _lastDrinkAmount = diff;
                    _lastDrinkSubtitle = '${_t('today')}$nowTime';
                  } else {
                    smartCupRef().update({'last_stable_weight': finalWeight});
                  }
                } 
                else if (finalWeight > _lastStableWeight + 15) {
                  smartCupRef().update({'last_stable_weight': finalWeight});
                }
                
                _lastStableWeight = finalWeight;
              }
            });
          }
        }
      });
    } catch (e) {
      debugPrint('❌ [Home] Logic error: $e');
    }
  }

  Future<void> _selectDrink(String? translatedType) async {
    if (translatedType == null) return;
    
    // ค้นหาคีย์ภาษาไทยเพื่อเก็บลงระบบแบบมาตรฐาน
    String thaiKey = 'น้ำเปล่า';
    for (String key in _drinkTypes) {
      if (_translateDrinkType(key) == translatedType) {
        thaiKey = key;
        break;
      }
    }

    setState(() {
      _currentDrinkType = thaiKey;
    });

    if (!isFirebaseReady()) return;
    try {
      await smartCupRef().update({'current_drink_type': thaiKey});
    } catch (e) {}
  }

  Future<void> _resetWater() async {
    if (!isFirebaseReady()) return;

    try {
      final snapshot = await smartCupRef('weight').get();
      final currentWeight = double.tryParse('${snapshot.value}') ?? 0.0;
      String dateKey = _getCurrentDateKey();

      await smartCupRef().update({
        'last_stable_weight': currentWeight,
        'history_logs/$dateKey': null, 
      });

      _lastStableWeight = currentWeight >= 20 ? currentWeight : 0;
      _pendingWeight = currentWeight;
      
      setState(() {
        _currentDisplayWeight = currentWeight < 20 ? 0 : currentWeight;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('reset_success'))),
      );
    } catch (e) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double percent = _dailyTarget <= 0
        ? 0.0
        : (_todayTotal / _dailyTarget).clamp(0.0, 1.0).toDouble();

    final double remaining = (_dailyTarget - _todayTotal)
        .clamp(0.0, double.infinity)
        .toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F9), 
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), 
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 30),
                  
                  _buildHydrationDashboard(percent, remaining),
                  
                  const SizedBox(height: 24),
                  if (remaining > 0) _buildNotificationBanner(remaining),
                  const SizedBox(height: 24),
                  
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  
                  _buildDrinkTypeCard(), 
                  const SizedBox(height: 24),
                  
                  _buildResetButton(), 
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SmartCup Dashboard', style: TextStyle(color: Color(0xFF5C6BC0), fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${_t('greeting')}$_userName 💧', style: const TextStyle(color: Color(0xFF1A237E), fontSize: 26, fontWeight: FontWeight.bold)),
          ],
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => BatteryScreen(battery: _battery)));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: const Color(0xFF3949AB).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Icon(Icons.battery_charging_full, color: _battery > 20 ? accentGreen : Colors.red, size: 20),
                const SizedBox(width: 6),
                Text('${_battery.toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHydrationDashboard(double percent, double remaining) {
    return Container(
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
          Text(
            '${_t('progress')}${(percent * 100).toInt()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${formatNumber(_todayTotal)} ml',
                style: const TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_t('from_goal')}${formatNumber(_dailyTarget)} ml',
                style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
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
                const Icon(Icons.water_drop_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_t('water_in_cup')}${formatNumber(_currentDisplayWeight)} ml',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNotificationBanner(double remaining) {
    return Container(
      width: double.infinity,
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
            child: const Icon(Icons.notifications_active, color: Color(0xFFD46B08), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              '${_t('miss_target')}${formatNumber(remaining)}${_t('miss_target_hint')}', 
              style: const TextStyle(color: Color(0xFFAD4E00), fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)
            )
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _infoCard(
            icon: Icons.history, 
            title: _t('last_drink'), 
            value: _lastDrinkAmount > 0 ? '${formatNumber(_lastDrinkAmount)} ml' : '0 ml', 
            subtitle: _lastDrinkSubtitle, 
            color: const Color(0xFF5C6BC0),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _infoCard(
            icon: Icons.local_fire_department, 
            title: _t('streak'), 
            value: '$_streakDays${_t('days')}', 
            subtitle: _t('keep_it_up'), 
            color: Colors.orangeAccent,
          ),
        ),
      ],
    );
  }

  Widget _infoCard({required IconData icon, required String title, required String value, required String subtitle, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF3949AB).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(color: textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Color(0xFF1A237E), fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: textGrey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDrinkTypeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF3949AB).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        children: [
          Container(
            width: 55, height: 55,
            decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(18)),
            child: Icon(_getDrinkIcon(_currentDrinkType), color: const Color(0xFF3949AB), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('select_drink'), style: const TextStyle(color: textGrey, fontSize: 13)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _translateDrinkType(_currentDrinkType),
                    icon: const Icon(Icons.keyboard_arrow_down, color: textGrey),
                    style: const TextStyle(color: Color(0xFF1A237E), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Arial'),
                    onChanged: (String? newValue) => _selectDrink(newValue),
                    items: _drinkTypes.map<DropdownMenuItem<String>>((String value) => 
                      DropdownMenuItem<String>(
                        value: _translateDrinkType(value), 
                        child: Text(_translateDrinkType(value))
                      )
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDrinkIcon(String type) {
    switch (type) {
      case 'น้ำเปล่า': return Icons.water_drop;
      case 'น้ำผลไม้': return Icons.local_drink;
      case 'กาแฟ/ชา': return Icons.coffee;
      case 'นม': return Icons.local_drink_outlined;
      case 'ชานมไข่มุก': return Icons.bubble_chart;
      default: return Icons.local_bar;
    }
  }

  Widget _buildResetButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF3949AB).withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(_t('reset_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A237E))),
          const SizedBox(height: 6),
          Text(_t('reset_subtitle'), style: const TextStyle(color: textGrey, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _resetWater,
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(_t('reset_button')),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
              ),
            ),
          ),
        ],
      ),
    );
  }
}