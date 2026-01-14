import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class SelectDatePage extends StatefulWidget {
  final String selectedDayOfWeekForSkinBody;
  final Map<String, String> selectedDoctor;
  final String serviceName;
  final String branchName;
  final int sessionsToSelect; // New: Number of sessions user wants to schedule

  const SelectDatePage({
    Key? key,
    required this.selectedDayOfWeekForSkinBody,
    required this.selectedDoctor,
    required this.serviceName,
    required this.branchName,
    required this.sessionsToSelect, // Initialize in constructor
  }) : super(key: key);

  @override
  _SelectDatePageState createState() => _SelectDatePageState();
}

class _SelectDatePageState extends State<SelectDatePage> {
  List<DateTime> _displayAvailableDates = [];
  Map<DateTime, String> _selectedDatesWithTimes = {}; // Stores selected dates and their times

  final Map<String, int> _dayNameToWeekday = {
    'Monday': DateTime.monday,
    'Tuesday': DateTime.tuesday,
    'Wednesday': DateTime.wednesday,
    'Thursday': DateTime.thursday,
    'Friday': DateTime.friday,
    'Saturday': DateTime.saturday,
    'Sunday': DateTime.sunday,
  };

  @override
  void initState() {
    super.initState();
    _populateAvailableDates(); // Generate dates when the page initializes
  }

  // Generates future dates that match the selected day of the week
  void _populateAvailableDates() {
    _displayAvailableDates.clear();
    final int? selectedDayInt = _dayNameToWeekday[widget.selectedDayOfWeekForSkinBody];
    if (selectedDayInt == null) return;

    DateTime currentDate = DateTime.now();
    // Generate dates for approximately the next 6 months
    for (int i = 0; i < 180; i++) {
      final dateToCheck = currentDate.add(Duration(days: i));
      // Ensure it's not a past date (only current or future dates) and matches the preferred day
      if (dateToCheck.weekday == selectedDayInt && dateToCheck.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
        _displayAvailableDates.add(dateToCheck);
      }
    }
  }

  // Generates 40-minute slots from 8 AM to 5 PM
  List<String> _generateFlexibleTimeSlots() {
    List<String> timeSlots = [];
    final DateTime startTime = DateTime(2000, 1, 1, 8, 0); // Start at 8:00 AM
    final DateTime endTime = DateTime(2000, 1, 1, 17, 0); // End at 5:00 PM (exclusive for start time)

    DateTime currentTime = startTime;
    while (currentTime.isBefore(endTime)) {
      final DateTime slotEnd = currentTime.add(const Duration(minutes: 40)); // 30 min session + 10 min grace

      // Ensure the slot doesn't start after or at 5:00 PM
      if (currentTime.hour > endTime.hour || (currentTime.hour == endTime.hour && currentTime.minute >= endTime.minute)) {
        break;
      }

      final String startFormatted = _formatTime(currentTime);
      final String endFormatted = _formatTime(slotEnd); // End can go past 5 PM for the last slot, which is fine
      timeSlots.add("$startFormatted - $endFormatted");
      currentTime = currentTime.add(const Duration(minutes: 40)); // Move to the next slot start
    }
    return timeSlots;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final ampm = hour < 12 ? 'AM' : 'PM';
    final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${formattedHour.toString().padLeft(1, '0')}:${minute.toString().padLeft(2, '0')}$ampm';
  }

  // Function to show time slot selection as a dialog
  Future<String?> _showTimeSlotDialog(BuildContext dialogContext, DateTime date) async {
    List<String> availableTimeSlots = _generateFlexibleTimeSlots(); // Generate time slots

    if (availableTimeSlots.isEmpty) {
      _showAlertDialog(dialogContext, 'No Slots', 'No time slots available for this date.');
      return null;
    }

    final String? selectedSlot = await showDialog<String>(
      context: dialogContext, // Use the provided dialogContext
      builder: (BuildContext innerDialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF394A7F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Select Time Slot for\n${DateFormat('MMMM d, y (EEEE)').format(date)}',
            style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableTimeSlots.map((timeSlot) {
                // Check if this timeSlot is already selected for this date
                bool isSelected = _selectedDatesWithTimes[date] == timeSlot;
                return ListTile(
                  title: Text(
                    timeSlot,
                    style: GoogleFonts.montserrat(
                      color: isSelected ? Colors.lightGreenAccent : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(innerDialogContext, timeSlot); // Return selected time slot
                  },
                );
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: GoogleFonts.montserrat(color: Colors.white70)),
              onPressed: () {
                Navigator.pop(innerDialogContext); // Dismiss dialog without selection
              },
            ),
          ],
        );
      },
    );
    return selectedSlot;
  }

  // Helper function to show a custom alert dialog (replaces alert())
  void _showAlertDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF394A7F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: GoogleFonts.playfairDisplay(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(message, style: GoogleFonts.montserrat(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: Text('OK', style: GoogleFonts.montserrat(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('MMMM d, y (EEEE)');
    bool isConfirmDatesEnabled = _selectedDatesWithTimes.length == widget.sessionsToSelect;

    return Scaffold(
      backgroundColor: const Color(0xFF253660),
      appBar: AppBar(
        title: Text(
          "Select Dates (${_selectedDatesWithTimes.length}/${widget.sessionsToSelect} selected)",
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF253660),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Booking with Doctor: ${widget.selectedDoctor['facilitator_name']}",
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 15),
              _displayAvailableDates.isEmpty
                  ? Center(
                child: Text(
                  'No available ${widget.selectedDayOfWeekForSkinBody}s in the near future.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 16),
                ),
              )
                  : Expanded(
                child: ListView.builder(
                  itemCount: _displayAvailableDates.length,
                  itemBuilder: (context, index) {
                    final date = _displayAvailableDates[index];
                    final bool isSelected = _selectedDatesWithTimes.containsKey(date);
                    final String? selectedTimeForDate = _selectedDatesWithTimes[date];

                    return Card(
                      color: isSelected
                          ? const Color(0xFF4CAF50) // Selected color (green)
                          : const Color(0xFF2D4373), // Default color
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: widget.sessionsToSelect == 1
                          ? InkWell(
                        onTap: () async {
                          final String? timeSlot = await _showTimeSlotDialog(context, date);
                          if (timeSlot != null) {
                            Navigator.pop(context, {date: timeSlot}); // Pop back with single selection
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatter.format(date),
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Doctor: ${widget.selectedDoctor['facilitator_name']}',
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                              if (selectedTimeForDate != null)
                                Text(
                                  'Time: $selectedTimeForDate',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      )
                          : CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: const Color(0xFF5A8DCC),
                        checkColor: Colors.white,
                        title: Text(
                          formatter.format(date),
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor: ${widget.selectedDoctor['facilitator_name']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            if (selectedTimeForDate != null)
                              Text(
                                'Time: $selectedTimeForDate',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        value: isSelected,
                        onChanged: (bool? value) async {
                          if (value == true) {
                            if (_selectedDatesWithTimes.length < widget.sessionsToSelect) {
                              final String? timeSlot = await _showTimeSlotDialog(context, date);
                              if (timeSlot != null) {
                                setState(() {
                                  _selectedDatesWithTimes[date] = timeSlot;
                                });
                              }
                            } else {
                              _showAlertDialog(context, 'Selection Limit', 'You can only select ${widget.sessionsToSelect} dates.');
                            }
                          } else {
                            setState(() {
                              _selectedDatesWithTimes.remove(date);
                            });
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              if (widget.sessionsToSelect > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: isConfirmDatesEnabled
                          ? () {
                        Navigator.pop(context, _selectedDatesWithTimes); // Pop back with all selections
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D5184),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 7,
                        shadowColor: Colors.black.withOpacity(0.4),
                      ),
                      child: Text(
                        isConfirmDatesEnabled
                            ? 'Confirm Dates & Times'
                            : 'Select ${widget.sessionsToSelect - _selectedDatesWithTimes.length} more date(s)',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
