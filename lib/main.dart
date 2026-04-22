import 'package:flutter/material.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
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
  final GlobalKey keyParam = GlobalKey();
  final GlobalKey keyRemain = GlobalKey();
  final GlobalKey keyAdd = GlobalKey();
  final GlobalKey keyDelete = GlobalKey();
  final GlobalKey keyResultDialog = GlobalKey();

  // チュートリアル関数
  Widget _bubble(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black),
      ),
    );
  }

  void showTutorialStep1() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "param",
          keyTarget: keyParam,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, __) => _bubble("パラメータをタップすると記録できます"),
            ),
          ],
        ),
      ],
      onFinish: () {
        showResultTutorial(); // ←次へ🔥
      },
    ).show(context: context);
  }

  void showResultTutorial() {
    // 先に出来栄え画面を出す
    if (parameters.isNotEmpty){
      showResultDialog(0);
    }
    
    // 少し待ってからチュートリアル
    Future.delayed(const Duration(milliseconds: 300), () {
      TutorialCoachMark(
        targets: [
          TargetFocus(
            identify: "result",
            targetPosition: TargetPosition(
              const Size(250, 300), // ダイアログサイズ（だいたいでOK）
              Offset(
                MediaQuery.of(context).size.width / 2 - 125,
                MediaQuery.of(context).size.height / 2 - 150,
              ),
            ),
            enableOverlayTab: true,
            contents: [
              TargetContent(
                align: ContentAlign.top,
                builder: (_, __) => _bubble("出来栄え（良い・普通・悪い）を選びます"),
              ),
            ],
          ),
        ],
        onFinish: () {
          Navigator.pop(context);
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            showBottomTutorial();
          });
        },
      ).show(context: context);
    });
  }

  void showBottomTutorial() {
    TutorialCoachMark(
      targets: [
        // 残り回数
        TargetFocus(
          identify: "count",
          keyTarget: keyRemain,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, __) => _bubble("1日5回まで記録できます"),
            ),
          ],
        ),

        // 追加
        TargetFocus(
          identify: "add",
          keyTarget: keyAdd,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, __) => _bubble("パラメータは最大8個まで追加できます"),
            ),
          ],
        ),

        // 削除
        TargetFocus(
          identify: "delete",
          keyTarget: keyDelete,
          enableOverlayTab: true,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (_, __) => _bubble("不要なパラメータは削除できます"),
            ),
          ],
        ),
      ],
      onFinish: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("使い方OK！")),
        );
      },
    ).show(context: context);
  }

  // 初回判定
  Future<void> checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('isFirst') ?? true;

    if (isFirst) {
      await prefs.setBool('isFirst', false);
      showTutorialStep1();
    }
  }

  final random = Random();
  List<Map<String, dynamic>> parameters = [];
  int todayCount = 0;
  String todayKey = "";
  Color bgColor = Colors.white;
  BannerAd? _bannerAd;
  bool isAdLoaded = false;

  // 広告
  @override
  void initState() {
    super.initState();  
    loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      checkFirstLaunch(); // ←ここに移動🔥
    });
    _bannerAd = BannerAd(
      adUnitId: Platform.isIOS
          ?'ca-app-pub-2166954523208068/6803285524'
          :'ca-app-pub-2166954523208068/4000621690',
      size: AdSize.banner,
      request: const AdRequest(),
      // listener: BannerAdListener(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          print('広告ロード成功');
          if (!mounted) return;
          setState((){
            isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          print('広告失敗: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
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
      try {
        parameters = List<Map<String, dynamic>>.from(jsonDecode(saved));
      } catch (e) {
        parameters = [
          {'name': '仕事', 'value': 0},
          {'name': '勉強', 'value': 0},
          {'name': '運動', 'value': 0},
        ];
      }
    } else {
      parameters = [
        {'name': '仕事', 'value': 0},
        {'name': '勉強', 'value': 0},
        {'name': '運動', 'value': 0},
      ];
    }

    final colorValue = prefs.getInt('bgColor') ?? Colors.white.value;
    bgColor = Color(colorValue);

    if (!mounted) return;
    setState(() {});
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('params', jsonEncode(parameters));
    await prefs.setString('date', todayKey);
    await prefs.setInt('count', todayCount);
    await prefs.setInt('bgColor', bgColor.value);
  }

  void checkDateReset() {
    final newKey = getTodayKey();
    if (newKey != todayKey) {
      todayKey = newKey;
      todayCount = 0;
      saveData();
    }
  }

  void increaseParam(int index) {
    checkDateReset();
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
      if (!mounted) return;
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

    final input = await showDialog<String>(
      context: context,
      builder: (context) {
        String temp = "";

        return AlertDialog(
          title: const Text("パラメータ名入力"),
          content: TextField(
            maxLength: 8,
            onChanged: (value) => temp = value,
            decoration: const InputDecoration(
              hintText: "例：運動",
              counterText: "",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null), // ←キャンセル
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, temp), // ←OK
              child: const Text("OK"),
            ),
          ],
        );
      },
    );

    if (input == null) return; // ←これが超重要

    final trimmed = input.trim();

    if (trimmed.isEmpty) return;

    if (trimmed.length > 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('8文字以内で入力してください')),
      );
      return;
    }

    final isDuplicate = parameters.any(
      (p) => p['name'].toString().toLowerCase() == trimmed.toLowerCase(),
    );

    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同じ名前は使えません')),
      );
      return;
    }

    setState(() {
      parameters.add({
        'name': trimmed,
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
    checkDateReset();
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
      if (!mounted) return;
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
        key: keyResultDialog,
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
                          key: index ==0 ? keyParam : null,
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
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment(-0.9, 0.15), // ←ここで下げる
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(p['name']),
                                  ),
                                ),
                              ),

                              /// 数値
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment(0.9, 0.15), // ←右 + 少し下
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Text("${p['value']}"),
                                  ),
                                ),
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
                key: keyRemain,
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
                      key: keyAdd,
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
                      key: keyDelete,
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
              
              if (_bannerAd != null && isAdLoaded)
                Container(
                  alignment: Alignment.center,
                  height: 50,
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],           
          ),
        ),
      ),
    );
  }
}