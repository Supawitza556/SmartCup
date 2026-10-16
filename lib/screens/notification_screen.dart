import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/theme.dart';
import '../core/utils.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _enabled = true;
  
  int _alertHours = 2;
  int _alertMinutes = 0;

  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 6, minute: 0);
  String _selectedLanguage = 'th'; // 🌟 ตัวแปรภาษา

  List<Map<String, String>> _logs = [];

  String _currentDateKey = '';
  Timer? _midnightTimer;

  StreamSubscription<DatabaseEvent>? _langSubscription; // 🌟 ตัวดักจับภาษา
  StreamSubscription<DatabaseEvent>? _settingsSubscription;
  StreamSubscription<DatabaseEvent>? _logsSubscription;

  // 🌟 พจนานุกรมแปลภาษาหน้าการแจ้งเตือน
  final Map<String, Map<String, String>> _notiTexts = {
    'th': {
      'title': 'การแจ้งเตือน',
      'subtitle': 'ตั้งค่าการแจ้งเตือนของ SmartCup',
      'enable_noti': 'เปิดการแจ้งเตือน',
      'freq_title': 'ความถี่ในการแจ้งเตือน',
      'hour': 'ชั่วโมง',
      'hr': 'ชม.',
      'min': 'น.',
      'custom': 'กำหนดเอง',
      'quiet_time': 'ช่วงเวลาปิดเสียงแจ้งเตือน',
      'start': 'เริ่มต้น',
      'end': 'สิ้นสุด',
      'save_settings': 'บันทึกการตั้งค่า',
      'today_history': 'ประวัติการแจ้งเตือนวันนี้',
      'no_history': 'ยังไม่มีประวัติการแจ้งเตือนในวันนี้',
      'save_success': 'บันทึกการตั้งค่าแล้ว',
      'cancel': 'ยกเลิก',
      'ok': 'ตกลง',
      'select_duration': 'เลือกระยะเวลา',
      'time_to_drink': 'ถึงเวลาที่ควรดื่มน้ำ',
    },
    'en': {
      'title': 'Notifications',
      'subtitle': 'Manage SmartCup alert settings',
      'enable_noti': 'Enable Notifications',
      'freq_title': 'Notification Frequency',
      'hour': 'Hour',
      'hr': 'hr',
      'min': 'm',
      'custom': 'Custom',
      'quiet_time': 'Do Not Disturb (Quiet Time)',
      'start': 'Start',
      'end': 'End',
      'save_settings': 'Save Settings',
      'today_history': 'Today\'s Alert History',
      'no_history': 'No notifications today.',
      'save_success': 'Settings saved successfully',
      'cancel': 'Cancel',
      'ok': 'OK',
      'select_duration': 'Select Duration',
      'time_to_drink': 'Time to drink water',
    }
  };

  String _t(String key) {
    return _notiTexts[_selectedLanguage]?[key] ?? key;
  }

  @override
  void initState() {
    super.initState();
    _currentDateKey = _getCurrentDateKey();
    _listenLanguage(); // 🌟 เรียกฟังภาษาทันที
    _listenSettings();
    _listenLogs();

    _midnightTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final nowKey = _getCurrentDateKey();
      if (nowKey != _currentDateKey) {
        _currentDateKey = nowKey;
        _cleanMidnightLogs();
      }
    });
  }

  String _getCurrentDateKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  int _timeStringToMinutes(String timeStr) {
    try {
      final clean = timeStr.replaceAll(' น.', '').replaceAll(' AM', '').replaceAll(' PM', '').trim();
      final parts = clean.split(':');
      if (parts.length >= 2) {
        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _cleanMidnightLogs() async {
    if (!isFirebaseReady()) return;
    try {
      await smartCupRef('notification_logs').remove();
      if (mounted) {
        setState(() {
          _logs = [];
        });
      }
    } catch (e) {
      debugPrint('Error cleaning midnight logs: $e');
    }
  }

  // 🌟 ฟังการตั้งค่าภาษาแบบ Real-time
  void _listenLanguage() {
    if (!isFirebaseReady()) return;
    try {
      _langSubscription = smartCupRef('profile/language').onValue.listen((event) {
        final lang = event.snapshot.value?.toString() ?? 'th';
        if (mounted) {
          setState(() {
            _selectedLanguage = lang;
          });
        }
      });
    } catch (e) {
      debugPrint('Noti Lang error: $e');
    }
  }

  void _listenSettings() {
    if (!isFirebaseReady()) return;

    try {
      _settingsSubscription = smartCupRef('settings').onValue.listen((event) {
        final data = event.snapshot.value;
        if (data == null) return;

        Map<dynamic, dynamic> mapData;
        try {
          mapData = Map<dynamic, dynamic>.from(data as dynamic);
        } catch (_) { return; }

        if (!mounted) return;

        setState(() {
          _enabled = mapData['notification_enabled'] != false;
          _alertHours = int.tryParse('${mapData['alert_hours'] ?? _alertHours}') ?? _alertHours;
          _alertMinutes = int.tryParse('${mapData['alert_minutes'] ?? _alertMinutes}') ?? _alertMinutes;
          
          if (mapData['quiet_start'] != null) _quietStart = parseTOD(mapData['quiet_start']);
          if (mapData['quiet_end'] != null) _quietEnd = parseTOD(mapData['quiet_end']);
        });
      });
    } catch (e) {
      debugPrint('Notification Settings error: $e');
    }
  }

  void _listenLogs() {
    if (!isFirebaseReady()) return;

    try {
      _logsSubscription = smartCupRef('notification_logs')
          .limitToLast(30)
          .onValue
          .listen((event) {
        final data = event.snapshot.value;
        if (data == null) {
          if (mounted) setState(() => _logs = []);
          return;
        }

        try {
          final Map<dynamic, dynamic> rawMap = Map<dynamic, dynamic>.from(data as dynamic);
          final List<Map<String, dynamic>> tempLogs = [];
          final String todayKey = _getCurrentDateKey();
          final Map<String, dynamic> dbUpdates = {};

          rawMap.forEach((key, value) {
            if (value is Map) {
              final String logKey = key.toString();
              final String? itemDate = value['date']?.toString();
              final String timeStr = value['time']?.toString() ?? '';
              final String messageStr = value['message']?.toString() ?? 'ถึงเวลาที่ควรดื่มน้ำ';

              if (itemDate == null) {
                dbUpdates['notification_logs/$logKey/date'] = todayKey;
                tempLogs.add({
                  'time': timeStr,
                  'message': messageStr,
                  'sortKey': _timeStringToMinutes(timeStr),
                });
              } else if (itemDate != todayKey) {
                dbUpdates['notification_logs/$logKey'] = null;
              } else {
                tempLogs.add({
                  'time': timeStr,
                  'message': messageStr,
                  'sortKey': _timeStringToMinutes(timeStr),
                });
              }
            }
          });

          if (dbUpdates.isNotEmpty) {
            smartCupRef().update(dbUpdates);
          }

          tempLogs.sort((a, b) => (b['sortKey'] as int).compareTo(a['sortKey'] as int));

          final List<Map<String, String>> sortedLogs = tempLogs.map((item) => {
            'time': item['time'].toString(),
            'message': item['message'].toString(), // เก็บข้อความดิบไว้ก่อน
          }).toList();

          if (mounted) {
            setState(() {
              _logs = sortedLogs;
            });
          }
        } catch (e) {
          debugPrint('Error parsing notification logs: $e');
        }
      });
    } catch (e) {
      debugPrint('Notification Logs error: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (!isFirebaseReady()) return;

    try {
      await smartCupRef('settings').update({
        'notification_enabled': _enabled,
        'alert_hours': _alertHours,
        'alert_minutes': _alertMinutes,
        'interval_minutes': (_alertHours * 60) + _alertMinutes,
        'quiet_start': formatTOD(_quietStart),
        'quiet_end': formatTOD(_quietEnd),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('save_success')),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Notification save error: $e');
    }
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = start ? _quietStart : _quietEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);

    if (picked == null || !mounted) return;

    setState(() {
      if (start) {
        _quietStart = picked;
      } else {
        _quietEnd = picked;
      }
    });
  }

  void _showIntervalPicker() {
    int tempHours = _alertHours;
    int tempMinutes = _alertMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext builder) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(_t('cancel'), style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      _t('select_duration'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _alertHours = tempHours;
                          _alertMinutes = tempMinutes;
                        });
                        Navigator.pop(context);
                      },
                      child: Text(_t('ok'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF3949AB))),
                    )
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(hours: tempHours, minutes: tempMinutes),
                  onTimerDurationChanged: (Duration newDuration) {
                    tempHours = newDuration.inHours;
                    tempMinutes = newDuration.inMinutes % 60;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _langSubscription?.cancel();
    _settingsSubscription?.cancel();
    _logsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F9), 
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), 
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('title'),
                    style: const TextStyle(
                      color: Color(0xFF1A237E), 
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t('subtitle'),
                    style: const TextStyle(color: textGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildNotificationSetting(),
                  const SizedBox(height: 20),
                  
                  _buildQuietSetting(),
                  const SizedBox(height: 20),
                  
                  _buildTodayLogs(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationSetting() {
    bool isCustomTime = !([1, 2, 3].contains(_alertHours) && _alertMinutes == 0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Color(0xFF3949AB),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _t('enable_noti'),
                  style: const TextStyle(
                    color: Color(0xFF1A237E), 
                    fontWeight: FontWeight.bold, 
                    fontSize: 16
                  ),
                ),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: const Color(0xFF3949AB),
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Colors.black12),
          ),
          
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _t('freq_title'),
              style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                ...[1, 2, 3].map((hour) {
                  final isSelected = (_alertHours == hour && _alertMinutes == 0);
                  String labelHourText = _selectedLanguage == 'en' && hour > 1 ? '${_t('hour')}s' : _t('hour');
                  return ChoiceChip(
                    label: Text(
                      '$hour $labelHourText',
                      style: TextStyle(
                        color: isSelected ? Colors.white : textGrey,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: _enabled ? (_) {
                      setState(() {
                        _alertHours = hour;
                        _alertMinutes = 0; 
                      });
                    } : null,
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF3949AB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF3949AB) : Colors.black12,
                      ),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                }),
                
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isCustomTime 
                          ? '$_alertHours ${_t('hr')} ${_alertMinutes > 0 ? '$_alertMinutes ${_t('min')}' : ''}'
                          : _t('custom'),
                        style: TextStyle(
                          color: isCustomTime ? Colors.white : textGrey,
                          fontWeight: isCustomTime ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.timer_outlined, size: 16, color: isCustomTime ? Colors.white : textGrey)
                    ],
                  ),
                  selected: isCustomTime,
                  onSelected: _enabled ? (_) {
                    _showIntervalPicker();
                  } : null,
                  backgroundColor: Colors.white,
                  selectedColor: const Color(0xFF3949AB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isCustomTime ? const Color(0xFF3949AB) : Colors.black12,
                    ),
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuietSetting() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('quiet_time'),
            style: const TextStyle(color: Color(0xFF1A237E), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _timeRow(
            title: _t('start'),
            time: _quietStart,
            onTap: () => _pickTime(start: true),
          ),
          const SizedBox(height: 8),
          _timeRow(
            title: _t('end'),
            time: _quietEnd,
            onTap: () => _pickTime(start: false),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3949AB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(_t('save_settings'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeRow({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.access_time, color: Color(0xFF3949AB)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: TextButton(
          onPressed: onTap,
          child: Text(
            formatTOD(time),
            style: const TextStyle(
              color: Color(0xFF1A237E),
              fontWeight: FontWeight.bold, 
              fontSize: 18
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayLogs() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3949AB).withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('today_history'),
            style: const TextStyle(color: Color(0xFF1A237E), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  _t('no_history'),
                  style: const TextStyle(color: textGrey, fontSize: 14),
                ),
              ),
            )
          else
            ..._logs.map((log) {
              // 🌟 แปลภาษาสำหรับรายการประวัติแจ้งเตือน
              String displayMsg = log['message'] ?? '';
              if (displayMsg == 'ถึงเวลาที่ควรดื่มน้ำ' || displayMsg == 'Time to drink water') {
                displayMsg = _t('time_to_drink');
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_none, color: Color(0xFF3949AB), size: 20),
                  ),
                  title: Text(
                    displayMsg,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    log['time'] ?? '',
                    style: const TextStyle(color: textGrey, fontSize: 13),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}