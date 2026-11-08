import 'package:flutter/material.dart';

/// Common page frame for a bottom-bar tab: an app bar and a body.
class TabScaffold extends StatelessWidget {
  const TabScaffold({super.key, required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
