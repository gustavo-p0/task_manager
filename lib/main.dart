import 'package:flutter/material.dart';
import 'screens/task_list_screen.dart';


/* 
  Este é o ponto de entrada da nossa aplicação Flutter. A função main() chama runApp() para iniciar o app. O widget MyApp configura o MaterialApp, que define o tema global, o título e a tela inicial (home), que será a nossa TaskListScreen.
*/

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TaskListScreen(),
    );
  }
}