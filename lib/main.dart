import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CityGraph extends StatelessWidget {
  final List<List<double>> coordinates;
  final List<List<int>> tspPath;
  final List<List<int>> connections;
  final double width, height;

  const CityGraph({
    super.key,
    required this.coordinates,
    required this.tspPath,
    required this.connections,
    this.width = 300,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _CityGraphPainter(coordinates, tspPath, connections),
    );
  }
}

class _CityGraphPainter extends CustomPainter {
  final List<List<double>> coordinates;
  final List<List<int>> tspPath;
  final List<List<int>> connections;

  _CityGraphPainter(this.coordinates, this.tspPath, this.connections);

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;
    final paintConnection = Paint()
      ..color = const Color(0xFF4CAF50).withOpacity(0.6)
      ..strokeWidth = 2.5;
    final paintTSP = Paint()
      ..color = const Color(0xFF2196F3)
      ..strokeWidth = 3.5;
    final paintCity = Paint()
      ..color = const Color(0xFFFF5722)
      ..style = PaintingStyle.fill;

    if (coordinates.isEmpty) return;

    double minX = coordinates.map((c) => c[0]).reduce(min);
    double maxX = coordinates.map((c) => c[0]).reduce(max);
    double minY = coordinates.map((c) => c[1]).reduce(min);
    double maxY = coordinates.map((c) => c[1]).reduce(max);

    double scaleX = (size.width - 60) / (maxX - minX + 0.001);
    double scaleY = (size.height - 60) / (maxY - minY + 0.001);

    List<Offset> points = coordinates.map((c) {
      double x = 30 + (c[0] - minX) * scaleX;
      double y = 30 + (c[1] - minY) * scaleY;
      return Offset(x, size.height - y);
    }).toList();

    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        canvas.drawLine(points[i], points[j], paintLine);
      }
    }

    for (var conn in connections) {
      if (conn[0] < points.length && conn[1] < points.length) {
        canvas.drawLine(points[conn[0]], points[conn[1]], paintConnection);
        double dist = sqrt(
            pow(coordinates[conn[0]][0] - coordinates[conn[1]][0], 2) +
                pow(coordinates[conn[0]][1] - coordinates[conn[1]][1], 2));

        final textSpan = TextSpan(
          text: dist.toStringAsFixed(1),
          style: const TextStyle(
            color: Color(0xFF2E7D32),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(
          canvas,
          Offset(
            (points[conn[0]].dx + points[conn[1]].dx) / 2 -
                textPainter.width / 2,
            (points[conn[0]].dy + points[conn[1]].dy) / 2 -
                textPainter.height / 2,
          ),
        );
      }
    }

    
    for (var conn in tspPath) {
      if (conn[0] < points.length && conn[1] < points.length) {
        canvas.drawLine(points[conn[0]], points[conn[1]], paintTSP);
      }
    }

  
    for (int i = 0; i < points.length; i++) {
      // Shadow
      canvas.drawCircle(
        points[i] + const Offset(1, 1),
        6,
        Paint()..color = Colors.black.withOpacity(0.3),
      );
      
      canvas.drawCircle(points[i], 6, paintCity);
      
      canvas.drawCircle(
        points[i],
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

     
      final textSpan = TextSpan(
        text: '$i',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, points[i] + const Offset(8, -8));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
      useMaterial3: true,
    ),
    home: const TSPApp(),
  ));
}

class TSPApp extends StatefulWidget {
  const TSPApp({super.key});

  @override
  State<TSPApp> createState() => _TSPAppState();
}

class _TSPAppState extends State<TSPApp> {
  int nCities = 3;
  List<List<TextEditingController>> coordControllers = [];
  List<List<int>> connections = [];
  List<List<int>>? tspPath;
  List<List<double>>? coords;
  double? cost;
  String? message;
  bool isLoading = false;

  final TextEditingController _fromCityController = TextEditingController();
  final TextEditingController _toCityController = TextEditingController();
  final TextEditingController _nCitiesController =
      TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    coordControllers = List.generate(nCities, (i) {
      return [TextEditingController(), TextEditingController()];
    });
    connections.clear();
  }

  String getBackendUrl() {
    if (kIsWeb) return "https://tsp-backend-yr3m.onrender.com/tsp";
    return "https://tsp-backend-yr3m.onrender.com/tsp";
  }

  void _addConnection() {
    int? from = int.tryParse(_fromCityController.text);
    int? to = int.tryParse(_toCityController.text);

    if (from == null || to == null) {
      setState(() {
        message = "Please enter valid city numbers";
      });
      return;
    }

    if (from < 0 || from >= nCities || to < 0 || to >= nCities) {
      setState(() {
        message = "City numbers must be between 0 and ${nCities - 1}";
      });
      return;
    }

    if (from == to) {
      setState(() {
        message = "Cities must be different";
      });
      return;
    }

    bool exists = connections.any((conn) =>
        (conn[0] == from && conn[1] == to) ||
        (conn[0] == to && conn[1] == from));

    if (exists) {
      setState(() {
        message = "Connection already exists";
      });
      return;
    }

    setState(() {
      connections.add([from, to]);
      message = null;
      _fromCityController.clear();
      _toCityController.clear();
    });
  }

  void _removeConnection(int index) {
    setState(() {
      connections.removeAt(index);
    });
  }

  Future<void> _calculateTSP() async {
    setState(() {
      isLoading = true;
      message = null;
    });

    coords = coordControllers
        .map((c) =>
            [double.tryParse(c[0].text) ?? 0, double.tryParse(c[1].text) ?? 0])
        .toList();

    final body = {
      "n": nCities,
      "coordinates": coords,
      "connections": connections
    };

    try {
      final url = Uri.parse(getBackendUrl());
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<int> path = List<int>.from(data["path"]);
        setState(() {
          tspPath = [
            for (int i = 0; i < path.length - 1; i++) [path[i], path[i + 1]],
            [path.last, path[0]]
          ];
          cost = data["cost"];
          message = null;
          isLoading = false;
        });
      } else {
        setState(() {
          message = "Server error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        message = "Network error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = min(800.0, screenWidth - 40);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "TSP Visualizer",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Input Section Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Number of cities
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.location_city,
                                  color: Color(0xFF2196F3)),
                              const SizedBox(width: 12),
                              const Text(
                                "Number of Cities:",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 70,
                                child: TextField(
                                  controller: _nCitiesController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                  ),
                                  onChanged: (v) {
                                    int newValue = int.tryParse(v) ?? 3;
                                    if (newValue > 0) {
                                      setState(() {
                                        nCities = newValue;
                                        _initControllers();
                                        tspPath = null;
                                        coords = null;
                                        cost = null;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // City coordinates
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "📍 City Coordinates",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: nCities,
                          itemBuilder: (context, i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5722),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$i',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: coordControllers[i]
                                                  [0],
                                              decoration: InputDecoration(
                                                labelText: "X",
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: coordControllers[i]
                                                  [1],
                                              decoration: InputDecoration(
                                                labelText: "Y",
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                              ),
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                  
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "🔗 City Connections",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: _fromCityController,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        labelText: "From",
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Icon(Icons.arrow_forward,
                                        color: Color(0xFF4CAF50)),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: TextField(
                                      controller: _toCityController,
                                      textAlign: TextAlign.center,
                                      decoration: InputDecoration(
                                        labelText: "To",
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: _addConnection,
                                    icon: const Icon(Icons.add),
                                    label: const Text("Add"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              if (connections.isEmpty)
                                const Text(
                                  "ℹ️ No connections defined (all cities are connected)",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children:
                                      connections.asMap().entries.map((entry) {
                                    int idx = entry.key;
                                    var conn = entry.value;
                                    return Chip(
                                      label: Text(
                                        "${conn[0]} ↔ ${conn[1]}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: Colors.white,
                                      deleteIcon:
                                          const Icon(Icons.close, size: 18),
                                      onDeleted: () => _removeConnection(idx),
                                      side:
                                          BorderSide(color: Colors.green[300]!),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                       
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _calculateTSP,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.route, size: 24),
                            label: Text(
                              isLoading ? "Calculating..." : "Calculate TSP",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2196F3),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                
                if (message != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border.all(color: Colors.red[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message!,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                
                if (coords != null && tspPath != null) ...[
                  const SizedBox(height: 20),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Text(
                            "🎯 TSP Solution",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Graph
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: CityGraph(
                              coordinates: coords!,
                              tspPath: tspPath!,
                              connections: connections,
                              width: maxWidth - 112,
                              height: 400,
                            ),
                          ),
                          const SizedBox(height: 24),

                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2196F3).withOpacity(0.1),
                                  const Color(0xFF64B5F6).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.attach_money,
                                        color: Color(0xFF2196F3)),
                                    const SizedBox(width: 8),
                                    const Text(
                                      "Total Cost:",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      cost!.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2196F3),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.route,
                                        color: Color(0xFF2196F3)),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Path:",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "${tspPath!.map((e) => e[0]).join(" → ")} → ${tspPath![0][0]}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1976D2),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.straighten,
                                        color: Color(0xFF2196F3), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Distance Breakdown:",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...tspPath!.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  var conn = entry.value;
                                  double dist = sqrt(pow(
                                          coords![conn[0]][0] -
                                              coords![conn[1]][0],
                                          2) +
                                      pow(
                                          coords![conn[0]][1] -
                                              coords![conn[1]][1],
                                          2));
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2196F3)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${idx + 1}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2196F3),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Text(
                                                'City ${conn[0]}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(Icons.arrow_forward,
                                                  size: 16, color: Colors.grey),
                                              const SizedBox(width: 8),
                                              Text(
                                                'City ${conn[1]}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4CAF50)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            dist.toStringAsFixed(2),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2E7D32),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Legend:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildLegendItem(
                                  Colors.grey.withOpacity(0.2),
                                  "All possible connections",
                                ),
                                const SizedBox(height: 8),
                                _buildLegendItem(
                                  const Color(0xFF4CAF50).withOpacity(0.6),
                                  "User-defined connections",
                                ),
                                const SizedBox(height: 8),
                                _buildLegendItem(
                                  const Color(0xFF2196F3),
                                  "TSP solution path",
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  @override
  void dispose() {
    for (var controllers in coordControllers) {
      for (var controller in controllers) {
        controller.dispose();
      }
    }
    _fromCityController.dispose();
    _toCityController.dispose();
    _nCitiesController.dispose();
    super.dispose();
  }
}
