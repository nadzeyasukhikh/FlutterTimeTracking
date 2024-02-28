import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.deepOrange, // Основной цвет (шапка)
        hintColor: Colors.deepOrangeAccent, // Цвет фона
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Time Tracking')),
        body: const TimeTracker(),
      ),
    );
  }
}

class TimeEntry {
  DateTime date;
  double hours;
  String category;

  TimeEntry(this.date, this.hours, this.category);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'hours': hours,
        'category': category,
      };

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      DateTime.parse(json['date']),
      json['hours'].toDouble(),
      json['category'],
    );
  }
}

class TimeTracker extends StatefulWidget {
  const TimeTracker({super.key});

  @override
  State<TimeTracker> createState() => _TimeTrackerState();
}

class _TimeTrackerState extends State<TimeTracker> {
  late DateTime selectedDate;
  DateTime? fromDate;
  DateTime? toDate;
  List<TimeEntry> entries = [];
  final List<String> categories = ["Internship", "Personal", "Studies"];
  final List<String> statisticNames = ["Daily", "Weekly", "Monthly", "Yearly"];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    loadEntries();
  }

  void addOrEditTimeEntry(TimeEntry entry) {
    setState(() {
      entries.removeWhere((e) => isSameDay(e.date, entry.date) && e.category == entry.category);
      entries.add(entry);
    });
    saveEntries();
  }

  void _showAddEditEntryDialog({TimeEntry? editEntry}) {
    double hours = editEntry?.hours ?? 0.0;
    String currentCategory = editEntry?.category ?? categories.first;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String dialogSelectedCategory = currentCategory;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(editEntry == null ? 'Add Time Entry' : 'Edit Time Entry'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DropdownButton<String>(
                      value: dialogSelectedCategory,
                      onChanged: (String? newValue) {
                        setStateDialog(() {
                          dialogSelectedCategory = newValue!;
                        });
                      },
                      items: categories.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    TextField(
                      controller: TextEditingController(text: hours.toString()),
                      decoration: const InputDecoration(labelText: 'Hours'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        hours = double.tryParse(value) ?? 0.0;
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    addOrEditTimeEntry(TimeEntry(selectedDate, hours, dialogSelectedCategory));
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = json.encode(entries.map((entry) => entry.toJson()).toList());
    await prefs.setString('timeEntries', encodedData);
  }

  void loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString('timeEntries');
    if (encodedData != null) {
      final List<dynamic> decodedData = json.decode(encodedData);
      setState(() {
        entries = decodedData.map((entryJson) => TimeEntry.fromJson(entryJson)).toList();
      });
    }
  }

  double _calculateHoursForDay(DateTime date, String category) {
    return entries
        .where((entry) => isSameDay(entry.date, date) && entry.category == category)
        .fold(0.0, (sum, entry) => sum + entry.hours);
  }

  double _calculateHoursForMonth(int year, int month, String category) {
    return entries
        .where((entry) => entry.date.year == year && entry.date.month == month && entry.category == category)
        .fold(0.0, (sum, entry) => sum + entry.hours);
  }

  double _calculateHoursForYear(int year, String category) {
    return entries
        .where((entry) => entry.date.year == year && entry.category == category)
        .fold(0.0, (sum, entry) => sum + entry.hours);
  }

  double _calculateHoursForWeek(DateTime startDate, DateTime endDate, String category) {
    return entries
        .where((entry) =>
            entry.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            entry.date.isBefore(endDate.add(const Duration(days: 1))) &&
            entry.category == category)
        .fold(0.0, (sum, entry) => sum + entry.hours);
  }

  double _calculateTotalHours(String category) {
    if (fromDate == null || toDate == null) {
      return 0.0;
    }

    return entries
        .where((entry) =>
            entry.date.isAfter(fromDate!) &&
            entry.date.isBefore(toDate!.add(const Duration(days: 1))) &&
            entry.category == category)
        .fold(0.0, (sum, entry) => sum + entry.hours);
  }

  Future<void> _showDateRangePicker() async {
    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: fromDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );

    if (pickedStartDate != null) {
      final DateTime? pickedEndDate = await showDatePicker(
        // ignore: use_build_context_synchronously
        context: context,
        initialDate: toDate ?? pickedStartDate,
        firstDate: pickedStartDate,
        lastDate: DateTime(2100),
      );

      if (pickedEndDate != null) {
        setState(() {
          fromDate = pickedStartDate;
          toDate = pickedEndDate;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    Map<String, double> weeklyHoursByCategory = {};
    for (var category in categories) {
      weeklyHoursByCategory[category] = _calculateHoursForDay(selectedDate, category);
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: selectedDate,
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            daysOfWeekVisible: true,
            selectedDayPredicate: (day) => isSameDay(selectedDate, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                selectedDate = selectedDay;
              });
              List<TimeEntry> entriesForSelectedDate =
                  entries.where((entry) => isSameDay(entry.date, selectedDate)).toList();
              TimeEntry? existingEntry = entriesForSelectedDate.isNotEmpty ? entriesForSelectedDate.first : null;
              _showAddEditEntryDialog(editEntry: existingEntry);
            },
            eventLoader: (day) {
              return entries.where((entry) => isSameDay(entry.date, day)).toList();
            },
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatisticContainer(
                        statisticName: statisticNames[0],
                        statisticValue: categories.map((category) =>
                            '${_calculateHoursForDay(selectedDate, category).toStringAsFixed(2)} Hours for $category'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatisticContainer(
                        statisticName: statisticNames[1],
                        statisticValue: categories.map((category) =>
                            '${_calculateHoursForWeek(weekStart, weekEnd, category).toStringAsFixed(2)} Hours for $category'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatisticContainer(
                        statisticName: statisticNames[2],
                        statisticValue: categories.map((category) =>
                            '${_calculateHoursForMonth(selectedDate.year, selectedDate.month, category).toStringAsFixed(2)} Hours for $category'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatisticContainer(
                        statisticName: statisticNames[3],
                        statisticValue: categories.map((category) =>
                            '${_calculateHoursForYear(selectedDate.year, category).toStringAsFixed(2)} Hours for $category'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _showDateRangePicker,
                  child: const Text("Select Date Range"),
                ),
                if (fromDate != null && toDate != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categories
                          .map(
                            (category) => Text(
                              "Total Hours for $category: ${_calculateTotalHours(category).toStringAsFixed(2)}",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticContainer({required String statisticName, required Iterable<String> statisticValue}) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            statisticName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          ...statisticValue.map((value) => Text(
                value,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              )),
        ],
      ),
    );
  }
}
