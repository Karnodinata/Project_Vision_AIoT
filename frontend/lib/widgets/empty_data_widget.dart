import 'package:flutter/material.dart';

class EmptyDataWidget extends StatelessWidget {
  final String message;
  const EmptyDataWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.inbox_outlined, color: Color(0xFF4A7A72), size: 18),
        const SizedBox(width: 10),
        Text(
          message,
          style: const TextStyle(color: Color(0xFF2E4F48), fontSize: 13),
        ),
      ],
    );
  }
}
