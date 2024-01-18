import 'package:flutter/material.dart';
import 'package:rfwpg/components/rfw_pad.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RFW Playground'),
      ),
      body: RfwPad(),
    );
  }
}
