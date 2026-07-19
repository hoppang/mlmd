import 'package:flutter/material.dart';

class TransferProgressDialog extends StatelessWidget {
  final String message;

  const TransferProgressDialog({super.key, required this.message});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}
