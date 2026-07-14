import 'package:flutter/material.dart';

import '../data/furfeel_repository.dart';
import '../models/models.dart';
import 'history_page.dart';

/// Full raw history (vitals chart, stress timeline, reading log) for owners
/// who want the detail — reached from the Trends tab, not a top-level view.
class DetailedLogPage extends StatelessWidget {
  const DetailedLogPage({super.key, required this.repository, required this.dog});

  final FurFeelRepository repository;
  final Dog dog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${dog.name}\'s detailed log')),
      body: HistoryView(repository: repository, dog: dog),
    );
  }
}
