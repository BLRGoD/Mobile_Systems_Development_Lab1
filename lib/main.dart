import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Мой кредит',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),
    );
  }
}

// Экран загрузки
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Загрузка...', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

// Экран авторизации
class LoginPage extends StatelessWidget {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> _login(BuildContext context) async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Введите имя пользователя и пароль')),
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/login'), // Локальный адрес Flask-сервера
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );


      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = responseData['token'];

        // Сохраняем токен
        await _secureStorage.write(key: 'auth_token', value: token);

        // Переход на следующий экран
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => CreditPage()),
        );
      } else {
        // Ошибка авторизации
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${response.body}')),
        );
      }
    } catch (e) {
      // Ошибка сети
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сети: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Авторизация'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Имя пользователя'),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Пароль'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _login(context),
              child: Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}

// Страница со всеми кредитами
class CreditPage extends StatefulWidget {
  @override
  _CreditPageState createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> {
  List<Credit> credits = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мои кредиты'),
      ),
      body: credits.isEmpty
          ? Center(child: Text('Кредитов пока нет.'))
          : ListView.builder(
        itemCount: credits.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(credits[index].creditName),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      CreditDetailsPage(credit: credits[index]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddCreditPage(
                onCreditAdded: (credit) {
                  setState(() {
                    credits.add(credit);
                  });
                },
              ),
            ),
          );
        },
        child: Icon(Icons.add),
        tooltip: 'Добавить кредит',
      ),
    );
  }
}

// Детали кредита
class CreditDetailsPage extends StatefulWidget {
  final Credit credit;

  CreditDetailsPage({required this.credit});

  @override
  _CreditDetailsPageState createState() => _CreditDetailsPageState();
}

class _CreditDetailsPageState extends State<CreditDetailsPage> {
  double? newInterestRate;
  List<Map<String, dynamic>> interestChanges = [];

  void _changeInterestRate() {
    if (newInterestRate != null) {
      setState(() {
        double monthlyPayment = widget.credit.calculateMonthlyPayment(newRate: newInterestRate!);
        double totalInterest = widget.credit.calculateTotalInterest(newRate: newInterestRate!);
        double overallOverpayment = widget.credit.calculateOverallOverpayment(newRate: newInterestRate!);

        interestChanges.add({
          'interestRate': newInterestRate,
          'monthlyPayment': monthlyPayment,
          'totalInterest': totalInterest,
          'overallOverpayment': overallOverpayment,
        });

        newInterestRate = null; // Сброс значения после изменения
      });
    }
  }

  void _calculatePrepayment() {
    // Пример логики для расчета досрочного погашения
    double remainingBalance = widget.credit.creditAmount; // Добавьте логику для реального остатка
    double reducedTotalInterest = widget.credit.calculateTotalInterest(); // Обновите расчет, если нужно
    double totalOverpayment = widget.credit.calculateOverallOverpayment();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Расчет досрочного погашения'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Оставшаяся сумма: ${remainingBalance.toStringAsFixed(2)} ${widget.credit.currency}'),
              Text('Переплата после досрочного погашения: ${reducedTotalInterest.toStringAsFixed(2)} ${widget.credit.currency}'),
              Text('Итоговая переплата: ${totalOverpayment.toStringAsFixed(2)} %'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.credit.creditName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Основная информация о кредите
            Text('Сумма кредита: ${widget.credit.creditAmount} ${widget.credit.currency}'),
            Text('Дата выдачи: ${DateFormat('yyyy-MM-dd').format(widget.credit.issueDate)}'),
            Text('Срок кредита: ${widget.credit.durationMonths} месяцев'),
            Text('Процентная ставка: ${widget.credit.interestRate}% (${widget.credit.interestType})'),
            Text('Тип платежа: ${widget.credit.paymentType}'),
            Text('Дата платежа: ${widget.credit.paymentDateType}'),
            Text('Первый платёж: ${widget.credit.firstPaymentType}'),
            Text('Досрочное погашение: ${widget.credit.isPrepaymentAllowed ? 'Да' : 'Нет'}'),
            SizedBox(height: 20),
            Text('Расчетные данные:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
                'Ежемесячный платеж: ${widget.credit.calculateMonthlyPayment().toStringAsFixed(2)} ${widget.credit.currency}'),
            Text(
                'Переплата по процентам: ${widget.credit.calculateTotalInterest().toStringAsFixed(2)} ${widget.credit.currency}'),
            Text(
                'Итоговая переплата: ${widget.credit.calculateOverallOverpayment().toStringAsFixed(2)} %'),
            SizedBox(height: 20),

            // Кнопка для изменения процентной ставки
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text('Изменить процентную ставку'),
                      content: TextField(
                        decoration: InputDecoration(hintText: 'Введите новую ставку (%)'),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          newInterestRate = double.tryParse(value);
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _changeInterestRate();
                          },
                          child: Text('Изменить'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: Text('Изменить процентную ставку'),
            ),
            SizedBox(height: 20),

            // Кнопка для расчета досрочного погашения
            ElevatedButton(
              onPressed: _calculatePrepayment,
              child: Text('Рассчитать досрочное погашение'),
            ),

            // Расчетные данные
            SizedBox(height: 20),
            Text('Расчетные данные:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            for (var change in interestChanges)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Процентная ставка: ${change['interestRate']}%'),
                  Text('Ежемесячный платеж: ${change['monthlyPayment'].toStringAsFixed(2)} ${widget.credit.currency}'),
                  Text('Переплата по процентам: ${change['totalInterest'].toStringAsFixed(2)} ${widget.credit.currency}'),
                  Text('Итоговая переплата: ${change['overallOverpayment'].toStringAsFixed(2)} %'),
                  Divider(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Страница добавления кредита
class AddCreditPage extends StatefulWidget {
  final Function(Credit) onCreditAdded;

  AddCreditPage({required this.onCreditAdded});

  @override
  _AddCreditPageState createState() => _AddCreditPageState();
}

class _AddCreditPageState extends State<AddCreditPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _creditNameController = TextEditingController();
  final TextEditingController _creditAmountController = TextEditingController();
  final TextEditingController _interestRateController = TextEditingController();
  final TextEditingController _creditDurationController =
  TextEditingController();
  String _currency = 'RU';
  DateTime? _issueDate;
  String _interestType = 'Фиксированная';
  String _paymentType = 'Аннуитетный';
  String _paymentDateType = 'В день выдачи';
  String _firstPaymentType = 'Проценты и основной долг';
  bool _isPrepaymentAllowed = false;

  Future<void> _selectIssueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _issueDate) {
      setState(() {
        _issueDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить кредит'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                // Имя кредита
                TextFormField(
                  controller: _creditNameController,
                  decoration: InputDecoration(labelText: 'Название кредита'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите название кредита';
                    }
                    return null;
                  },
                ),
                // Сумма кредита
                TextFormField(
                  controller: _creditAmountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Сумма кредита'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите сумму кредита';
                    }
                    return null;
                  },
                ),
                // Валюта
                DropdownButtonFormField<String>(
                  value: _currency,
                  decoration: InputDecoration(labelText: 'Валюта'),
                  items: ['RU', 'USD', 'EUR']
                      .map((currency) => DropdownMenuItem(
                    value: currency,
                    child: Text(currency),
                  ))
                      .toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _currency = newValue!;
                    });
                  },
                ),
                // Дата выдачи
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Дата выдачи',
                    hintText: _issueDate == null
                        ? 'Выберите дату'
                        : DateFormat('dd.MM.yyyy').format(_issueDate!),
                  ),
                  onTap: () {
                    _selectIssueDate(context);
                  },
                ),
                // Срок кредита
                TextFormField(
                  controller: _creditDurationController,
                  keyboardType: TextInputType.number,
                  decoration:
                  InputDecoration(labelText: 'Срок кредита (в месяцах)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите срок кредита';
                    }
                    return null;
                  },
                ),
                // Процентная ставка
                TextFormField(
                  controller: _interestRateController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Процентная ставка (% годовых)'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Введите процентную ставку';
                    }
                    return null;
                  },
                ),
                // Тип процентной ставки
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тип процентной ставки'),
                    ListTile(
                      title: const Text('Фиксированная'),
                      leading: Radio<String>(
                        value: 'Фиксированная',
                        groupValue: _interestType,
                        onChanged: (value) {
                          setState(() {
                            _interestType = value!;
                          });
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Изменяемая'),
                      leading: Radio<String>(
                        value: 'Изменяемая',
                        groupValue: _interestType,
                        onChanged: (value) {
                          setState(() {
                            _interestType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Вид платежа
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Вид платежа'),
                    ListTile(
                      title: const Text('Аннуитетный'),
                      leading: Radio<String>(
                        value: 'Аннуитетный',
                        groupValue: _paymentType,
                        onChanged: (value) {
                          setState(() {
                            _paymentType = value!;
                          });
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text('Дифференцированный'),
                      leading: Radio<String>(
                        value: 'Дифференцированный',
                        groupValue: _paymentType,
                        onChanged: (value) {
                          setState(() {
                            _paymentType = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                // Дата платежей
                DropdownButtonFormField<String>(
                  value: _paymentDateType,
                  decoration: InputDecoration(labelText: 'Дата платежей'),
                  items: [
                    'В день выдачи',
                    'В последний день месяца',
                    'Выбрать дату'
                  ]
                      .map((dateType) => DropdownMenuItem(
                    value: dateType,
                    child: Text(dateType),
                  ))
                      .toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _paymentDateType = newValue!;
                    });
                  },
                ),
                // Первый платеж
                DropdownButtonFormField<String>(
                  value: _firstPaymentType,
                  decoration: InputDecoration(labelText: 'Первый платёж'),
                  items: [
                    'Проценты и основной долг',
                    'Только проценты',
                  ]
                      .map((firstPayment) => DropdownMenuItem(
                    value: firstPayment,
                    child: Text(firstPayment),
                  ))
                      .toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _firstPaymentType = newValue!;
                    });
                  },
                  ),
                // Досрочное погашение
                SwitchListTile(
                  title: Text('Досрочное погашение'),
                  value: _isPrepaymentAllowed,
                  onChanged: (newValue) {
                    setState(() {
                      _isPrepaymentAllowed = newValue;
                    });
                  },
                ),
                // Кнопка "Сохранить"
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final newCredit = Credit(
                        creditName: _creditNameController.text,
                        creditAmount: double.parse(_creditAmountController.text),
                        currency: _currency,
                        issueDate: _issueDate ?? DateTime.now(),
                        durationMonths: int.parse(_creditDurationController.text),
                        interestRate: double.parse(_interestRateController.text),
                        interestType: _interestType,
                        paymentType: _paymentType,
                        paymentDateType: _paymentDateType,
                        firstPaymentType: _firstPaymentType,
                        isPrepaymentAllowed: _isPrepaymentAllowed,
                      );

                      // Расчетные данные
                      double monthlyPayment = newCredit.calculateMonthlyPayment();
                      double totalInterest = newCredit.calculateTotalInterest();
                      double overallOverpayment = newCredit.calculateOverallOverpayment();

                      // // Вывод расчетных данных в консоль (или можно добавить отображение в UI)
                      // print('Ежемесячный платеж: ${monthlyPayment.toStringAsFixed(2)} ${newCredit.currency}');
                      // print('Переплата по процентам: ${totalInterest.toStringAsFixed(2)} ${newCredit.currency}');
                      // print('Итоговая переплата: ${overallOverpayment.toStringAsFixed(2)} %');
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Процентная ставка: ${newCredit.interestRate}%'),
                          Text('Ежемесячный платеж: ${monthlyPayment.toStringAsFixed(2)} ${newCredit.currency}'),
                          Text('Переплата по процентам: ${totalInterest.toStringAsFixed(2)} ${newCredit.currency}'),
                          Text('Итоговая переплата: ${overallOverpayment.toStringAsFixed(2)} %'),
                          const Divider(),
                        ],
                      );

                      widget.onCreditAdded(newCredit);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Модель кредита
class Credit {
  final String creditName;
  final double creditAmount;
  final String currency;
  final DateTime issueDate;
  final int durationMonths;
  final double interestRate;
  final String interestType;
  final String paymentType;
  final String paymentDateType;
  final String firstPaymentType;
  final bool isPrepaymentAllowed;

  Credit({
    required this.creditName,
    required this.creditAmount,
    required this.currency,
    required this.issueDate,
    required this.durationMonths,
    required this.interestRate,
    required this.interestType,
    required this.paymentType,
    required this.paymentDateType,
    required this.firstPaymentType,
    required this.isPrepaymentAllowed,
  });

  List<Map<String, dynamic>> calculatePaymentSchedule() {
    List<Map<String, dynamic>> schedule = [];
    double remainingBalance = creditAmount;
    DateTime paymentDate = issueDate.add(Duration(days: 30)); // Первый платеж через 30 дней

    for (int i = 1; i <= durationMonths; i++) {
      double interestPayment;
      double principalPayment;
      double monthlyPayment;

      if (paymentType == 'аннуитетный') {
        double monthlyRate = (interestRate / 100) / 12;
        monthlyPayment = remainingBalance *
            (monthlyRate +
                (monthlyRate / (1 - (1 / pow(1 + monthlyRate, durationMonths)))));
        interestPayment = remainingBalance * monthlyRate;
        principalPayment = monthlyPayment - interestPayment;
      } else if (paymentType == 'дифференцированный') {
        principalPayment = creditAmount / durationMonths;
        interestPayment = remainingBalance * (interestRate / 100) * 30 / 365;
        monthlyPayment = principalPayment + interestPayment;
      } else {
        throw Exception('Неизвестный тип платежа');
      }

      schedule.add({
        'number': i,
        'date': paymentDate,
        'payment': monthlyPayment,
        'principal': principalPayment,
        'interest': interestPayment,
        'remainingBalance': remainingBalance - principalPayment,
      });

      remainingBalance -= principalPayment;
      paymentDate = paymentDate.add(Duration(days: 30));
    }

    return schedule;
  }

  // Расчет ежемесячного платежа с возможностью передачи новой ставки
  double calculateMonthlyPayment({double? newRate}) {
    double rate = newRate ?? interestRate; // Используем новую ставку, если она передана
    if (paymentType == 'Аннуитетный') {
      // Ставка процента за один месяц
      double monthlyRate = rate / 12 / 100;
      return creditAmount *
          (monthlyRate +
              (monthlyRate / (pow(1 + monthlyRate, durationMonths) - 1)));
    } else {
      // Дифференцированный платеж
      double remainingBalance = creditAmount;
      double monthlyInterest =
          (remainingBalance * rate * 30) / (100 * 365);
      return (remainingBalance / durationMonths) + monthlyInterest;
    }
  }

  // Расчет полной стоимости кредита с возможностью передачи новой ставки
  double calculateTotalCost({double? newRate}) {
    return calculateMonthlyPayment(newRate: newRate) * durationMonths;
  }

  // Расчет переплаты по процентам за кредит с возможностью передачи новой ставки
  double calculateTotalInterest({double? newRate}) {
    return calculateTotalCost(newRate: newRate) - creditAmount;
  }

  // Итоговая переплата за весь период с возможностью передачи новой ставки
  double calculateOverallOverpayment({double? newRate}) {
    return (calculateTotalInterest(newRate: newRate) * 100) / creditAmount;
  }
}