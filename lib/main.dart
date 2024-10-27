import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather/weather.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ww_weather/appbar.dart';
import 'package:ww_weather/setting.dart';

void main() {
  tz.initializeTimeZones();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  static of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>();
  }
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;
  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = prefs.getBool('isDarkMode') ?? false;
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void changeTheme(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      themeMode: _themeMode,
      theme: ThemeData.light(
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(
        useMaterial3: true,
      ),
      title: 'Weather App',
      home: WeatherScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherController extends GetxController {
  var cityName = ''.obs;
  var weather = Rx<Weather?>(null);
  WeatherFactory wf = WeatherFactory("25ea4ddc425fd290784d241f12f46d46");
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void onInit() {
    super.onInit();
    _speech = stt.SpeechToText();
    debounce(cityName, (String value) {
      if (value.isNotEmpty) {
        getWeather(value);
      } else {
        weather.value = null;
      }
    }, time: const Duration(seconds: 1));
  }

  Future<void> getWeather(String city) async {
    try {
      Weather data = await wf.currentWeatherByCityName(city);
      weather.value = data;
      FocusScope.of(Get.context!).unfocus();
    } catch (e) {
      Get.snackbar('Error', 'City not found or internet issue');
    }
  }

  void listenToSpeech() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        Get.defaultDialog(
          barrierDismissible: false,
          title: "Speak Now",
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic,
                size: 50,
                color: Colors.red,
              ),
              SizedBox(height: 10),
              Text("Speak Now"),
              SizedBox(height: 10),
              CircularProgressIndicator(),
            ],
          ),
        );

        _speech.listen(onResult: (val) {
          cityName.value = val.recognizedWords;
          if (val.finalResult) {
            _stopListening();
          }
        });
        _isListening = true;
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    _speech.stop();
    _isListening = false;
    Get.back();
  }

  Future<String> getTimeZone(String countryCode, String cityName) async {
    try {
      String searchUrl =
          'http://api.geonames.org/searchJSON?q=$cityName&country=$countryCode&maxRows=1&username=gauravpathak207';
      final searchResponse = await http.get(Uri.parse(searchUrl));

      if (searchResponse.statusCode == 200) {
        var searchData = json.decode(searchResponse.body);
        if (searchData['geonames'].isNotEmpty) {
          var latitude = searchData['geonames'][0]['lat'];
          var longitude = searchData['geonames'][0]['lng'];

          String timeZoneUrl =
              'http://api.geonames.org/timezoneJSON?lat=$latitude&lng=$longitude&username=gauravpathak207';
          final timeZoneResponse = await http.get(Uri.parse(timeZoneUrl));

          if (timeZoneResponse.statusCode == 200) {
            var timeZoneData = json.decode(timeZoneResponse.body);
            return timeZoneData['timezoneId'] ?? '';
          }
        }
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<String> getCurrentTime(String countryCode, String cityName) async {
    String timezone = await getTimeZone(countryCode, cityName);

    if (timezone.isEmpty) {
      return 'Timezone not available';
    }

    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);

    return DateFormat('hh:mm a').format(now);
  }
}

class WeatherScreen extends StatelessWidget {
  final WeatherController weatherController = Get.put(WeatherController());

  WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const CustomAppBaar(),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              onChanged: (value) {
                weatherController.cityName.value = value;
              },
              decoration: InputDecoration(
                suffix: InkWell(
                  onTap: weatherController.listenToSpeech,
                  child: Icon(
                    weatherController._isListening ? Icons.mic : Icons.mic_none,
                    size: 30,
                  ),
                ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    )),
                labelText: 'Enter city name',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Obx(() {
                if (weatherController.weather.value == null) {
                  return const Text('Enter a city to get weather information.');
                } else {
                  var weather = weatherController.weather.value!;
                  return ListView(
                    children: [
                      Center(
                        child: FutureBuilder<String>(
                          future: weatherController.getCurrentTime(
                              weather.country!, weather.areaName!),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            } else if (snapshot.hasError ||
                                snapshot.data == null) {
                              return const Text('Error fetching time');
                            } else {
                              return ListTile(
                                leading: const Icon(CupertinoIcons.time,
                                    color: Colors.blueGrey),
                                title: Text(
                                  'City Time: ${snapshot.data}',
                                  style: const TextStyle(fontSize: 20),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      ListTile(
                          leading: const Icon(CupertinoIcons.time,
                              color: Colors.blueGrey),
                          title: Text(
                            'India Time: ${formatTime(DateTime.now())}',
                          )),
                      const Divider(),
                      ListTile(
                        leading: const Icon(CupertinoIcons.globe,
                            color: Colors.blue),
                        title: Text(
                          'Country: ${weather.country ?? 'N/A'}',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(CupertinoIcons.location,
                            color: Colors.red),
                        title: Text('City: ${weather.areaName ?? 'N/A'}',
                            style: const TextStyle(fontSize: 20)),
                      ),
                      ListTile(
                        leading: Icon(CupertinoIcons.thermometer,
                            color: _getTemperatureColor(
                                weather.temperature?.celsius)),
                        title: Text(
                            'Temperature: ${weather.temperature?.celsius?.toStringAsFixed(1) ?? 'N/A'} °C',
                            style: const TextStyle(fontSize: 20)),
                      ),
                      ListTile(
                        leading: Icon(
                          _getWeatherIcon(weather.weatherDescription),
                          color: _getWeatherConditionColor(
                              weather.weatherDescription),
                        ),
                        title: Text(
                            'Weather: ${weather.weatherDescription ?? 'N/A'}',
                            style: const TextStyle(fontSize: 20)),
                      ),
                      ListTile(
                        leading: Icon(CupertinoIcons.drop,
                            color: _getHumidityColor(weather.humidity)),
                        title: Text(
                          'Humidity: ${weather.humidity ?? 'N/A'}%',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(CupertinoIcons.sunrise,
                            color: Colors.orange),
                        title: Text(
                          'Sunrise: ${weather.sunrise != null ? formatTime(weather.sunrise!.toLocal()) : 'N/A'}',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(CupertinoIcons.sunset,
                            color: Colors.red),
                        title: Text(
                          'Sunset: ${weather.sunset != null ? formatTime(weather.sunset!.toLocal()) : 'N/A'}',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(CupertinoIcons.calendar,
                            color: Colors.blue),
                        title: Text(
                          'Date: ${weather.sunset != null ? formatDate(weather.sunset!.toLocal()) : 'N/A'}',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ],
                  );
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  String formatTime(DateTime dateTime) {
    return DateFormat('hh:mm a').format(dateTime);
  }

  String formatDate(DateTime dateTime) {
    return DateFormat('dd-MM-yyyy').format(dateTime);
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return CupertinoIcons.cloud;

    switch (condition.toLowerCase()) {
      case 'clear':
        return CupertinoIcons.sun_max;
      case 'rain':
        return CupertinoIcons.cloud_rain;
      case 'cloudy':
        return CupertinoIcons.cloud;
      case 'storm':
        return CupertinoIcons.cloud_bolt;
      default:
        return CupertinoIcons.cloud;
    }
  }

  Color _getTemperatureColor(double? temp) {
    if (temp == null) return Colors.grey;
    if (temp < 12) {
      return Colors.blue;
    } else if (temp >= 12 && temp <= 25) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Color _getWeatherConditionColor(String? condition) {
    if (condition == null) return Colors.grey;
    switch (condition.toLowerCase()) {
      case 'clear sky':
        return Colors.yellow;
      case 'shower rain':
        return Colors.blue;
      case 'cloudy':
        return Colors.grey;
      case 'storm':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  Color _getHumidityColor(double? humidity) {
    if (humidity == null) return Colors.grey;
    if (humidity < 30) {
      return Colors.red;
    } else if (humidity >= 30 && humidity < 60) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }
}
