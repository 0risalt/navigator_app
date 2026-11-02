import 'dart:convert';
import 'dart:core';
import 'dart:core' as core;

import 'package:flutter/material.dart' hide Icon, TextStyle;
import 'package:flutter/material.dart' as material show Icon, Icons, TextStyle, Text;

import 'package:yandex_maps_mapkit/init.dart' as init;
import 'package:yandex_maps_mapkit/mapkit.dart' hide Uri;
import 'package:yandex_maps_mapkit/mapkit_factory.dart';
import 'package:yandex_maps_mapkit/image.dart' as image_provider;
import 'package:yandex_maps_mapkit/yandex_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../assets/map_style.dart';
import '../services/supabase_service.dart';

class HomeScreenAndroid extends StatefulWidget {
  const HomeScreenAndroid({super.key});

  @override
  State<HomeScreenAndroid> createState() => _HomeScreenAndroidState();
}

class _HomeScreenAndroidState extends State<HomeScreenAndroid> {
  final String _apiKey = '673d50b7-d921-4885-9b09-6bfe856d3a0d';
  final String _geocoderApiKey = 'e7f31599-4b12-4ff7-b616-25635e6ae8db';
  final String _suggestApiKey = '2f505185-7be6-4da5-b2e8-cc4fc964051b';

  final SupabaseService _supabaseService = SupabaseService();

  Map? _map;
  MapWindow? _mapWindow;
  TrafficLayer? _trafficLayer;
  bool _isReady = false;
  bool _isTrafficOn = false;

  Point? _currentPosition;
  Point? _startPoint;
  Point? _destination;
  String? _destinationAddress;
  String? _startAddress;
  final List<Point> _waypoints = [];
  final List<PlacemarkMapObject> _waypointMarkers = [];

  double? _routeDistance;
  double? _routeDuration;

  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _suggestions = [];
  bool _isLoadingSuggestions = false;
  bool _searchOrganizations = false;

  String? _editingPointType; // 'start', 'destination', 'waypoint'
  int? _editingWaypointIndex;

  PlacemarkMapObject? _destinationMarker;
  PlacemarkMapObject? _currentLocationMarker;
  PlacemarkMapObject? _startMarker;
  PolylineMapObject? _routePolyline;

  // Закладки и История
  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _homePointData;
  Map<String, dynamic>? _workPointData;

  late final image_provider.ImageProvider _pinkMarkerIcon;

  @override
  void initState() {
    super.initState();
    _pinkMarkerIcon = image_provider.ImageProvider.fromImageProvider(
      const AssetImage('assets/images/pink_marker.png'),
    );
    
    init.initMapkit(apiKey: _apiKey);
    _determinePosition();
    _loadDataFromSupabase();
  }

  Future<void> _loadDataFromSupabase() async {
    try {
      final bookmarks = await _supabaseService.getBookmarks();
      final history = await _supabaseService.getHistory();
      final home = await _supabaseService.getPlace('home');
      final work = await _supabaseService.getPlace('work');
      
      setState(() {
        _bookmarks = bookmarks;
        _history = history;
        _homePointData = home;
        _workPointData = work;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки из Supabase: $e');
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = Point(latitude: position.latitude, longitude: position.longitude);
      });
      _map?.move(CameraPosition(_currentPosition!, zoom: 15.0, azimuth: 0.0, tilt: 0.0));
      _addCurrentLocationMarker(_currentPosition!);
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _onMapCreated(MapWindow mapWindow) {
    _mapWindow = mapWindow;
    _map = mapWindow.map;
    _map?.setMapStyle(pinkMapStyle);
    try {
      _trafficLayer = mapkit.createTrafficLayer(mapWindow)..setTrafficVisible(false);
    } catch (e) {
      debugPrint('Failed to create traffic layer: $e');
    }
    final start = _currentPosition ?? const Point(latitude: 55.755864, longitude: 37.617698);
    _map?.move(CameraPosition(start, zoom: 12.0, azimuth: 0.0, tilt: 0.0));
    _map?.addTapListener(_MapTapListener((point) {
      _handleMapTap(point);
    }));
    setState(() => _isReady = true);
  }

  Future<void> _handleMapTap(Point point) async {
    if (_editingPointType == null) {
      _editingPointType = 'destination';
    }
    if (_editingPointType == 'start' && _startMarker != null) {
      _map?.mapObjects.remove(_startMarker!);
    } else if (_editingPointType == 'destination' && _destinationMarker != null) {
      _map?.mapObjects.remove(_destinationMarker!);
    }

    final marker = _map?.mapObjects.addPlacemark();
    if (marker != null) {
      marker.geometry = point;
      marker.setIcon(_pinkMarkerIcon);
      marker.setIconStyle(const IconStyle(scale: 0.5));
    }

    String address = 'Определение...';
    setState(() {
      if (_editingPointType == 'start') {
        _startPoint = point;
        _startAddress = address;
        _startMarker = marker;
      } else if (_editingPointType == 'destination') {
        _destination = point;
        _destinationAddress = address;
        _destinationMarker = marker;
      }
    });

    try {
      final url = 'https://geocode-maps.yandex.ru/1.x/?apikey=$_geocoderApiKey&geocode=${point.longitude},${point.latitude}&format=json&results=1';
      final response = await http.get(core.Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final members = data['response']['GeoObjectCollection']['featureMember'];
        if (members != null && members.isNotEmpty) {
          address = members[0]['GeoObject']['metaDataProperty']['GeocoderMetaData']['text'];
        }
      }
    } catch (e) {
      address = 'Ошибка';
    }

    setState(() {
      if (_editingPointType == 'start') {
        _startAddress = address;
      } else if (_editingPointType == 'destination') {
        _destinationAddress = address;
      }
    });

    _editingPointType = null;
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _isLoadingSuggestions = true);
    try {
      final params = <String, String>{
        'apikey': _suggestApiKey,
        'text': query,
        'lang': 'ru_RU',
        'type': _searchOrganizations ? 'biz' : 'geo',
      };
      if (_currentPosition != null) {
        params['ll'] = '${_currentPosition!.longitude},${_currentPosition!.latitude}';
        params['spn'] = '0.5,0.5';
      }
      final url = core.Uri.https('suggest-maps.yandex.ru', '/v1/suggest', params);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _suggestions = data['results'] ?? []);
      }
    } catch (e) {
      debugPrint('Suggest error: $e');
    } finally {
      setState(() => _isLoadingSuggestions = false);
    }
  }

  Future<void> _onSuggestionSelected(dynamic item) async {
    final String display = item['title']['text'] ?? '';
    _searchController.text = display;
    setState(() => _suggestions = []);

    try {
      final url = 'https://geocode-maps.yandex.ru/1.x/?apikey=$_geocoderApiKey&geocode=$display&format=json&results=1';
      final response = await http.get(core.Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final members = data['response']['GeoObjectCollection']['featureMember'];
        if (members != null && members.isNotEmpty) {
          final pos = members[0]['GeoObject']['Point']['pos'].split(' ');
          final lon = double.parse(pos[0]);
          final lat = double.parse(pos[1]);
          final point = Point(latitude: lat, longitude: lon);
          _applySelectedPoint(point, display);
        }
      }
    } catch (e) {
      debugPrint('Geocode error: $e');
    }
  }

  void _applySelectedPoint(Point point, String address) {
    setState(() {
      if (_editingPointType == 'start') {
        _startPoint = point;
        _startAddress = address;
        if (_startMarker != null) _map?.mapObjects.remove(_startMarker!);
        final marker = _map?.mapObjects.addPlacemark()
          ..geometry = point
          ..setIcon(_pinkMarkerIcon)
          ..setIconStyle(const IconStyle(scale: 0.5));
        _startMarker = marker;
      } else if (_editingPointType == 'destination') {
        _destination = point;
        _destinationAddress = address;
        if (_destinationMarker != null) _map?.mapObjects.remove(_destinationMarker!);
        final marker = _map?.mapObjects.addPlacemark()
          ..geometry = point
          ..setIcon(_pinkMarkerIcon)
          ..setIconStyle(const IconStyle(scale: 0.5));
        _destinationMarker = marker;
      } else if (_editingPointType == 'waypoint' && _editingWaypointIndex != null) {
        _waypoints[_editingWaypointIndex!] = point;
        for (var m in _waypointMarkers) {
          _map?.mapObjects.remove(m);
        }
        _waypointMarkers.clear();
        for (var wp in _waypoints) {
          final m = _map?.mapObjects.addPlacemark()
            ..geometry = wp
            ..setIcon(_pinkMarkerIcon)
            ..setIconStyle(const IconStyle(scale: 0.5));
          if (m != null) _waypointMarkers.add(m);
        }
      }
    });
    _map?.move(CameraPosition(point, zoom: 16.0, azimuth: 0.0, tilt: 0.0));
    _editingPointType = null;
    _editingWaypointIndex = null;
  }

  void _editStart() {
    _editingPointType = 'start';
    _searchController.clear();
    _suggestions = [];
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _editDestination() {
    _editingPointType = 'destination';
    _searchController.clear();
    _suggestions = [];
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _editWaypoint(int index) {
    _editingPointType = 'waypoint';
    _editingWaypointIndex = index;
    _searchController.clear();
    _suggestions = [];
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _addWaypoint() {
    setState(() {
      _waypoints.add(Point(latitude: 0, longitude: 0));
    });
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints.removeAt(index);
      _map?.mapObjects.remove(_waypointMarkers[index]);
      _waypointMarkers.removeAt(index);
    });
  }

  Future<void> _buildRoute() async {
    final start = _startPoint ?? _currentPosition;
    final end = _destination;

    if (start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Нужна начальная и конечная точка')));
      return;
    }

    setState(() {
      _routeDistance = null;
      _routeDuration = null;
    });

    if (_routePolyline != null) _map?.mapObjects.remove(_routePolyline!);

    try {
      final points = ['${start.longitude},${start.latitude}'];
      for (var wp in _waypoints) {
        if (wp.latitude != 0 && wp.longitude != 0) {
          points.add('${wp.longitude},${wp.latitude}');
        }
      }
      points.add('${end.longitude},${end.latitude}');

      final url = 'https://router.project-osrm.org/route/v1/driving/${points.join(';')}?overview=full&geometries=geojson';
      final response = await http.get(core.Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry']['coordinates'] as List;
          final List<Point> routePoints = [];
          for (var coord in geometry) {
            routePoints.add(Point(latitude: coord[1] as double, longitude: coord[0] as double));
          }

          setState(() {
            _routeDistance = (route['distance'] as num).toDouble();
            _routeDuration = (route['duration'] as num).toDouble();
          });

          final polyline = _map?.mapObjects.addPolyline();
          if (polyline != null) {
            polyline.geometry = Polyline(routePoints);
            polyline.setStrokeColor(const Color(0xFFFF4081));
            polyline.strokeWidth = 6.0;
            _routePolyline = polyline;
          }

          // СОХРАНЯЕМ В ИСТОРИЮ
          if (_destinationAddress != null && _destination != null) {
            await _supabaseService.savePlace(
              address: _destinationAddress!,
              lat: _destination!.latitude,
              lon: _destination!.longitude,
              type: 'history',
            );
            _loadDataFromSupabase(); // Обновляем историю
          }
        }
      }
    } catch (e) {
      debugPrint('OSRM route error: $e');
    }
  }

  void _saveHome() async {
    if (_destination != null && _destinationAddress != null) {
      await _supabaseService.savePlace(
        address: _destinationAddress!,
        lat: _destination!.latitude,
        lon: _destination!.longitude,
        type: 'home',
      );
      setState(() => _homePointData = {
        'address': _destinationAddress,
        'latitude': _destination!.latitude,
        'longitude': _destination!.longitude,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Дом сохранен')));
    }
  }

  void _saveWork() async {
    if (_destination != null && _destinationAddress != null) {
      await _supabaseService.savePlace(
        address: _destinationAddress!,
        lat: _destination!.latitude,
        lon: _destination!.longitude,
        type: 'work',
      );
      setState(() => _workPointData = {
        'address': _destinationAddress,
        'latitude': _destination!.latitude,
        'longitude': _destination!.longitude,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Работа сохранена')));
    }
  }

  Future<void> _addCurrentLocationMarker(Point point) async {
    if (_currentLocationMarker != null) _map?.mapObjects.remove(_currentLocationMarker!);
    final marker = _map?.mapObjects.addPlacemark();
    if (marker != null) {
      marker.geometry = point;
      marker.setIcon(_pinkMarkerIcon);
      marker.setIconStyle(const IconStyle(scale: 0.5));
      _currentLocationMarker = marker;
    }
  }

  void _addBookmark() async {
    if (_destination != null && _destinationAddress != null) {
      await _supabaseService.savePlace(
        address: _destinationAddress!,
        lat: _destination!.latitude,
        lon: _destination!.longitude,
        type: 'bookmark',
      );
      _loadDataFromSupabase();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавлено в закладки')));
    }
  }

  void _toggleTraffic() {
    setState(() => _isTrafficOn = !_isTrafficOn);
    try {
      _trafficLayer?.setTrafficVisible(_isTrafficOn);
    } catch (e) {
      debugPrint('Failed to toggle traffic: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF4081))));
    }

    return Scaffold(
      body: Stack(
        children: [
          YandexMap(onMapCreated: _onMapCreated),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                children: [
                  if (_editingPointType != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4081),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _editingPointType == 'start' ? 'Изменение начала' : _editingPointType == 'destination' ? 'Изменение конца' : 'Изменение промежуточной',
                            style: const TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 18),
                            onPressed: () => setState(() => _editingPointType = null),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.2), blurRadius: 10)],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: _editingPointType == null 
                            ? 'Поиск адреса или клик по карте' 
                            : 'Введите адрес для изменения...',
                        prefixIcon: const material.Icon(material.Icons.search, color: Color(0xFFFF4081)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        suffixIcon: _isLoadingSuggestions
                            ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                icon: material.Icon(_searchOrganizations ? material.Icons.business : material.Icons.location_on, color: const Color(0xFFFF4081)),
                                onPressed: () => setState(() => _searchOrganizations = !_searchOrganizations),
                              ),
                      ),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 250),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          return ListTile(
                            leading: material.Icon(material.Icons.location_on, color: const Color(0xFFFF4081)),
                            title: material.Text(item['title']['text'] ?? ''),
                            onTap: () => _onSuggestionSelected(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 320,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'traffic', mini: true,
                  backgroundColor: _isTrafficOn ? const Color(0xFFFF4081) : Colors.white,
                  foregroundColor: _isTrafficOn ? Colors.white : const Color(0xFFFF4081),
                  onPressed: _toggleTraffic,
                  child: const material.Icon(material.Icons.traffic),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'myLocation', mini: true,
                  backgroundColor: Colors.white, foregroundColor: const Color(0xFFFF4081),
                  onPressed: _determinePosition,
                  child: const material.Icon(material.Icons.my_location),
                ),
                if (_destination != null && _destinationAddress != null) ...[
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'bookmark', mini: true,
                    backgroundColor: Colors.white, foregroundColor: const Color(0xFFFF4081),
                    onPressed: _addBookmark,
                    child: const material.Icon(material.Icons.star),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton(
                    heroTag: 'waypoint', mini: true,
                    backgroundColor: Colors.white, foregroundColor: const Color(0xFFFF4081),
                    onPressed: _addWaypoint,
                    child: const material.Icon(material.Icons.add_location_alt),
                  ),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 320,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: DefaultTabController(
                length: 4, // <-- ТЕПЕРЬ 4 ВКЛАДКИ
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Color(0xFFFF4081),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFFFF4081),
                      isScrollable: true,
                      tabs: [
                        Tab(icon: material.Icon(material.Icons.route), text: 'Маршрут'),
                        Tab(icon: material.Icon(material.Icons.star), text: 'Избранное'),
                        Tab(icon: material.Icon(material.Icons.history), text: 'История'),
                        Tab(icon: material.Icon(material.Icons.home), text: 'Дом/Работа'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildRouteTab(),
                          _buildBookmarksTab(),
                          _buildHistoryTab(), // <-- НОВАЯ ВКЛАДКА
                          _buildHomeWorkTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ... (Метод _buildRouteTab и _buildPointRow остаются как в предыдущем коде) ...
  Widget _buildRouteTab() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPointRow(
            icon: Icons.my_location,
            label: 'Начало',
            address: _startPoint != null ? _startAddress ?? '' : 'Мое местоположение',
            onEdit: _editStart,
          ),
          ..._waypoints.asMap().entries.map((entry) {
            final index = entry.key;
            return _buildPointRow(
              icon: Icons.add_location_alt,
              label: 'Промежуточная ${index + 1}',
              address: 'Нажмите для выбора',
              onEdit: () => _editWaypoint(index),
              onDelete: () => _removeWaypoint(index),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TextButton.icon(
              onPressed: _addWaypoint,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить точку', style: TextStyle(fontSize: 12)),
            ),
          ),
          _buildPointRow(
            icon: Icons.location_on,
            label: 'Конец',
            address: _destinationAddress ?? 'Выберите на карте или в поиске',
            onEdit: _editDestination,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_destination != null) ? _buildRoute : null,
              icon: const Icon(Icons.navigation),
              label: const Text('Построить маршрут'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointRow({
    required IconData icon,
    required String label,
    required String address,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.pink.shade100),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFFF4081)),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFFFF4081), size: 20),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  // ОБНОВЛЕННАЯ ВКЛАДКА ИЗБРАННОГО (с удалением)
  Widget _buildBookmarksTab() {
    return _bookmarks.isEmpty
        ? const Center(child: material.Text('Нет избранных мест'))
        : ListView.builder(
            itemCount: _bookmarks.length,
            itemBuilder: (context, index) {
              final b = _bookmarks[index];
              return ListTile(
                leading: const material.Icon(material.Icons.star, color: Color(0xFFFF4081)),
                title: material.Text(b['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () {
                  final lat = b['latitude'] as double;
                  final lon = b['longitude'] as double;
                  final point = Point(latitude: lat, longitude: lon);
                  setState(() {
                    _destination = point;
                    _destinationAddress = b['address'];
                  });
                  _map?.move(CameraPosition(point, zoom: 16.0, azimuth: 0.0, tilt: 0.0));
                },
                trailing: IconButton(
                  icon: const material.Icon(material.Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    await _supabaseService.deleteItem(b['id'] as int);
                    _loadDataFromSupabase();
                  },
                ),
              );
            },
          );
  }

  // НОВАЯ ВКЛАДКА ИСТОРИИ (с удалением)
  Widget _buildHistoryTab() {
    return _history.isEmpty
        ? const Center(child: material.Text('История пуста'))
        : ListView.builder(
            itemCount: _history.length,
            itemBuilder: (context, index) {
              final h = _history[index];
              return ListTile(
                leading: const material.Icon(material.Icons.history, color: Colors.grey),
                title: material.Text(h['address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: const Text('Последний маршрут', style: TextStyle(fontSize: 10)),
                onTap: () {
                  final lat = h['latitude'] as double;
                  final lon = h['longitude'] as double;
                  final point = Point(latitude: lat, longitude: lon);
                  setState(() {
                    _destination = point;
                    _destinationAddress = h['address'];
                  });
                  _map?.move(CameraPosition(point, zoom: 16.0, azimuth: 0.0, tilt: 0.0));
                },
                trailing: IconButton(
                  icon: const material.Icon(material.Icons.delete, color: Colors.grey),
                  onPressed: () async {
                    await _supabaseService.deleteItem(h['id'] as int);
                    _loadDataFromSupabase();
                  },
                ),
              );
            },
          );
  }

  // ... (Метод _buildHomeWorkTab без изменений) ...
  Widget _buildHomeWorkTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(onPressed: _saveHome, icon: const material.Icon(material.Icons.home), label: const material.Text('Сохранить Дом')),
            ElevatedButton.icon(onPressed: _saveWork, icon: const material.Icon(material.Icons.work), label: const material.Text('Сохранить Работу')),
          ],
        ),
        const SizedBox(height: 16),
        if (_homePointData != null)
          ListTile(
            leading: const material.Icon(material.Icons.home, color: Color(0xFFFF4081)),
            title: const material.Text('Домой'),
            onTap: () {
              final lat = _homePointData!['latitude'] as double;
              final lon = _homePointData!['longitude'] as double;
              _buildRoute(customStart: _currentPosition, customEnd: Point(latitude: lat, longitude: lon)); // Напрямую
            },
          ),
        if (_workPointData != null)
          ListTile(
            leading: const material.Icon(material.Icons.work, color: Color(0xFFFF4081)),
            title: const material.Text('На работу'),
            onTap: () {
              final lat = _workPointData!['latitude'] as double;
              final lon = _workPointData!['longitude'] as double;
              _buildRoute(customStart: _currentPosition, customEnd: Point(latitude: lat, longitude: lon));
            },
          ),
      ],
    );
  }
}

class Bookmark {
  final String address;
  final Point point;
  Bookmark({required this.address, required this.point});
}

class _MapTapListener implements LayersGeoObjectTapListener {
  final Function(Point) onTap;
  _MapTapListener(this.onTap);

  @override
  bool onObjectTap(GeoObjectTapEvent event) {
    return true;
  }
}