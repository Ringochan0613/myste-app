import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        fontFamily: 'MPlus',
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final random = Random();
  List<Map<String, dynamic>> parameters = [];
  int todayCount = 0;
  String todayKey = "";
  Color bgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  String getTodayKey() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
     todayKey = getTodayKey();

    // 回数管理
    final savedDate = prefs.getString('date') ?? "";
    final count = prefs.getInt('count') ?? 0;
    if (savedDate == todayKey) {
      todayCount = count;
      // todayCount = 0;
    } else {
      todayCount = 0;
    }

    // パラメータ読み込み
    final saved = prefs.getString('params');

    if (saved != null) {
      parameters = List<Map<String, dynamic>>.from(jsonDecode(saved));
    } else {
      parameters = [
        {'name': '仕事', 'value': 0},
        {'name': '勉強', 'value': 0},
        {'name': '運動', 'value': 0},
      ];
    }

    final colorValue = prefs.getInt('bgColor') ?? Colors.white.value;
    bgColor = Color(colorValue);

    setState(() {});
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('params', jsonEncode(parameters));
    await prefs.setString('date', todayKey);
    await prefs.setInt('count', todayCount);
    await prefs.setInt('bgColor', bgColor.value);
  }

  void increaseParam(int index) {
    if (todayCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今日はもう5回実行済み！')),
      );
      return;
    }

    int add = [2, 2, 3, 3, 3, 4, 4, 5, 6][random.nextInt(9)];

    setState(() {
      parameters[index]['value'] += add;
      if (parameters[index]['value'] > 250) {
        parameters[index]['value'] = 250;
      }
      todayCount++;

      floatingTexts[index] = add; // ←追加🔥
    });

    saveData();

    // 1.2秒後に消す
    Future.delayed(const Duration(milliseconds: 1200), () {
      setState(() {
        floatingTexts.remove(index);
      });
    });
  }

  void addParameter() async {
    if (parameters.length >= 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パラメータは最大8個まで!'))
      );
      return;
    }

    String input = "";

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("パラメータ名入力"),
          content: TextField(
            onChanged: (value) => input = value,
            decoration: const InputDecoration(hintText: "例：運動"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (input.isEmpty) return;

    setState(() {
      parameters.add({
        'name': input,
        'value': 0,
      });
    });

    saveData();
  }

  void selectDeleteParameter() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("削除する項目を選択"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(parameters.length, (index) {
              return ListTile(
                title: Text(parameters[index]['name']),
                onTap: () {
                  Navigator.pop(context);
                  confirmDelete(index);
                },
              );
            }),
          ),
        );
      },
    );
  }

  void confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("本当に削除？"),
          content: Text(parameters[index]['name']),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  parameters.removeAt(index);
                });
                saveData();
                Navigator.pop(context);
              },
              child: const Text("削除"),
            ),
          ],
        );
      },
    );
  }

  void openSettings() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("背景色変更"),
          content: SizedBox(
            width: 200,
            child: GridView.count(
              crossAxisCount: 4, // ←4×4🔥
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: colorList.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      bgColor = color;
                    });
                    saveData();
                    Navigator.pop(context);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _colorButton(Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          bgColor = color;
        });
        saveData();
        Navigator.pop(context);
      },
      child: Container(
        width: 40,
        height: 40,
        color: color,
      ),
    );
  }

  Widget _imageButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        'assets/images/button.png',
        width: 40,
        height: 40,
      ),
    );
  }

  Map<int,int> floatingTexts = {};

  final List<Color> colorList = [
  Colors.white,
  Colors.pink.shade100,
  Colors.red.shade100,
  Colors.orange.shade100,

  Colors.yellow.shade100,
  Colors.green.shade100,
  Colors.teal.shade100,
  Colors.blue.shade100,

  Colors.indigo.shade100,
  Colors.purple.shade100,
  Colors.brown.shade100,
  Colors.grey.shade300,

  Colors.cyan.shade100,
  Colors.lime.shade100,
  Colors.amber.shade100,
  Colors.deepOrange.shade100,
  ];
  
  int getWeightedValue(String type) {
    final rand = random.nextDouble();

    if (type == "good") {
      if (rand < 0.2) return 6;
      if (rand < 0.7) return 5;
      return 4;
    }

    if (type == "normal") {
      if (rand < 0.2) return 5;
      if (rand < 0.7) return 4;
      return 3;
    }

    if (type == "bad") {
      if (rand < 0.2) return 4;
      if (rand < 0.7) return 3;
      return 2;
    }

    return 3;
  }

  void increaseParamWithResult(int index, String type) {
    int add = getWeightedValue(type);

    setState(() {
      parameters[index]['value'] += add;

      if (parameters[index]['value'] > 250) {
        parameters[index]['value'] = 250;
      }
      if (todayCount < 5) {
        todayCount++;
      }
      // +演出
      floatingTexts[index] = add;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        floatingTexts.remove(index);
      });
    });

    saveData();
  }
    
  void showResultDialog(int index) {
  if (todayCount >= 5) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今日はもう5回実行済み！')),
    );
    return;
  }

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("出来栄えを選択"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            /// 良い
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                increaseParamWithResult(index, "good");
              },
              child: Image.asset(
                'assets/images/good.png',
                height: 60,
              ),
            ),

            const SizedBox(height: 10),

            /// 普通
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                increaseParamWithResult(index, "normal");
              },
              child: Image.asset(
                'assets/images/normal.png',
                height: 60,
              ),
            ),

            const SizedBox(height: 10),

            /// 悪い
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                increaseParamWithResult(index, "bad");
              },
              child: Image.asset(
                'assets/images/bad.png',
                height: 60,
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("戻る"),
            ),
          ],
        ),
      );
    },
  );
}

  void resetParameters() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("本当にリセット？"),
          content: const Text("すべてのパラメータが0になります"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  for (var p in parameters) {
                    p['value'] = 0;
                  }
                });
                saveData();
                Navigator.pop(context);
              },
              child: const Text("リセット"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: openSettings,
          ),
        ],
      ),

      body: SafeArea(
        child: Container(
          color:bgColor,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              /// 日付
              Text(
                "${now.month}月 ${now.day}日",
                style: const TextStyle(fontSize: 20),
              ),

              const SizedBox(height: 16),

              /// パラメータ一覧
              Expanded(
                child: Column(
                  children: List.generate(8, (index) {
                    if (index >= parameters.length) {
                      // 空白（パラメータが少ない時）
                      return const Expanded(child: SizedBox());
                    }

                    final p = parameters[index];

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: GestureDetector(
                          onTap: () => showResultDialog(index),
                          child: Stack(
                            children: [

                              /// 背景
                              Image.asset(
                                'assets/images/para.png',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.fill,
                              ),

                              /// 名前
                              Positioned(
                                left: 12,
                                top: 10,
                                child: Text(p['name']),
                              ),

                              /// 数値
                              Positioned(
                                right: 12,
                                top: 10,
                                child: Text("${p['value']}"),
                              ),

                              /// +演出
                              if (floatingTexts.containsKey(index))
                                Positioned(
                                  right: 60,
                                  top: 0,
                                  child: TweenAnimationBuilder(
                                    tween: Tween(begin: 0.0, end: -20.0),
                                    duration: const Duration(milliseconds: 800),
                                    builder: (context, value, child) {
                                      return Transform.translate(
                                        offset: Offset(0, value),
                                        child: Opacity(
                                          opacity: 1 - (value.abs() / 20),
                                          child: Text(
                                            "+${floatingTexts[index]}",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              /// 残り回数（全幅にする🔥）
              Stack(
                children: [
                  Image.asset(
                    'assets/images/zan.png',
                    width: double.infinity, // ←これ重要
                    height: 60,
                    fit: BoxFit.fill,
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 25),
                      child: Text(
                        "残り ${max(0, 5 - todayCount)}回",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  /// 追加
                  Expanded(
                    child: GestureDetector(
                      onTap: addParameter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/button.png',
                            height: 80,
                            width:double.infinity,
                            fit: BoxFit.fill,
                          ),
                          const Text(
                            "パラメータ追加",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),
                  /// 削除
                  Expanded(
                    child: GestureDetector(
                      onTap: selectDeleteParameter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/button.png',
                            height: 80,
                            width:double.infinity,
                            fit: BoxFit.fill,
                          ),
                          const Text(
                            "パラメータ削除",
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              GestureDetector(
                onTap: resetParameters,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/images/button.png',
                      height: 80,
                      width: double.infinity,
                      fit: BoxFit.fill,
                    ),
                    const Text(
                      "パラメータリセット",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}