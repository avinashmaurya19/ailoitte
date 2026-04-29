import 'package:ailoitte/bloc/note_bloc.dart';
import 'package:ailoitte/bloc/note_event.dart';
import 'package:ailoitte/data/db_helper.dart';
import 'package:ailoitte/data/repository.dart';
import 'package:ailoitte/data/sync_manager.dart';
import 'package:ailoitte/firebase_options.dart';
import 'package:ailoitte/ui/home_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final db = DBHelper();
  final sync = SyncManager(db);
  final repo = NoteRepository(db, sync);
  runApp(MyApp(repo: repo));
}

class MyApp extends StatelessWidget {
  final NoteRepository repo;
  const MyApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline First Notes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: BlocProvider(
        create: (_) => NoteBloc(repo)..add(LoadNotes()),
        child: const HomePage(),
      ),
    );
  }
}
