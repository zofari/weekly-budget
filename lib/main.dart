import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(MaterialApp(
    // Hide the debug label at the top right corner for debug build
    debugShowCheckedModeBanner: false,
    title: 'Weekly Budget',
    home: WeeklyBudget(),
  ));
}

class WeeklyBudget extends StatefulWidget {
  WeeklyBudget({Key key}) : super(key: key);

  @override
  _WeeklyBudgetState createState() => _WeeklyBudgetState();
}

enum StoreKey {
  total,
  weeklyBudget,
  lastBudgetTime,
  lastTxAmount,
  showUndo,
  debugCounter,
  debugCounter2
}

class _WeeklyBudgetState extends State<WeeklyBudget>
    with SingleTickerProviderStateMixin {
  AnimationController _animation;
  SharedPreferences _prefs;

  @override
  initState() {
    super.initState();
    _initStateAsync();
    _initAnimationController();
    _initTimerAddWeeklyBudget();
  }

  // Async because of SharedPreferences. Everything to do with
  // SharedPreferences in initState needs to go in this function.
  _initStateAsync() async {
    _prefs = await SharedPreferences.getInstance();

    // For debug purpose. Track how many times initState is called.
    _storeAddValue(StoreKey.debugCounter2, 1);

    // First time running the app? Set default values $100.00.
    if (!_storeKeyExist(StoreKey.weeklyBudget)) {
      _storeSetValue(StoreKey.weeklyBudget, 10000);
    }

    // If weekly budget has been allocated in the check function, the
    // rebuild would have been triggered already, hence don't need to
    // call setState() again in that case.
    if (!_checkToAllocateWeeklyBudget()) {
      setState(() {});
    }
  }

  // TODO Store related function should probably go into a separate store class.

  int _storeGetValue(StoreKey key) {
    return _prefs == null ? 0 : _prefs.get(key.toString()) ?? 0;
  }

  _storeSetValue(StoreKey key, int val) {
    if (_prefs != null) _prefs.setInt(key.toString(), val);
  }

  _storeAddValue(StoreKey key, int val) {
    _storeSetValue(key, _storeGetValue(key) + val);
  }

  bool _storeKeyExist(StoreKey key) {
    return _prefs.get(key.toString()) == null ? false : true;
  }

  _initAnimationController() {
    _animation = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this)
      ..addListener(() {
        setState(() {});
      })
      ..forward();
  }

  // This is for the purpose that in case the app is held running by the OS,
  // it would be able to load the weekly budget at its time. During testing
  // with debug build, however, the app always gets killed before this timer
  // has a chance to fire.
  _initTimerAddWeeklyBudget() {
    Timer.periodic(Duration(hours: 1), (timer) {
      _storeAddValue(StoreKey.debugCounter, 1);

      _checkToAllocateWeeklyBudget();
    });
  }

  bool _checkToAllocateWeeklyBudget() {
    int now = DateTime.now().millisecondsSinceEpoch;
    int then = _storeGetValue(StoreKey.lastBudgetTime);
    int week = 1000 * 3600 * 24 * 7;
    int weeksPassed = (now - then) ~/ week;

    if (weeksPassed == 0) {
      return false;
    }

    int budget = _storeGetValue(StoreKey.weeklyBudget);
    if (then == 0) {
      _storeSetValue(StoreKey.lastBudgetTime, now);
    } else {
      _storeSetValue(StoreKey.lastBudgetTime, then + week * weeksPassed);
      budget *= weeksPassed;
    }
    _addFundAndRefreshUI(budget, false);

    return true;
  }

  _addFundAndRefreshUI(int val, bool fromUser) {
    if (val == 0 && fromUser) {
      return;
    }

    _animation.reset();
    _animation.forward();

    setState(() {
      if (fromUser) {
        _storeSetValue(StoreKey.lastTxAmount, val);
        _storeSetValue(StoreKey.showUndo, 1);
      }
      _storeAddValue(StoreKey.total, val);
    });
  }

  _showInputSheet(Function f, Color backgroundColor) {
    var textController = MoneyMaskedTextController(
        decimalSeparator: '.', thousandSeparator: ',', leftSymbol: '\$ ');
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return GestureDetector(
              child: Container(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 22,
                      top: 22,
                      left: 22,
                      right: 22),
                  color: backgroundColor,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                            // Use IgnorePointer so onTap from GestureDetector will take
                            // precedence over TextField tap to focus.
                            child: IgnorePointer(
                                child: TextField(
                          decoration: null,
                          keyboardType: TextInputType.number,
                          controller: textController,
                          maxLines: 1,
                          textAlign: TextAlign.end,
                          autofocus: true,
                          style: TextStyle(fontSize: 32.0),
                          enableInteractiveSelection: false,
                          cursorWidth: 0.0,
                        ))),
                        Padding(
                            padding: EdgeInsets.only(bottom: 10),
                            child: Text(
                                '    \u{25B6}', // Right triangle as a hint to user to tap to enter.
                                style: TextStyle(
                                    fontSize: 14.0, color: Colors.white)))
                      ])),
              onTap: () {
                f(int.parse(
                    textController.text.replaceAll(RegExp(r'\W+'), '')));
                Navigator.pop(context);
              });
        });
  }

  _showAddInput() {
    _showInputSheet((int val) {
      _addFundAndRefreshUI(val, true);
    }, Colors.black);
  }

  _showSubstractInput() {
    _showInputSheet((int val) {
      _addFundAndRefreshUI(-val, true);
    }, Colors.red);
  }

  _showConfigureWeeklyFundInput() {
    _showInputSheet((int val) {
      _storeSetValue(StoreKey.weeklyBudget, val);

      Fluttertoast.showToast(
          msg: 'Weekly budget is set to \$' + _convertAmountToStr(val),
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIos: 3,
          backgroundColor: Colors.grey.shade100,
          textColor: Colors.black);
    }, Colors.grey);
  }

  String _convertAmountToStr(int val) {
    return val % 100 == 0 ? '${val ~/ 100}' : '${val / 100}';
  }

  _showInfoSheet() {
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return Container(
              padding: EdgeInsets.all(25.0),
              child: RichText(
                  text: TextSpan(
                      style: TextStyle(color: Colors.grey.shade900),
                      children: <TextSpan>[
                    TextSpan(
                        text: 'Weekly Budget\n',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: '\$' +
                            _convertAmountToStr(
                                _storeGetValue(StoreKey.weeklyBudget))),
                    TextSpan(
                        text: '\n\nNext Budget Load Date\n',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: DateFormat('EEEEEEEEE, MM/dd/yyyy').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                _storeGetValue(StoreKey.lastBudgetTime) +
                                    1000 * 3600 * 24 * 7))),
                    TextSpan(
                        text: '\n\nMysterious Counters\n',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(
                        text: _storeGetValue(StoreKey.debugCounter).toString() +
                            '/' +
                            _storeGetValue(StoreKey.debugCounter2).toString())
                  ])));
        });
  }

  _showResetAlertDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              title: Text('Reset'),
              content: Text('Reset the tracked amount to the weekly budget?'),
              actions: <Widget>[
                FlatButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                FlatButton(
                  child: Text('Yes'),
                  onPressed: () {
                    _storeSetValue(StoreKey.lastTxAmount, 0);
                    _storeSetValue(StoreKey.lastBudgetTime, 0);
                    _storeSetValue(StoreKey.total, 0);
                    _storeSetValue(StoreKey.showUndo, 0);

                    _checkToAllocateWeeklyBudget();
                    Navigator.of(context).pop();
                  },
                )
              ]);
        });
  }

  @override
  dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var total = _storeGetValue(StoreKey.total);
    var lastTxAmount = _storeGetValue(StoreKey.lastTxAmount);

    var fundWidgets = <Widget>[
      Text('\$' + _convertAmountToStr(total),
          style: TextStyle(
              fontSize: 62.0,
              color: total < 0 ? Colors.red : Colors.black,
              shadows: <Shadow>[
                Shadow(
                    blurRadius: 1.0,
                    offset: Offset(1.5, 1.5),
                    color: Colors.grey.shade400)
              ])),
    ];

    if (_storeGetValue(StoreKey.showUndo) == 1) {
      fundWidgets.insert(
          0,
          GestureDetector(
              // Need to set behavior to have opaque area trigger tap action.
              behavior: HitTestBehavior.opaque,
              child: Padding(
                  padding: EdgeInsets.fromLTRB(15, 15, 5, 15),
                  child: Text('\u{25C0}', // Left triangle symbol
                      style: TextStyle(fontSize: 16.0, color: Colors.grey))),
              onTap: () {
                _storeSetValue(StoreKey.showUndo, 0);
                _addFundAndRefreshUI(-lastTxAmount, false);
              }));
    } else if (lastTxAmount != 0) {
      // show redo
      fundWidgets.add(GestureDetector(
          behavior: HitTestBehavior.opaque,
          child: Padding(
              padding: EdgeInsets.fromLTRB(5, 15, 15, 15),
              child: Text('\u{25B6}', // Right triangle symbol
                  style: TextStyle(fontSize: 16.0, color: Colors.grey))),
          onTap: () {
            _addFundAndRefreshUI(lastTxAmount, true);
          }));
    }

    // In SingleScrollView(Row(Text)), if text is the right most widget, the very right end
    // of the text will be clipped. To word around it, append another text of space in such case
    // (when redo button isn't shown).
    if (_storeGetValue(StoreKey.showUndo) == 1 || lastTxAmount == 0) {
      fundWidgets.add(Text(' '));
    }

    return Scaffold(
      body: Center(
          child: Opacity(
              opacity: _animation.value,
              child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: fundWidgets,
                  )))),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: _showAddInput,
            child: Icon(Icons.arrow_upward),
            backgroundColor: Colors.black,
          ),
          Padding(padding: EdgeInsets.only(left: 10.0)),
          FloatingActionButton(
              onPressed: _showSubstractInput,
              child: Icon(Icons.arrow_downward),
              backgroundColor: Colors.red),
        ],
      ),
      appBar: AppBar(
          backgroundColor: Colors.grey.shade900,
          title: Text('Weekly Budget'),
          actions: <Widget>[
            PopupMenuButton(
              onSelected: (val) {
                if (val == 1) {
                  _showConfigureWeeklyFundInput();
                } else if (val == 2) {
                  _showInfoSheet();
                } else if (val == 3) {
                  _showResetAlertDialog();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                    const PopupMenuItem(
                      value: 1,
                      child: Text('Set weekly budget'),
                    ),
                    const PopupMenuItem(
                      value: 2,
                      child: Text('Show info'),
                    ),
                    const PopupMenuItem(
                      value: 3,
                      child: Text('Reset available fund'),
                    )
                  ],
            )
          ]),
    );
  }
}
